// POST /functions/v1/ai-visit-report-generate
//
// PRD Part 7, Batch 4, Module 14 (AI Visit Reports). A periodic (weekly)
// plain-language digest of what already happened for an elder — built
// only from content that already passed the guardrail once (delivered
// timeline events, completed visits, check-in counts), never raw clinical
// text. Same two-layer guardrail + mandatory disclaimer + full
// ai_interactions-shaped logging (here, ai_visit_reports) as every other
// AI output, with the flagged-hold rule from 0016.
//
// No user JWT — scheduled (n8n/cron), shared-secret header, same pattern
// as the other sweeps.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { runGuardrail, MEDICAL_DISCLAIMER } from "../_shared/aiGuardrail.ts";

const REPORTS_SWEEP_SHARED_SECRET = Deno.env.get("REPORTS_SWEEP_SHARED_SECRET")!;
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const PERIOD_DAYS = 7;

const SYSTEM_PROMPT = `You write a short, warm weekly summary for an elder's family, from a structured list of
what happened. Rules:
- Only use the facts provided. Never add, infer, or interpret anything medical.
- Never diagnose or mention medication changes.
- 3-4 sentences, plain and reassuring where the facts allow, factual where they don't.
- Write in the requested language.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const providedSecret = req.headers.get("x-reports-sweep-secret");
  if (providedSecret !== REPORTS_SWEEP_SHARED_SECRET) return errorResponse("Invalid credentials", 401);

  const admin = supabaseAdmin();
  const now = new Date();
  const periodStart = new Date(now.getTime() - PERIOD_DAYS * 24 * 60 * 60 * 1000);
  const periodStartDate = periodStart.toISOString().slice(0, 10);
  const periodEndDate = now.toISOString().slice(0, 10);

  const { data: elders, error } = await admin
    .from("elder_profiles")
    .select("id, primary_language");
  if (error) return errorResponse(error.message, 500);

  const results: Array<{ elder_id: string; outcome: "generated" | "flagged" | "skipped_no_activity" | "already_exists" }> = [];

  for (const elder of elders ?? []) {
    // Idempotent: one report per elder per period.
    const { data: existing } = await admin
      .from("ai_visit_reports")
      .select("id").eq("elder_id", elder.id).eq("period_start", periodStartDate).eq("period_end", periodEndDate)
      .maybeSingle();
    if (existing) {
      results.push({ elder_id: elder.id, outcome: "already_exists" });
      continue;
    }

    // Source material: only already-guardrailed, already-happened facts.
    const { data: events } = await admin
      .from("elder_timeline_events")
      .select("event_type, summary, occurred_at")
      .eq("elder_id", elder.id).gte("occurred_at", periodStart.toISOString())
      .order("occurred_at");
    const { count: checkinCount } = await admin
      .from("daily_checkins")
      .select("id", { count: "exact", head: true })
      .eq("elder_id", elder.id).gte("checked_in_at", periodStart.toISOString());

    if ((events?.length ?? 0) === 0 && (checkinCount ?? 0) === 0) {
      results.push({ elder_id: elder.id, outcome: "skipped_no_activity" });
      continue;
    }

    const facts = [
      `Check-ins this week: ${checkinCount ?? 0}.`,
      ...(events ?? []).map((e) => `${e.occurred_at.slice(0, 10)}: ${e.summary}`),
    ].join("\n");

    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "gpt-4o",
        temperature: 0.3,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: `Output language: ${elder.primary_language}\n\nWhat happened:\n${facts}` },
        ],
      }),
    });
    if (!res.ok) {
      results.push({ elder_id: elder.id, outcome: "skipped_no_activity" });
      continue;
    }
    const completion = await res.json();
    const rawOutput: string = completion.choices?.[0]?.message?.content ?? "";

    const guardrail = await runGuardrail(rawOutput, OPENAI_API_KEY);
    const reportText = guardrail.flagged ? rawOutput : `${rawOutput}\n\n${MEDICAL_DISCLAIMER}`;

    await admin.from("ai_visit_reports").insert({
      elder_id: elder.id,
      period_start: periodStartDate,
      period_end: periodEndDate,
      report_text: reportText,
      flagged: guardrail.flagged,
      human_reviewed: false,
    });

    results.push({ elder_id: elder.id, outcome: guardrail.flagged ? "flagged" : "generated" });
  }

  return jsonResponse({ processed: results.length, results });
});
