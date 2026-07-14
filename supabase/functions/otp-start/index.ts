// POST /functions/v1/otp-start
// body: { booking_id: uuid, otp: string }
// Caller must be the assigned caregiver. Marks the visit as started.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

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
      .select("id, status, otp_start, caregiver_id, caregivers(user_id)")
      .eq("id", booking_id)
      .single();
    if (error || !booking) return errorResponse("Booking not found", 404);

    const assignedUserId = (booking as unknown as { caregivers: { user_id: string } }).caregivers?.user_id;
    if (assignedUserId !== user.id) return errorResponse("Not the assigned caregiver for this booking", 403);
    if (booking.status !== "matched" && booking.status !== "confirmed") {
      return errorResponse(`Cannot start a visit from status ${booking.status}`, 409);
    }
    if (booking.otp_start !== otp) return errorResponse("Incorrect OTP", 422);

    const { data: updated, error: updateErr } = await admin
      .from("bookings")
      .update({ status: "in_progress", otp_start_verified_at: new Date().toISOString() })
      .eq("id", booking_id)
      .select()
      .single();
    if (updateErr) return errorResponse(updateErr.message, 500);

    await admin.from("booking_events").insert({
      booking_id,
      event_type: "visit_started",
      actor_user_id: user.id,
      payload: {},
    });

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "booking",
      resource_id: booking_id,
      metadata: { event: "visit_started" },
    });

    return jsonResponse(updated);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
