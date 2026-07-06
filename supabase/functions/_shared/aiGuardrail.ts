// PRD Part 2 §14: "don't diagnose" is a system constraint with multiple
// independent layers, not a single prompt instruction trusted on its own.
// This module is layer 2 (the output guardrail) — layer 1 is the scoped
// system prompt in each function, layer 3 is the mandatory disclaimer,
// layer 4 is the ai_interactions log this all feeds.

export interface GuardrailResult {
  flagged: boolean;
  reason?: string;
}

// Layer 2a: cheap, deterministic pattern match for the clearest cases —
// specific dosage instructions and direct diagnostic assertions. This is
// intentionally over-inclusive (a false positive just means a human
// reviews a safe summary before it's shown) rather than under-inclusive.
const DOSAGE_OR_DIAGNOSIS_PATTERNS: RegExp[] = [
  /\b(increase|decrease|double|halve|stop|skip)\s+(the\s+)?(dose|dosage|medication|tablet|pill)/i,
  /\btake\s+\d+\s*(mg|ml|mcg|tablets?|pills?)/i,
  /\byou\s+(have|are\s+suffering\s+from|are\s+diagnosed\s+with)\b/i,
  /\bthis\s+(means|indicates|suggests)\s+(a|an|that)?\s*\b(disease|condition|disorder|infection|cancer|diabetes)\b/i,
  /\b(likely|probably|definitely)\s+(has|have)\s+\b(a|an)\b.*\b(disease|condition|disorder)\b/i,
];

function patternMatch(text: string): GuardrailResult {
  for (const pattern of DOSAGE_OR_DIAGNOSIS_PATTERNS) {
    if (pattern.test(text)) {
      return { flagged: true, reason: `Matched dosage/diagnosis pattern: ${pattern.source}` };
    }
  }
  return { flagged: false };
}

// Layer 2b: a second, cheap LLM call whose only job is to say SAFE or
// FLAGGED — deliberately a different, narrower prompt than the generation
// call, so a prompt-injection attempt that fools the generation call still
// has to separately fool this one.
async function modelClassify(text: string, openaiApiKey: string): Promise<GuardrailResult> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${openaiApiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0,
      messages: [
        {
          role: "system",
          content:
            "You are a safety classifier for an elder-care app. Given a piece of text, reply with exactly " +
            'SAFE if it contains no medical diagnosis, no medication dosage instruction, and no clinical ' +
            'judgment call — or FLAGGED: <short reason> if it does. Reply with nothing else.',
        },
        { role: "user", content: text },
      ],
    }),
  });
  if (!res.ok) {
    // Fail closed: if the classifier itself is unavailable, treat the
    // content as flagged rather than silently skipping the check.
    return { flagged: true, reason: "Classifier call failed; failing closed" };
  }
  const data = await res.json();
  const verdict: string = data.choices?.[0]?.message?.content?.trim() ?? "";
  if (verdict.startsWith("FLAGGED")) {
    return { flagged: true, reason: verdict.replace(/^FLAGGED:?\s*/, "") };
  }
  return { flagged: false };
}

export async function runGuardrail(text: string, openaiApiKey: string): Promise<GuardrailResult> {
  const patternResult = patternMatch(text);
  if (patternResult.flagged) return patternResult;
  return modelClassify(text, openaiApiKey);
}

export const MEDICAL_DISCLAIMER =
  "This summary is generated to help you stay informed and is not medical advice. " +
  "For anything about medication, symptoms, or treatment, please confirm with your clinician.";
