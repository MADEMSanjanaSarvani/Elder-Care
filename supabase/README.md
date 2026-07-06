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
delivered — the caller gets a "pending review" response instead. There is
currently no admin UI to actually clear a flagged item for delivery; that
review queue is part of the Admin Dashboard (PRD Part 2 §16) and hasn't
been built yet, so a flagged summary today has no path to the family
until that's implemented. Treat this as a known gap, not a red herring.

## Not yet implemented

- `payouts-run` (RazorpayX batch payout, meant to be triggered by n8n on a schedule per PRD Part 2 §15)
- `me/data-export`, `me/erasure-request` (DPDP data-subject rights, PRD Part 2 §12/§13)
- The admin review queue for flagged AI outputs (see above)

These were deferred rather than stubbed with fake logic — see the PRD for their intended design before implementing.
