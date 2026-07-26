// POST /functions/v1/ai-visit-summary
// body: { booking_id: uuid, raw_notes: string }
//
// PRD Part 2 §14: turns a caregiver's raw visit notes into a plain-language
// family summary, in the elder's own language, with a fixed system prompt
// (layer 1), an output guardrail (layer 2, _shared/aiGuardrail.ts), a
// mandatory disclaimer (layer 3), and full logging to ai_interactions
// (layer 4). A flagged output is held for human review, never delivered.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { runGuardrail, MEDICAL_DISCLAIMER } from "../_shared/aiGuardrail.ts";
import { aiProvider } from "../_shared/aiProvider.ts";

const provider = aiProvider();

const SYSTEM_PROMPT = `You summarize an in-home caregiver's visit notes for the elder's family.
Rules you must follow exactly:
- Write a short, factual, plain-language summary of what happened during the visit.
- Never diagnose a condition, interpret a symptom, or suggest a medication change.
- If the notes contain anything that requires clinical judgment (a new symptom, a
  medication question, anything concerning), do not interpret it — instead write:
  "This needs a clinician's review: <quote the relevant part of the notes>".
- Do not invent details that are not in the notes.
- Write your entire response in the requested output language.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);
  if (!provider) return errorResponse("Visit summaries aren't available yet — still being set up.", 503);

  try {
    const user = await requireUser(req);
    const { booking_id, raw_notes } = await req.json();
    if (!booking_id || !raw_notes) return errorResponse("booking_id and raw_notes are required");

    const admin = supabaseAdmin();
    const { data: booking, error } = await admin
      .from("bookings")
      .select("id, elder_id, caregivers(user_id), elder_profiles(primary_language)")
      .eq("id", booking_id)
      .single();
    if (error || !booking) return errorResponse("Booking not found", 404);

    const assignedUserId = (booking as unknown as { caregivers: { user_id: string } }).caregivers?.user_id;
    const isAdmin = (await admin.from("profiles").select("role").eq("id", user.id).single()).data?.role === "admin";
    if (assignedUserId !== user.id && !isAdmin) {
      return errorResponse("Only the assigned caregiver may submit visit notes for this booking", 403);
    }

    const language = (booking as unknown as { elder_profiles: { primary_language: string } }).elder_profiles.primary_language;

    const completionRes = await fetch(provider.chatUrl, {
      method: "POST",
      headers: { Authorization: `Bearer ${provider.apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: provider.model,
        temperature: 0.2,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: `Output language: ${language}\n\nCaregiver's raw notes:\n${raw_notes}` },
        ],
      }),
    });
    if (!completionRes.ok) return errorResponse(`AI summary generation failed: ${await completionRes.text()}`, 502);
    const completion = await completionRes.json();
    const rawOutput: string = completion.choices?.[0]?.message?.content ?? "";

    const guardrail = await runGuardrail(rawOutput, provider);
    const finalOutput = guardrail.flagged ? rawOutput : `${rawOutput}\n\n${MEDICAL_DISCLAIMER}`;

    const { data: interaction, error: logErr } = await admin
      .from("ai_interactions")
      .insert({
        elder_id: booking.elder_id,
        booking_id,
        initiated_by: user.id,
        interaction_type: "visit_summary",
        input_ref: raw_notes,
        output_text: finalOutput,
        flagged: guardrail.flagged,
        human_reviewed: false,
      })
      .select()
      .single();
    if (logErr) return errorResponse(logErr.message, 500);

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "ai_interaction",
      resource_id: interaction.id,
      metadata: { interaction_type: "visit_summary", flagged: guardrail.flagged },
    });

    if (guardrail.flagged) {
      // Never write a flagged output to family-visible storage — it stays
      // in ai_interactions (admin-visible for review) only, per Part 2 §14
      // "held for human review, never delivered."
      return jsonResponse({
        status: "pending_review",
        message: "This summary needs a quick human review before it's shared — we'll notify the family once it's ready.",
        interaction_id: interaction.id,
      }, 202);
    }

    await admin.from("elder_health_notes").insert({
      elder_id: booking.elder_id,
      booking_id,
      note: finalOutput,
      source: "ai_summary",
      created_by: user.id,
    });

    // Fire-and-forget: feeds the Elder Care Timeline (PRD Part 4, Batch 1).
    // Only logged on the delivered path — a flagged, held-for-review output
    // was never actually shown to family, so it isn't a real timeline event yet.
    await admin.from("elder_timeline_events").insert({
      elder_id: booking.elder_id,
      event_type: "health_note_added",
      category: "health_notes",
      actor_user_id: user.id,
      related_booking_id: booking_id,
      summary: "Visit summary added",
      metadata: { interaction_id: interaction.id },
    });

    return jsonResponse({ status: "delivered", summary: finalOutput, interaction_id: interaction.id });
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
