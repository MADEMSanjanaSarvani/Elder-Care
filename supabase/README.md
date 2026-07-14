# Project Setu — Supabase backend

Schema and Edge Functions implementing `docs/prd/02-prd-part2-architecture.html`.

## Layout

- `migrations/0001_schema.sql` — tables (Section 11)
- `migrations/0002_rls.sql` — RLS policies, helper functions, consent audit trigger (Section 13)
- `seed.sql` — Visakhapatnam pilot region + MVP service catalog
- `functions/` — Edge Functions (Section 12): everything that touches a secret or a cross-table rule

## Local development

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli) (not installed in this container — install it locally before running these):

```bash
supabase init          # if not already linked
supabase db reset       # applies migrations + seed.sql to your local db
supabase functions serve
```

## Status

**Database + RLS**: applied to a real local Postgres 16 + PostGIS instance
and functionally tested — see `tests/README.md`. This is the strongest
verification anything in this repo has, short of a live Supabase project.

**Edge Functions**: all 11 functions plus `_shared/` type-check clean
(`deno check`) and lint clean (`deno lint`) under Deno 2.9. The two pure-logic
shared modules have real unit tests (`_shared/trustTier.test.ts`,
`_shared/aiGuardrail.test.ts` — 15 passing, the guardrail's model-classifier
branch tested by stubbing `fetch` since there's no live OpenAI key
available here):

```bash
deno test --allow-net=api.openai.com functions/_shared/
```

None of the 11 functions have been *invoked* — that needs either a real
Supabase project (`supabase functions serve` / a deployed project) or a
live third-party API key, neither of which exists in this environment.
Static/type validation and unit tests are real signal, but they're not
the same as a confirmed working HTTP call.

Note: `_shared/supabaseAdmin.ts` imports `@supabase/supabase-js` via an
`npm:` specifier rather than the more commonly-seen `https://esm.sh/...`
URL — both work in Supabase's Deno-based Edge Runtime, but `npm:` was
required here because this environment's network policy blocks `esm.sh`
(and also blocks `jsr.io`, which is why the test files use a 6-line
local assertion helper instead of `jsr:@std/assert`). Neither substitution
changes behavior; note them if you're used to seeing the more common imports.

## Required environment variables (Edge Functions)

| Variable | Used by |
|---|---|
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | all functions |
| `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` | `payments-create-order` |
| `RAZORPAY_WEBHOOK_SECRET` | `payments-webhook` |
| `IDFY_WEBHOOK_SHARED_SECRET` | `verification-idfy-webhook` (placeholder auth scheme — confirm against IDfy's actual docs before launch) |
| `OPENAI_API_KEY` | `ai-visit-summary`, `ai-translate` |

None of these are set in this repo. Configure them via `supabase secrets set` (or your CI's secret store) — never commit real keys.

## The AI guardrail (`_shared/aiGuardrail.ts`)

Both AI functions run every model output through two independent checks
before it can reach a family member (PRD Part 2 §14): a deterministic
regex pass for the clearest dosage/diagnosis phrasing, then a second,
narrowly-scoped LLM call whose only job is to say SAFE or FLAGGED. A
flagged output is written to `ai_interactions` (admin-visible) but never
delivered — the caller gets a "pending review" response instead. The
Admin Dashboard's AI review queue (`apps/admin-dashboard/app/(dashboard)/ai-review`)
now clears these for delivery or rejects them.

## Not yet implemented

- `payouts-run` (RazorpayX batch payout, meant to be triggered by n8n on a schedule per PRD Part 2 §15) — also
  blocked on a `fund_account_id`-equivalent not existing anywhere in the caregiver schema yet; see
  `apps/admin-dashboard`'s payouts page for the same gap from the read side.
- `me/data-export`, `me/erasure-request` (DPDP data-subject rights, PRD Part 2 §12/§13)
- Write-side instrumentation for `audit_log` — the table, RLS, and an admin viewer all exist, but nothing calls
  INSERT on it yet. Postgres has no native SELECT-trigger auditing, so this needs explicit logging added at each
  sensitive read path (consumer app repositories and Edge Functions alike), not a single migration.

These were deferred rather than stubbed with fake logic — see the PRD for their intended design before implementing.
