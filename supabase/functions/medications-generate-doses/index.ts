// POST /functions/v1/medications-generate-doses
//
// PRD Part 5, Batch 2, Module 5 (Medicine Management). No user JWT —
// triggered externally (n8n/cron) on a schedule, authenticated with a
// shared secret header, the same pattern as checkins-escalation-sweep and
// payouts-run.
//
// Schema note: elder_medications.schedule is jsonb with no format defined
// anywhere in the PRD or 0001_schema.sql beyond "turns a medication's
// schedule jsonb into concrete dose instances" — this function is the
// first place that format actually has to mean something, so it's
// defined here: { "times": ["08:00", "20:00"] }, a plain array of
// HH:mm strings. Compared against UTC wall-clock, not true per-elder
// timezone — the same simplification already made in
// checkins-escalation-sweep for the same reason (the pilot, Visakhapatnam,
// is single-timezone; real per-timezone handling is named Phase 2+ work,
// not built here or there).
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const MEDICATIONS_SWEEP_SHARED_SECRET = Deno.env.get("MEDICATIONS_SWEEP_SHARED_SECRET")!;

// "A few days ahead" per the PRD — 3 days, including today.
const ROLLING_WINDOW_DAYS = 3;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const providedSecret = req.headers.get("x-medications-sweep-secret");
  if (providedSecret !== MEDICATIONS_SWEEP_SHARED_SECRET) return errorResponse("Invalid credentials", 401);

  const admin = supabaseAdmin();

  const { data: medications, error } = await admin
    .from("elder_medications")
    .select("id, elder_id, schedule")
    .eq("active", true);
  if (error) return errorResponse(error.message, 500);

  let dosesCreated = 0;
  let remindersCreated = 0;

  for (const medication of medications ?? []) {
    const times = Array.isArray((medication.schedule as Record<string, unknown>)?.times)
      ? ((medication.schedule as { times: unknown[] }).times.filter((t) => typeof t === "string") as string[])
      : [];
    if (times.length === 0) continue; // e.g. PRN medications with no fixed schedule — see PRD §13, not handled by this sweep

    const rows: { medication_id: string; scheduled_at: string }[] = [];
    for (let dayOffset = 0; dayOffset < ROLLING_WINDOW_DAYS; dayOffset++) {
      const day = new Date();
      day.setUTCDate(day.getUTCDate() + dayOffset);
      const dateStr = day.toISOString().slice(0, 10);
      for (const time of times) {
        rows.push({ medication_id: medication.id, scheduled_at: `${dateStr}T${time}:00Z` });
      }
    }
    if (rows.length === 0) continue;

    // Idempotent: relies on medication_doses' unique(medication_id,
    // scheduled_at) constraint — a re-run of this sweep must never create
    // duplicate rows for the same medication/time. ignoreDuplicates means
    // only genuinely new rows come back from .select(), so the reminder
    // enqueue below never double-fires for a dose the sweep already saw.
    const { data: inserted, error: insertErr } = await admin
      .from("medication_doses")
      .upsert(rows, { onConflict: "medication_id,scheduled_at", ignoreDuplicates: true })
      .select("id, scheduled_at");
    if (insertErr) continue; // one medication's failure shouldn't abort the whole sweep

    dosesCreated += inserted?.length ?? 0;

    if (inserted && inserted.length > 0) {
      const reminderRows = inserted.map((dose) => ({
        elder_id: medication.elder_id,
        source_type: "medication_dose",
        source_id: dose.id,
        remind_at: dose.scheduled_at,
        recipient_scope: "both",
      }));
      const { error: reminderErr } = await admin.from("reminders").insert(reminderRows);
      if (!reminderErr) remindersCreated += reminderRows.length;
    }
  }

  return jsonResponse({ doses_created: dosesCreated, reminders_created: remindersCreated });
});
