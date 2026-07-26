// Unit tests for the deterministic half of the AI guardrail (PRD Part 2
// §14). patternMatch is pure regex, tested directly with no network
// calls. runGuardrail's fallback to modelClassify (the OpenAI safety
// classifier) is tested by stubbing globalThis.fetch — there is no live
// OpenAI key available to call the real thing here, and a stub is the
// honest way to test that branch's logic rather than skipping it.
//
// Deliberately dependency-free — see testUtil.ts for why.
import { assertEquals, assertStringIncludes } from "./testUtil.ts";
import { patternMatch, runGuardrail, isMedicalQuestion } from "./aiGuardrail.ts";
import type { AiProvider } from "./aiProvider.ts";
// A stand-in provider so the classifier layer can be exercised without a live
// key. The fetch call is stubbed in each test, so only the shape matters.
const FAKE_PROVIDER: AiProvider = {
  name: "openai",
  chatUrl: "https://api.openai.com/v1/chat/completions",
  apiKey: "fake-key",
  model: "gpt-4o",
  fastModel: "gpt-4o-mini",
  trainsOnData: false,
};

Deno.test("patternMatch: flags an explicit dosage-change instruction", () => {
  const result = patternMatch("You should increase the dose to twice daily.");
  assertEquals(result.flagged, true);
});

Deno.test("patternMatch: flags a specific dosage amount", () => {
  const result = patternMatch("Take 500 mg twice a day.");
  assertEquals(result.flagged, true);
});

Deno.test("patternMatch: flags a direct diagnostic assertion", () => {
  const result = patternMatch("Based on the symptoms, you have diabetes.");
  assertEquals(result.flagged, true);
});

Deno.test("patternMatch: does not flag a plain, non-clinical visit summary", () => {
  const result = patternMatch(
    "Helped with breakfast, went for a short walk in the garden, and had a friendly chat about her grandchildren.",
  );
  assertEquals(result.flagged, false);
});

Deno.test("patternMatch: does not flag a factual mention of an existing prescription without instructing a change", () => {
  // Deliberately checks the guardrail isn't so broad it blocks ordinary
  // caregiving notes just for mentioning that medication exists.
  const result = patternMatch("Reminded her to take her morning tablet as scheduled by her doctor.");
  assertEquals(result.flagged, false);
});

Deno.test("runGuardrail: pattern-flagged text short-circuits before any network call", async () => {
  let fetchCalled = false;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = () => {
    fetchCalled = true;
    throw new Error("fetch should not have been called");
  };
  try {
    const result = await runGuardrail("You should double the dose immediately.", FAKE_PROVIDER);
    assertEquals(result.flagged, true);
    assertEquals(fetchCalled, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("runGuardrail: falls back to the model classifier for text the regex layer misses", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = () =>
    Promise.resolve(
      new Response(JSON.stringify({ choices: [{ message: { content: "SAFE" } }] }), { status: 200 }),
    );
  try {
    const result = await runGuardrail("Had a lovely afternoon walk.", FAKE_PROVIDER);
    assertEquals(result.flagged, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("runGuardrail: fails closed if the classifier call itself errors", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = () => Promise.resolve(new Response("service unavailable", { status: 500 }));
  try {
    const result = await runGuardrail("Some ambiguous text the regex layer didn't catch.", FAKE_PROVIDER);
    assertEquals(result.flagged, true);
    assertStringIncludes(result.reason ?? "", "failing closed");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

// Module 13's input pre-filter — the mirror image of the output guardrail.
Deno.test("isMedicalQuestion: flags a dosage-change question", () => {
  assertEquals(isMedicalQuestion("Should I increase her blood pressure tablet?").flagged, true);
});

Deno.test("isMedicalQuestion: flags a 'is this serious' symptom question", () => {
  assertEquals(isMedicalQuestion("Is this rash something dangerous?").flagged, true);
});

Deno.test("isMedicalQuestion: flags a 'does this mean' interpretation question", () => {
  assertEquals(isMedicalQuestion("Does this mean she has dementia?").flagged, true);
});

Deno.test("isMedicalQuestion: does NOT flag an ordinary operational question", () => {
  assertEquals(isMedicalQuestion("When is the next visit scheduled?").flagged, false);
  assertEquals(isMedicalQuestion("What medications is she taking?").flagged, false);
  assertEquals(isMedicalQuestion("Book a companion for tomorrow afternoon.").flagged, false);
});
