// POST /functions/v1/checkins-escalation-sweep
//
// PRD Part 4, Batch 1, Module 3 (Daily Check-ins System). No user JWT —
// triggered externally (n8n/cron) on a schedule, authenticated with a
// shared secret header, the same pattern as verification-idfy-webhook and
// payouts-run.
//
// Simplification versus the full PRD design: the doc describes a
// two-stage flow (a gentle in-app nudge to the elder first, escalating to
// family only if the elder doesn't respond within a further window).
// This pass goes straight to family escalation once the expected
// check-in time has passed with nothing to satisfy it — the nudge stage
// needs additional state (when the elder was last nudged today) that
// isn't in the schema yet, and is deferred rather than built half-right.
//
// Also per the PRD: a completed booking on a given day already proves
// the elder is fine, so it satisfies that day's check-in without a
// redundant nudge.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const CHECKINS_SWEEP_SHARED_SECRET = Deno.env.get("CHECKINS_SWEEP_SHARED_SECRET")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const providedSecret = req.headers.get("x-checkins-sweep-secret");
  if (providedSecret !== CHECKINS_SWEEP_SHARED_SECRET) return errorResponse("Invalid credentials", 401);

  const admin = supabaseAdmin();
  const nowIso = new Date().toISOString();
  const today = nowIso.slice(0, 10);
  const todayStart = `${today}T00:00:00Z`;

  const { data: schedules, error } = await admin
    .from("checkin_schedules")
    .select("elder_id, expected_by_time, timezone, paused_until, escalation_contact_family_user_id")
    .or(`paused_until.is.null,paused_until.lt.${today}`);
  if (error) return errorResponse(error.message, 500);

  const results: Array<{ elder_id: string; outcome: "satisfied" | "escalated" | "not_due" | "already_escalated" }> = [];

  for (const schedule of schedules ?? []) {
    // MVP: compares expected_by_time against UTC wall-clock rather than a
    // true per-timezone conversion — the pilot (Visakhapatnam) is
    // single-timezone; per-timezone batching is a named Phase 2+ need in
    // the PRD, not built here.
    const expectedToday = new Date(`${today}T${schedule.expected_by_time}Z`);
    if (new Date(nowIso) < expectedToday) {
      results.push({ elder_id: schedule.elder_id, outcome: "not_due" });
      continue;
    }

    const { data: checkin } = await admin
      .from("daily_checkins")
      .select("id")
      .eq("elder_id", schedule.elder_id)
      .gte("checked_in_at", todayStart)
      .maybeSingle();

    const { data: completedBooking } = await admin
      .from("bookings")
      .select("id")
      .eq("elder_id", schedule.elder_id)
      .eq("status", "completed")
      .gte("otp_end_verified_at", todayStart)
      .maybeSingle();

    if (checkin || completedBooking) {
      results.push({ elder_id: schedule.elder_id, outcome: "satisfied" });
      continue;
    }

    const { data: existingEscalation } = await admin
      .from("checkin_escalations")
      .select("id")
      .eq("elder_id", schedule.elder_id)
      .eq("date", today)
      .maybeSingle();
    if (existingEscalation) {
      results.push({ elder_id: schedule.elder_id, outcome: "already_escalated" });
      continue;
    }

    const { data: escalation, error: escalationErr } = await admin
      .from("checkin_escalations")
      .insert({ elder_id: schedule.elder_id, date: today })
      .select()
      .single();
    if (escalationErr) {
      results.push({ elder_id: schedule.elder_id, outcome: "not_due" });
      continue;
    }

    const { data: elder } = await admin
      .from("elder_profiles")
      .select("display_name")
      .eq("id", schedule.elder_id)
      .single();

    const recipientIds: string[] = [];
    if (schedule.escalation_contact_family_user_id) {
      recipientIds.push(schedule.escalation_contact_family_user_id);
    } else {
      const { data: familyLinks } = await admin
        .from("family_links")
        .select("family_user_id")
        .eq("elder_id", schedule.elder_id)
        .eq("status", "active");
      recipientIds.push(...(familyLinks ?? []).map((f) => f.family_user_id));
    }

    if (recipientIds.length > 0) {
      await admin.from("notifications").insert(
        recipientIds.map((uid) => ({
          user_id: uid,
          type: "checkin_missed_escalation",
          payload: {
            elder_id: schedule.elder_id,
            elder_name: elder?.display_name,
            escalation_id: escalation.id,
            date: today,
          },
        })),
      );
    }

    // Fire-and-forget: feeds the Elder Care Timeline (PRD Part 4, Batch 1).
    await admin.from("elder_timeline_events").insert({
      elder_id: schedule.elder_id,
      event_type: "checkin_missed",
      category: "wellbeing_checkins",
      summary: "Missed daily check-in",
      metadata: { date: today },
    });

    results.push({ elder_id: schedule.elder_id, outcome: "escalated" });
  }

  return jsonResponse({ processed: results.length, results });
});
