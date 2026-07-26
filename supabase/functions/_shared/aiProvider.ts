// Which model provider the AI functions talk to.
//
// SETU is pre-revenue and a paid OpenAI balance is a recurring cost that has
// to be justified before there is a single paying family. Google's Gemini API
// has a genuinely free tier — no card, ~1,500 requests a day on Flash — which
// is far more than a pilot will use, so it is preferred when configured.
//
// The switch is this cheap because Gemini exposes an OpenAI-compatible
// endpoint: same request body, same tool-calling schema, same response shape.
// So every call site keeps its existing logic and changes only a URL, a model
// name and a key. Nothing about the guardrail, the tool loop or the audit log
// moves.
//
// IMPORTANT, and the reason both providers stay wired up: on Gemini's FREE
// tier Google may use the prompts and responses to improve its models. These
// functions send medication lists, conditions and visit notes. That is fine
// while the only data is test data, and it is not fine the day a real family
// is onboarded — at that point either the OpenAI key goes back in (set
// OPENAI_API_KEY and unset GEMINI_API_KEY and this file switches back with no
// code change) or Gemini moves to a paid/Vertex tier, which is not trained on.
// See docs/business/SETU-ai-provider.md.

export interface AiProvider {
  /** Which service is actually being called — used in error messages. */
  name: "gemini" | "openai";
  /** OpenAI-compatible chat-completions endpoint. */
  chatUrl: string;
  apiKey: string;
  /** The model that answers users. */
  model: string;
  /** A smaller, cheaper model for the safety classifier. */
  fastModel: string;
  /** True when responses may be used to train the provider's models. */
  trainsOnData: boolean;
}

/** The configured provider, or null when no key is set at all. */
export function aiProvider(): AiProvider | null {
  const gemini = Deno.env.get("GEMINI_API_KEY") ?? "";
  if (gemini) {
    return announce({
      name: "gemini",
      chatUrl:
        "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
      apiKey: gemini,
      model: "gemini-2.5-flash",
      fastModel: "gemini-2.5-flash-lite",
      trainsOnData: true,
    });
  }
  const openai = Deno.env.get("OPENAI_API_KEY") ?? "";
  if (openai) {
    return announce({
      name: "openai",
      chatUrl: "https://api.openai.com/v1/chat/completions",
      apiKey: openai,
      model: "gpt-4o",
      fastModel: "gpt-4o-mini",
      trainsOnData: false,
    });
  }
  console.warn("[ai] no GEMINI_API_KEY or OPENAI_API_KEY set — AI disabled");
  return null;
}

/**
 * Says which provider was chosen, once per isolate, in the function logs.
 *
 * Which key is in effect is otherwise invisible: both providers speak the same
 * protocol, so a working answer looks identical either way, and a stale isolate
 * still holding the old key is indistinguishable from a new one. This turns
 * "did the secret take effect?" from a guess into one line in the Supabase log
 * viewer.
 *
 * It also states the training posture out loud, because "Gemini free tier" and
 * "families' medication lists" are two facts that must never quietly drift
 * apart — see docs/business/SETU-ai-provider.md. Never logs the key itself.
 */
function announce(provider: AiProvider): AiProvider {
  console.log(
    `[ai] provider=${provider.name} model=${provider.model} ` +
      `classifier=${provider.fastModel} ` +
      `trains_on_data=${provider.trainsOnData}`,
  );
  return provider;
}

/**
 * Turns a provider HTTP failure into something a family member can act on.
 *
 * Dumping the raw JSON into a chat bubble helps nobody, and the failures that
 * actually happen each have one specific fix — so name it, and name it per
 * provider, because "add credit to the OpenAI account" is useless advice when
 * the app is talking to Gemini.
 */
export function aiErrorMessage(
  provider: AiProvider,
  status: number,
  body: string,
): string {
  if (status === 429) {
    if (provider.name === "gemini") {
      // Free-tier daily quota, which resets — worth saying, because "try
      // again later" and "you have hit today's limit" are different facts.
      return "The assistant has hit today's free usage limit. It will work " +
        "again tomorrow, or sooner if the Gemini plan is upgraded.";
    }
    if (body.includes("insufficient_quota")) {
      return "The assistant is out of credit. Add a little balance to the " +
        "OpenAI account and it will start working again.";
    }
    return "The assistant is busy right now. Please try again in a moment.";
  }
  if (status === 401 || status === 403) {
    const secret = provider.name === "gemini"
      ? "GEMINI_API_KEY"
      : "OPENAI_API_KEY";
    return `The assistant's API key isn't valid. Check ${secret} in the ` +
      "Supabase secrets.";
  }
  return "The assistant is having trouble right now. Please try again shortly.";
}
