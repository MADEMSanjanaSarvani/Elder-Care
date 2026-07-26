# Which AI provider SETU uses, and when that has to change

## The decision

SETU now prefers **Google's Gemini API free tier** and falls back to OpenAI.
Set `GEMINI_API_KEY` in the Supabase secrets and every AI function uses Gemini.
Set only `OPENAI_API_KEY` and they use OpenAI. Set neither and the AI features
say "still being set up" instead of breaking.

The reason is money. OpenAI has no free tier — a balance has to be topped up,
and SETU has no revenue to top it up from. Gemini's free tier needs no card at
all and gives roughly 1,500 requests a day on Flash, which is far more than a
pilot with five families will ever use.

## The catch, stated plainly

**On Gemini's free tier, Google may use the prompts and responses to improve
its models.**

SETU's AI functions send real content: medication lists, chronic conditions,
caregiver visit notes, and whatever a worried daughter types into the
assistant at 11pm. On the free tier that content is not private in the way
SETU's own privacy policy implies it is.

That is acceptable right now, and only because of a specific fact: there are
no real families on SETU yet. Everything in the database is test data.

**It stops being acceptable the day the first real family is onboarded.**

## What has to happen before the first real family

Pick one:

1. **Put the OpenAI key back.** Set `OPENAI_API_KEY`, unset `GEMINI_API_KEY`.
   No code change — `_shared/aiProvider.ts` switches on its own. Costs a few
   dollars a month at pilot volume.
2. **Move Gemini to a paid tier or Vertex AI.** Paid Gemini and Vertex are not
   trained on. Same key, same endpoint for paid Gemini — also no code change.
3. **Turn the AI features off** until one of the above is affordable. The
   functions already degrade gracefully with no key set, so this costs nothing
   to do and nothing to undo.

This is not a "nice to have later" item. Sending a stranger's mother's
medication list to a provider that trains on it, while the app's own privacy
policy promises otherwise, is a DPDP problem and a trust problem, and trust is
the entire product.

## Where the switch lives

`supabase/functions/_shared/aiProvider.ts`. One function, `aiProvider()`,
returns the endpoint, key and model names. Every AI function and the safety
guardrail read from it.

The switch is cheap because Gemini publishes an **OpenAI-compatible endpoint**
(`/v1beta/openai/chat/completions`) that accepts the same request body,
the same tool-calling schema and returns the same response shape. So the
care assistant's tool loop, the two-layer guardrail, the medical pre-filter
and the `ai_interactions` audit trail are all untouched by the change — only
a URL, a model name and a key move.

## Model choice

| Role | Gemini | OpenAI |
|---|---|---|
| Answering users, generating summaries | `gemini-2.5-flash` | `gpt-4o` |
| Safety classifier (layer 2b) | `gemini-2.5-flash-lite` | `gpt-4o-mini` |

The classifier is deliberately a smaller model on a narrower prompt. That is a
safety property, not a cost saving: a prompt injection that fools the
generation call still has to separately fool a different model with a
different instruction.

## Error handling

Running out of free Gemini quota and running out of OpenAI credit look
identical over the wire — both are HTTP 429 — and need completely different
things done about them. `aiErrorMessage()` tells them apart, so the app says
"the assistant has hit today's free usage limit, it will work again tomorrow"
rather than telling someone on a free plan to go add credit to an account they
do not have.

## Free-tier limits worth knowing

Google has revised free-tier quotas downward before, without notice, and does
not guarantee them. If the assistant starts returning quota errors well below
the documented limit, that is the likely cause — check the live rate limits in
Google AI Studio for the project rather than trusting a published number.
