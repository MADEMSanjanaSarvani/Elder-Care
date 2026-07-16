// POST /functions/v1/ai-translate
// body: { text: string, target_language: string, elder_id?: uuid, booking_id?: uuid }
//
// PRD Part 1 §05 / Part 2 §14: multilingual communication between a
// caregiver and a family member. Narrow, single-purpose tool — translate
// only, no interpretation — but still runs the same output guardrail as
// visit summaries, since translated text can just as easily smuggle
// through a dosage instruction as generated text can.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { runGuardrail } from "../_shared/aiGuardrail.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";

const SYSTEM_PROMPT = `Translate the user's message to the requested target language.
Rules you must follow exactly:
- Translate only. Do not add, remove, summarize, or interpret meaning.
- Do not answer questions contained in the text — translate them as questions.
- Output only the translated text, nothing else.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);
  if (!OPENAI_API_KEY) return errorResponse("Translation isn't available yet — it's still being set up.", 503);

  try {
    const user = await requireUser(req);
    const { text, target_language, elder_id, booking_id } = await req.json();
    if (!text || !target_language) return errorResponse("text and target_language are required");

    const completionRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "gpt-4o",
        temperature: 0,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: `Target language: ${target_language}\n\nText:\n${text}` },
        ],
      }),
    });
    if (!completionRes.ok) return errorResponse(`Translation failed: ${await completionRes.text()}`, 502);
    const completion = await completionRes.json();
    const translated: string = completion.choices?.[0]?.message?.content ?? "";

    const guardrail = await runGuardrail(translated, OPENAI_API_KEY);

    if (elder_id) {
      const admin = supabaseAdmin();
      const { data: interaction } = await admin
        .from("ai_interactions")
        .insert({
          elder_id,
          booking_id: booking_id ?? null,
          initiated_by: user.id,
          interaction_type: "translation",
          input_ref: text,
          output_text: translated,
          flagged: guardrail.flagged,
          human_reviewed: false,
        })
        .select("id")
        .single();

      if (interaction) {
        await admin.from("audit_log").insert({
          actor_user_id: user.id,
          action: "write",
          resource_type: "ai_interaction",
          resource_id: interaction.id,
          metadata: { interaction_type: "translation", flagged: guardrail.flagged },
        });
      }
    }

    if (guardrail.flagged) {
      return jsonResponse({
        status: "pending_review",
        message: "This message needs a quick review before it's shown — translation of medical instructions is held for a human to confirm.",
      }, 202);
    }

    return jsonResponse({ status: "delivered", translated });
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
