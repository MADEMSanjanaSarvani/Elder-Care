// POST /functions/v1/hospital-stays-gap-sweep
//
// PRD Part 6, Batch 3, Module 11 (Hospital Companion Services): "a stay
// with no shift booked for the next several hours should be visually
// flagged to family," with gap detection feeding the shared Smart
// Reminder System (Batch 2) as a new source_type rather than a bespoke
// alert mechanism. This function is the generation half of that split —
// it only enqueues `reminders` rows; delivery stays owned by
// reminders-dispatch-sweep, same as every other source module.
//
// No user JWT — triggered externally (n8n/cron), shared-secret header,
// same pattern as the other three sweeps.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const HOSPITAL_GAP_SWEEP_SHARED_SECRET = Deno.env.get("HOSPITAL_GAP_SWEEP_SHARED_SECRET")!;

// "The next several hours" per the PRD — a shift starting within this
// window counts as coverage; nothing scheduled inside it is a gap.
const GAP_WINDOW_HOURS = 6;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const providedSecret = req.headers.get("x-hospital-gap-sweep-secret");
  if (providedSecret !== HOSPITAL_GAP_SWEEP_SHARED_SECRET) return errorResponse("Invalid credentials", 401);

  const admin = supabaseAdmin();
  const now = new Date();
  const windowEnd = new Date(now.getTime() + GAP_WINDOW_HOURS * 60 * 60 * 1000);

  const { data: stays, error } = await admin
    .from("hospital_stays")
    .select("id, elder_id")
    .eq("status", "active");
  if (error) return errorResponse(error.message, 500);

  const results: Array<{ stay_id: string; outcome: "covered" | "gap_reminder_enqueued" | "already_flagged" }> = [];

  for (const stay of stays ?? []) {
    // A shift covers the window if it's currently running or starts
    // inside it — cancelled/disputed bookings don't count as coverage.
    const { data: shifts } = await admin
      .from("hospital_stay_bookings")
      .select("booking_id, bookings!inner(status, scheduled_at)")
      .eq("hospital_stay_id", stay.id);

    const covering = (shifts ?? []).some((s) => {
      const booking = (s as unknown as { bookings: { status: string; scheduled_at: string } }).bookings;
      if (["cancelled", "disputed"].includes(booking.status)) return false;
      if (booking.status === "in_progress") return true;
      const startsAt = new Date(booking.scheduled_at);
      return startsAt <= windowEnd;
    });

    if (covering) {
      results.push({ stay_id: stay.id, outcome: "covered" });
      continue;
    }

    // One open gap reminder per stay at a time — a still-pending (or
    // sent-but-not-yet-dismissed) reminder means family already knows;
    // re-enqueueing every sweep run would be exactly the notification
    // storm the platform's anti-fatigue principle exists to prevent.
    const { data: existing } = await admin
      .from("reminders")
      .select("id")
      .eq("source_type", "hospital_stay_gap")
      .eq("source_id", stay.id)
      .in("status", ["pending", "sent", "snoozed"])
      .limit(1)
      .maybeSingle();
    if (existing) {
      results.push({ stay_id: stay.id, outcome: "already_flagged" });
      continue;
    }

    await admin.from("reminders").insert({
      elder_id: stay.elder_id,
      source_type: "hospital_stay_gap",
      source_id: stay.id,
      remind_at: now.toISOString(),
      recipient_scope: "family",
    });
    results.push({ stay_id: stay.id, outcome: "gap_reminder_enqueued" });
  }

  return jsonResponse({ processed: results.length, results });
});
