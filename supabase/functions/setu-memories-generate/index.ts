// POST /functions/v1/setu-memories-generate
//
// SETU Memories — the emotional heart of the family experience. Turns a
// day's real, structured data (medication doses, the daily check-in, and
// timeline events like companion visits) into one warm, human sentence:
// "Amma took all her medicines, checked in feeling happy, and had a
// companion visit today." Family peace of mind, in a single glance.
//
// Deliberately NOT a language model. Every phrase below is a fixed template
// keyed off a deterministic condition over structured data, so it cannot
// hallucinate and works with zero AI keys configured — essential for a
// pilot where reliability beats flourish. (The PRD's optional LLM
// re-phrasing step is a defense-in-depth nicety, deferred, not built.)
//
// Auth: called with the user's JWT. We first confirm the caller may see
// this elder AT ALL by reading the elder row AS the caller (RLS enforces
// self / linked-family / admin). Only then do we assemble the day from
// the service role and upsert the memory (the table is admin-write only).
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { supabaseAsUser } from "../_shared/supabaseAsUser.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

interface Highlight {
  icon: string; // a Material icon name the app maps to an IconData
  text: string;
}

// A mood string ("happy", "okay", "sad", …) → a warm clause + icon.
function moodClause(mood: string | null): { clause: string | null; highlight: Highlight | null } {
  if (!mood) return { clause: null, highlight: null };
  const m = mood.toLowerCase();
  const map: Record<string, { clause: string; icon: string }> = {
    happy: { clause: "checked in feeling happy", icon: "sentiment_very_satisfied" },
    good: { clause: "checked in feeling good", icon: "sentiment_satisfied" },
    okay: { clause: "checked in feeling okay", icon: "sentiment_neutral" },
    fine: { clause: "checked in feeling okay", icon: "sentiment_neutral" },
    tired: { clause: "checked in feeling a little tired", icon: "sentiment_dissatisfied" },
    unwell: { clause: "checked in feeling unwell", icon: "sick" },
    sad: { clause: "checked in feeling low", icon: "sentiment_dissatisfied" },
  };
  const entry = map[m] ?? { clause: `checked in feeling ${m}`, icon: "mood" };
  return {
    clause: entry.clause,
    highlight: { icon: entry.icon, text: `Mood: ${mood}` },
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  let body: { elder_id?: string; date?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }
  const elderId = body.elder_id;
  if (!elderId) return errorResponse("elder_id is required", 400);

  // The day to summarize (local calendar day, default today). We store the
  // date; the window is [00:00, next 00:00) in UTC terms of that date.
  const dateStr = body.date ?? new Date().toISOString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) return errorResponse("date must be YYYY-MM-DD", 400);
  const dayStart = new Date(`${dateStr}T00:00:00.000Z`);
  const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);

  // 1) Authorize AS the caller: can they see this elder at all? RLS on
  //    elder_profiles answers self / linked-family / admin in one read.
  const asUser = supabaseAsUser(req);
  const { data: elder, error: elderErr } = await asUser
    .from("elder_profiles")
    .select("id, display_name")
    .eq("id", elderId)
    .maybeSingle();
  if (elderErr) return errorResponse(elderErr.message, 500);
  if (!elder) return errorResponse("Not found", 404);

  const displayName = (elder.display_name as string | null) ?? "They";
  const firstName = displayName.split(" ")[0];

  // 2) Assemble the day from the service role.
  const admin = supabaseAdmin();

  const { data: doses } = await admin
    .from("medication_doses")
    .select("status, elder_medications!inner(elder_id)")
    .eq("elder_medications.elder_id", elderId)
    .gte("scheduled_at", dayStart.toISOString())
    .lt("scheduled_at", dayEnd.toISOString());
  const medsTotal = doses?.length ?? 0;
  const medsTaken = (doses ?? []).filter((d) => d.status === "taken").length;

  const { data: checkin } = await admin
    .from("daily_checkins")
    .select("mood, checked_in_at")
    .eq("elder_id", elderId)
    .gte("checked_in_at", dayStart.toISOString())
    .lt("checked_in_at", dayEnd.toISOString())
    .order("checked_in_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  const { data: events } = await admin
    .from("elder_timeline_events")
    .select("event_type, summary, occurred_at")
    .eq("elder_id", elderId)
    .gte("occurred_at", dayStart.toISOString())
    .lt("occurred_at", dayEnd.toISOString())
    .order("occurred_at", { ascending: true });

  // 3) Build the warm summary + highlight chips deterministically.
  const clauses: string[] = [];
  const highlights: Highlight[] = [];

  if (medsTotal > 0) {
    if (medsTaken >= medsTotal) {
      clauses.push("took all the day's medicines");
    } else if (medsTaken > 0) {
      clauses.push(`took ${medsTaken} of ${medsTotal} medicines`);
    } else {
      clauses.push("has medicines still to take");
    }
    highlights.push({
      icon: "medication",
      text: `Medicines ${medsTaken}/${medsTotal}`,
    });
  }

  const { clause: mClause, highlight: mHighlight } = moodClause(
    (checkin?.mood as string | null) ?? null,
  );
  if (mClause) clauses.push(mClause);
  if (mHighlight) highlights.push(mHighlight);

  // Companion visits are the warmest signal — surface them explicitly.
  const visitEvents = (events ?? []).filter(
    (e) => e.event_type === "companion_visit_completed" || e.event_type === "visit_completed",
  );
  if (visitEvents.length === 1) {
    clauses.push("had a companion visit");
    highlights.push({ icon: "volunteer_activism", text: "Companion visit" });
  } else if (visitEvents.length > 1) {
    clauses.push(`had ${visitEvents.length} companion visits`);
    highlights.push({ icon: "volunteer_activism", text: `${visitEvents.length} visits` });
  }

  let summary: string;
  if (clauses.length === 0) {
    summary = medsTotal === 0 && !checkin
      ? `A quiet day — nothing new logged for ${firstName} yet.`
      : `${firstName} had a calm day.`;
  } else if (clauses.length === 1) {
    summary = `${firstName} ${clauses[0]} today.`;
  } else {
    const last = clauses[clauses.length - 1];
    const head = clauses.slice(0, -1).join(", ");
    summary = `${firstName} ${head}, and ${last} today.`;
  }

  // 4) Upsert (one memory per elder per day).
  const { data: saved, error: upsertErr } = await admin
    .from("setu_memories")
    .upsert(
      {
        elder_id: elderId,
        memory_date: dateStr,
        summary,
        highlights,
        mood: (checkin?.mood as string | null) ?? null,
        generated_at: new Date().toISOString(),
      },
      { onConflict: "elder_id,memory_date" },
    )
    .select("id, elder_id, memory_date, summary, highlights, mood, generated_at")
    .single();
  if (upsertErr) return errorResponse(upsertErr.message, 500);

  return jsonResponse({ memory: saved });
});
