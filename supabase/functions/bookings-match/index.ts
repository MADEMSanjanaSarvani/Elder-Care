// POST /functions/v1/bookings-match
// body: { booking_id: uuid }
//
// PRD Part 2 §12/§22: a plain SQL filter is the right amount of matching
// logic through Phase 2 (see Part 3 §22) — trust tier, region, and
// caregiver_type must line up. Revisit only when real volume in Phase 3
// shows this query is actually slow, not before.
//
// On a successful match this also generates the visit OTPs — see PRD
// Part 2 §11 (otp_start/otp_end) — since "matched" is the first point a
// specific caregiver and elder are paired for a specific visit.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { meetsRequiredTier, type TrustTier } from "../_shared/trustTier.ts";

function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req); // TODO: restrict to admin/ops or an internal dispatch job once matching moves off manual trigger
    const { booking_id } = await req.json();
    if (!booking_id) return errorResponse("booking_id is required");

    const admin = supabaseAdmin();

    const { data: booking, error: bookingErr } = await admin
      .from("bookings")
      .select("id, elder_id, region_id, service_id, required_trust_tier, status, service_catalog(category)")
      .eq("id", booking_id)
      .single();
    if (bookingErr || !booking) return errorResponse("Booking not found", 404);
    if (booking.status !== "requested") return errorResponse(`Booking is already ${booking.status}`, 409);

    const serviceCategory = (booking as unknown as { service_catalog: { category: string } }).service_catalog.category;
    const caregiverType = serviceCategory === "clinical" ? "clinical" : "non_clinical";

    const { data: candidates, error: candidateErr } = await admin
      .from("caregivers")
      .select("id, trust_tier")
      .eq("region_id", booking.region_id)
      .eq("caregiver_type", caregiverType)
      .eq("active", true);
    if (candidateErr) return errorResponse(candidateErr.message, 500);

    const eligibleCandidates = (candidates ?? []).filter((c) =>
      meetsRequiredTier(c.trust_tier as TrustTier, booking.required_trust_tier as TrustTier)
    );
    if (eligibleCandidates.length === 0) return errorResponse("No eligible caregiver available at this time", 409);

    // PRD Part 6, Batch 3, Module 10 (Companion Visits) — the one
    // existing-Edge-Function touch across Batches 1-3, scoped exactly as
    // narrowly as that document states: this only reorders which
    // *already-eligible* candidate is picked. It cannot make an
    // ineligible caregiver eligible, and falls back to the untouched
    // first-eligible selection whenever no preference is set or the
    // preferred caregiver isn't in the eligible set this time.
    const { data: preference } = await admin
      .from("companion_visit_preferences")
      .select("preferred_caregiver_id")
      .eq("elder_id", booking.elder_id)
      .maybeSingle();
    const preferredMatch = preference?.preferred_caregiver_id
      ? eligibleCandidates.find((c) => c.id === preference.preferred_caregiver_id)
      : undefined;
    const eligible = preferredMatch ?? eligibleCandidates[0];

    const otpStart = generateOtp();
    const otpEnd = generateOtp();

    const { data: updated, error: updateErr } = await admin
      .from("bookings")
      .update({ caregiver_id: eligible.id, status: "matched", otp_start: otpStart, otp_end: otpEnd })
      .eq("id", booking_id)
      .select()
      .single();
    if (updateErr) return errorResponse(updateErr.message, 500);

    await admin.from("booking_events").insert({
      booking_id,
      event_type: "matched",
      actor_user_id: user.id,
      payload: { caregiver_id: eligible.id },
    });

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "booking",
      resource_id: booking_id,
      metadata: { event: "matched", caregiver_id: eligible.id },
    });

    // Fire-and-forget: feeds the Elder Care Timeline (PRD Part 4, Batch 1).
    // A dropped row here is degraded UX, not a correctness bug — bookings
    // and booking_events remain the source of truth.
    await admin.from("elder_timeline_events").insert({
      elder_id: booking.elder_id,
      event_type: "visit_scheduled",
      category: "visit_history",
      actor_user_id: user.id,
      related_booking_id: booking_id,
      summary: "Matched with a caregiver",
      metadata: { caregiver_id: eligible.id },
    });

    // TODO(Part 3 deployment): deliver otp_start/otp_end to the elder via
    // FCM push + SMS fallback rather than returning them in this response;
    // returned here only so the MVP flow is exercisable end-to-end.
    return jsonResponse(updated);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
