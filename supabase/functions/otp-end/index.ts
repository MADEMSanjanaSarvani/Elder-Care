// POST /functions/v1/otp-end
// body: { booking_id: uuid, otp: string }
//
// Completes the visit and schedules the caregiver's payout — the payout
// ledger entry is created here, at visit-completion, rather than at
// booking time, so a caregiver is only ever owed money for work actually
// verified as delivered (PRD Part 1 §04, Part 2 §11).
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

// T+2 days: an illustrative settlement window — confirm the actual
// guaranteed-payout SLA with finance/ops before launch (PRD Part 1 §04).
const PAYOUT_DELAY_DAYS = 2;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const { booking_id, otp } = await req.json();
    if (!booking_id || !otp) return errorResponse("booking_id and otp are required");

    const admin = supabaseAdmin();
    const { data: booking, error } = await admin
      .from("bookings")
      .select("id, elder_id, status, otp_end, caregiver_id, caregivers(user_id), service_catalog(base_price, currency, commission_pct)")
      .eq("id", booking_id)
      .single();
    if (error || !booking) return errorResponse("Booking not found", 404);

    const assignedUserId = (booking as unknown as { caregivers: { user_id: string } }).caregivers?.user_id;
    if (assignedUserId !== user.id) return errorResponse("Not the assigned caregiver for this booking", 403);
    if (booking.status !== "in_progress") return errorResponse(`Cannot end a visit from status ${booking.status}`, 409);
    if (booking.otp_end !== otp) return errorResponse("Incorrect OTP", 422);

    const { data: updated, error: updateErr } = await admin
      .from("bookings")
      .update({ status: "completed", otp_end_verified_at: new Date().toISOString() })
      .eq("id", booking_id)
      .select()
      .single();
    if (updateErr) return errorResponse(updateErr.message, 500);

    const service = (booking as unknown as { service_catalog: { base_price: number; currency: string; commission_pct: number } }).service_catalog;
    const caregiverAmount = Number((service.base_price * (1 - service.commission_pct / 100)).toFixed(2));
    const scheduledFor = new Date(Date.now() + PAYOUT_DELAY_DAYS * 24 * 60 * 60 * 1000).toISOString();

    await admin.from("caregiver_payouts").insert({
      caregiver_id: booking.caregiver_id,
      booking_id,
      amount: caregiverAmount,
      currency: service.currency,
      provider: "razorpayx",
      status: "scheduled",
      scheduled_for: scheduledFor,
    });

    await admin.from("booking_events").insert({
      booking_id,
      event_type: "visit_completed",
      actor_user_id: user.id,
      payload: { payout_amount: caregiverAmount, payout_currency: service.currency },
    });

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "booking",
      resource_id: booking_id,
      metadata: { event: "visit_completed", payout_amount: caregiverAmount },
    });

    // Fire-and-forget: feeds the Elder Care Timeline (PRD Part 4, Batch 1).
    await admin.from("elder_timeline_events").insert({
      elder_id: booking.elder_id,
      event_type: "visit_completed",
      category: "visit_history",
      actor_user_id: user.id,
      related_booking_id: booking_id,
      summary: "Visit completed",
      metadata: { payout_amount: caregiverAmount },
    });

    return jsonResponse(updated);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
