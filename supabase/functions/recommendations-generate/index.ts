// POST /functions/v1/recommendations-generate
//
// PRD Part 7, Batch 4, Module 15 (AI Recommendation Engine). The highest
// scope-creep risk in the whole 25-module plan, scoped hard on purpose:
// this is a RULES ENGINE, not a language model deciding outcomes. Every
// suggestion is a closed, enumerated type fired by a deterministic SQL
// condition over structured data; the trigger_metric records exactly what
// fired it, for auditability. No generative AI is used here at all in this
// implementation — the optional LLM phrasing step the PRD allows is a
// pure defense-in-depth nicety on top of the real (deterministic) control,
// deferred rather than built, so nothing here can hallucinate a
// recommendation. Every suggestion_text below is a fixed template.
//
// No user JWT — scheduled (n8n/cron), shared-secret header.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const RECOMMENDATIONS_SWEEP_SHARED_SECRET = Deno.env.get("RECOMMENDATIONS_SWEEP_SHARED_SECRET")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 401);

  const providedSecret = req.headers.get("x-recommendations-sweep-secret");
  if (providedSecret !== RECOMMENDATIONS_SWEEP_SHARED_SECRET) return errorResponse("Invalid credentials", 401);

  const admin = supabaseAdmin();
  const now = new Date();

  const { data: elders, error } = await admin.from("elder_profiles").select("id");
  if (error) return errorResponse(error.message, 500);

  let created = 0;

  for (const elder of elders ?? []) {
    // Each rule below inserts at most one pending suggestion of its type
    // per elder — an existing pending one of the same type means the
    // family already has the nudge; re-inserting would be notification
    // spam (same anti-fatigue principle as everywhere else).
    const suggestOnce = async (
      suggestionType: string,
      triggerMetric: Record<string, unknown>,
      text: string,
    ) => {
      const { data: existing } = await admin.from("care_suggestions")
        .select("id").eq("elder_id", elder.id).eq("suggestion_type", suggestionType).eq("status", "pending")
        .limit(1).maybeSingle();
      if (existing) return;
      const { error: insErr } = await admin.from("care_suggestions").insert({
        elder_id: elder.id,
        suggestion_type: suggestionType,
        trigger_metric: triggerMetric,
        suggestion_text: text,
      });
      if (!insErr) created++;
    };

    // Rule: no completed visit in 14 days.
    const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000).toISOString();
    const { count: recentVisits } = await admin.from("bookings")
      .select("id", { count: "exact", head: true })
      .eq("elder_id", elder.id).eq("status", "completed").gte("otp_end_verified_at", fourteenDaysAgo);
    if ((recentVisits ?? 0) === 0) {
      await suggestOnce("no_recent_visit", { days: 14 },
        "It's been a couple of weeks since the last visit — you might want to book one.");
    }

    // Rule: a medication is low on stock.
    const { data: lowStock } = await admin.from("medication_stock")
      .select("quantity_on_hand, refill_threshold, elder_medications!inner(name, elder_id)")
      .eq("elder_medications.elder_id", elder.id);
    for (const stock of lowStock ?? []) {
      const onHand = stock.quantity_on_hand as number;
      const threshold = stock.refill_threshold as number;
      const name = (stock as unknown as { elder_medications: { name: string } }).elder_medications.name;
      if (onHand <= threshold) {
        await suggestOnce("refill_due_soon", { medication: name, on_hand: onHand },
          `${name} is running low — consider booking a medicine pickup.`);
      }
    }

    // Rule: no check-in in 2 days despite an active schedule.
    const { data: schedule } = await admin.from("checkin_schedules")
      .select("elder_id").eq("elder_id", elder.id).maybeSingle();
    if (schedule) {
      const twoDaysAgo = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000).toISOString();
      const { count: recentCheckins } = await admin.from("daily_checkins")
        .select("id", { count: "exact", head: true })
        .eq("elder_id", elder.id).gte("checked_in_at", twoDaysAgo);
      if ((recentCheckins ?? 0) === 0) {
        await suggestOnce("checkin_streak_broken", { days: 2 },
          "No check-in in the last couple of days — a quick call might be nice.");
      }
    }

    // Rule: an upcoming appointment with no companion booked for it.
    const { data: appts } = await admin.from("appointments")
      .select("id, related_booking_id, scheduled_at")
      .eq("elder_id", elder.id).eq("status", "scheduled").is("related_booking_id", null)
      .gte("scheduled_at", now.toISOString());
    if ((appts?.length ?? 0) > 0) {
      await suggestOnce("appointment_without_companion", { count: appts!.length },
        "There's an upcoming appointment with no companion booked — you can add one if help getting there would be useful.");
    }
  }

  return jsonResponse({ created });
});
