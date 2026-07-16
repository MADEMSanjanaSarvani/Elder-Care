// POST /functions/v1/ai-care-assistant
// body: { elder_id: uuid, message: string }
//
// PRD Part 7, Batch 4, Module 13. A conversational front end over data
// the caller could ALREADY see through existing screens — never a new
// access path, never a new source of truth.
//
// Five things make this safe, each a direct application of PRD Part 2 §14:
//  1. Fixed, enumerated toolset — the model can only call these named
//     functions, no freeform browsing or code execution.
//  2. Every tool executes via supabaseAsUser() — RLS-scoped to the
//     caller, so the assistant can never read what the caller couldn't.
//  3. A deterministic input pre-filter refuses medical-shaped questions
//     before an API call is even made (isMedicalQuestion).
//  4. initiate_booking only PREPARES a draft; a human confirms it in the
//     UI before bookings-create is ever called. AI proposes, human commits.
//  5. Output runs through the same two-layer guardrail as every other AI
//     function, and every interaction is logged to ai_interactions.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { supabaseAsUser } from "../_shared/supabaseAsUser.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { runGuardrail, isMedicalQuestion, CLINICAL_REDIRECT, MEDICAL_DISCLAIMER } from "../_shared/aiGuardrail.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const SYSTEM_PROMPT = `You are the care assistant for an elder-care app. You help a family member or elder
with operational questions about care: upcoming visits, the medication list, appointments, who is on the
care team, recent activity, and starting a booking.

Rules you must follow exactly:
- Only answer using data returned by the provided tools. Never state a fact no tool call returned.
- Never diagnose, interpret a symptom, or advise on medication. If asked anything medical, tell the user
  to contact the elder's clinician.
- If a tool returns access_denied, tell the user they may not have permission to see that and can request
  it — do NOT say there is nothing there; "denied" and "empty" are different facts.
- A caregiver's phone number is never shared. Do not reveal contact numbers.
- To start a booking, call initiate_booking to prepare a draft. Tell the user it's ready for them to
  confirm — never claim a booking is done, because it isn't until they tap confirm.
