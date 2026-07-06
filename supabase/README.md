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

None of these are set in this repo. Configure them via `supabase secrets set` (or your CI's secret store) — never commit real keys.

## Not yet implemented

- `payouts-run` (RazorpayX batch payout, meant to be triggered by n8n on a schedule per PRD Part 2 §15)
- `ai/visit-summary`, `ai/translate` (PRD Part 2 §14 — the constrained AI architecture; needs the output-guardrail classifier designed before the OpenAI call itself is wired up)
- `me/data-export`, `me/erasure-request` (DPDP data-subject rights, PRD Part 2 §12/§13)

These were deferred rather than stubbed with fake logic — see the PRD for their intended design before implementing.