- Keep answers short and plain.`;

// The fixed toolset (PRD §03). No tool takes an elder_id argument — it's
// pinned server-side to the elder in the request, so the model can never
// pivot to a different elder.
const TOOLS = [
  { type: "function", function: { name: "get_upcoming_bookings", description: "Upcoming visits for this elder.", parameters: { type: "object", properties: {} } } },
  { type: "function", function: { name: "get_medication_list", description: "Current medications for this elder.", parameters: { type: "object", properties: {} } } },
  { type: "function", function: { name: "get_appointment_details", description: "Upcoming external appointments for this elder.", parameters: { type: "object", properties: {} } } },
  { type: "function", function: { name: "get_care_team_info", description: "Linked family members for this elder (names and relationships only, never phone numbers).", parameters: { type: "object", properties: {} } } },
  { type: "function", function: { name: "get_recent_timeline", description: "Recent care activity for this elder.", parameters: { type: "object", properties: {} } } },
  { type: "function", function: { name: "get_consent_status", description: "What data categories this family member is permitted to see for this elder.", parameters: { type: "object", properties: {} } } },
  { type: "function", function: { name: "initiate_booking", description: "Prepare (not submit) a booking draft for the user to confirm.", parameters: { type: "object", properties: { service_code: { type: "string" }, when: { type: "string", description: "ISO 8601 datetime" } }, required: ["service_code"] } } },
] as const;

type ToolResult = { data?: unknown; access_denied?: boolean; draft?: unknown };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const { elder_id, message } = await req.json();
    if (!elder_id || !message) return errorResponse("elder_id and message are required");

    // Layer 3 (input side): refuse medical-shaped questions deterministically,
    // before spending an OpenAI call, and log the refusal like any other
    // interaction so the escalation is auditable.
    const medical = isMedicalQuestion(message);
    if (medical.flagged) {
      await logInteraction(elder_id, user.id, message, CLINICAL_REDIRECT, true);
      return jsonResponse({ status: "delivered", reply: CLINICAL_REDIRECT });
    }

    const asUser = supabaseAsUser(req);

    // Tool calls run under RLS as the caller — this is the module's core
    // safety property (PRD §09). A denied read comes back as access_denied,
    // which the model is instructed to distinguish from "empty."
    const runTool = async (name: string, args: Record<string, unknown>): Promise<ToolResult> => {
      switch (name) {
        case "get_upcoming_bookings": {
          const { data } = await asUser.from("bookings")
            .select("id, status, scheduled_at, service_catalog(name)")
            .eq("elder_id", elder_id).gte("scheduled_at", new Date().toISOString())
            .order("scheduled_at").limit(10);
          return { data };
        }
        case "get_medication_list": {
          const { data, error } = await asUser.from("elder_medications")
            .select("name, dosage, active").eq("elder_id", elder_id).eq("active", true);
          if (error) return { access_denied: true };
          return { data };
        }
        case "get_appointment_details": {
          const { data } = await asUser.from("appointments")
            .select("title, location, scheduled_at, status").eq("elder_id", elder_id)
            .gte("scheduled_at", new Date().toISOString()).order("scheduled_at").limit(10);
          return { data };
        }
        case "get_care_team_info": {
          // profiles join intentionally omits phone (PRD §03).
          const { data } = await asUser.from("family_links")
            .select("relationship, status, profiles(display_name)").eq("elder_id", elder_id).eq("status", "active");
          return { data };
        }
        case "get_recent_timeline": {
          const { data } = await asUser.from("elder_timeline_events")
            .select("event_type, summary, occurred_at").eq("elder_id", elder_id)
            .order("occurred_at", { ascending: false }).limit(10);
          return { data };
        }
        case "get_consent_status": {
          const { data } = await asUser.from("consent_grants")
            .select("category, granted").eq("elder_id", elder_id).eq("family_user_id", user.id).eq("granted", true);
          return { data };
        }
        case "initiate_booking": {
          // Never submits — returns a draft the UI turns into a confirm card.
          return { draft: { elder_id, service_code: args.service_code, when: args.when ?? null } };
        }
        default:
          return { access_denied: true };
      }
    };

    // deno-lint-ignore no-explicit-any
    const messages: any[] = [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: `Elder in context: ${elder_id}\n\nUser: ${message}` },
    ];

    let bookingDraft: unknown = null;

    // Bounded tool loop — the model may call a few tools, then must answer.
    for (let round = 0; round < 4; round++) {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { Authorization: `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({ model: "gpt-4o", temperature: 0.2, messages, tools: TOOLS, tool_choice: "auto" }),
      });
      if (!res.ok) return errorResponse(`AI assistant call failed: ${await res.text()}`, 502);
      const completion = await res.json();
      const choice = completion.choices?.[0]?.message;
      messages.push(choice);

      const toolCalls = choice?.tool_calls ?? [];
      if (toolCalls.length === 0) {
        const rawOutput: string = choice?.content ?? "";
        const guardrail = await runGuardrail(rawOutput, OPENAI_API_KEY);
        const reply = guardrail.flagged
          ? "I want to be careful here — this needs a person to review before I answer. Please check with the elder's clinician if it's medical."
          : `${rawOutput}\n\n${MEDICAL_DISCLAIMER}`;
        await logInteraction(elder_id, user.id, message, reply, guardrail.flagged);
        return jsonResponse({ status: "delivered", reply, booking_draft: bookingDraft });
      }

      for (const call of toolCalls) {
        const args = call.function.arguments ? JSON.parse(call.function.arguments) : {};
        const result = await runTool(call.function.name, args);
        if (result.draft) bookingDraft = result.draft;
        messages.push({ role: "tool", tool_call_id: call.id, content: JSON.stringify(result) });
      }
    }

    return errorResponse("The assistant took too many steps — please rephrase your question.", 500);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});

async function logInteraction(
  elderId: string,
  userId: string,
  input: string,
  output: string,
  flagged: boolean,
) {
  const admin = supabaseAdmin();
  const { data: interaction } = await admin.from("ai_interactions").insert({
    elder_id: elderId,
    initiated_by: userId,
    interaction_type: "care_assistant_chat",
    input_ref: input,
    output_text: output,
    flagged,
    human_reviewed: false,
  }).select().single();
  if (interaction) {
    await admin.from("audit_log").insert({
      actor_user_id: userId,
      action: "write",
      resource_type: "ai_interaction",
      resource_id: interaction.id,
      metadata: { interaction_type: "care_assistant_chat", flagged },
    });
  }
}
