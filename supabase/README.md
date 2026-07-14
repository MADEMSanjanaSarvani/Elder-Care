# Project Setu — Supabase backend

Schema and Edge Functions implementing `docs/prd/02-prd-part2-architecture.html`.

## Layout

- `migrations/0001_schema.sql` — tables (Section 11)
- `migrations/0002_rls.sql` — RLS policies, helper functions, consent audit trigger (Section 13)
- `migrations/0003_realtime.sql` — adds `sos_events` to the `supabase_realtime` publication
- `migrations/0004_erasure_requests.sql` — DPDP erasure-request queue (Section 12/13)
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

**A real Supabase project now exists and is live** — project ref
`veumfexjpxqhxemjaaor`, region ap-southeast-1 (Singapore). All three
migrations, the seed data, and all 11 Edge Functions have been applied /
deployed against it for real (not a local approximation), from a
Windows machine outside this sandboxed environment (whose network policy
blocks `supabase.co` entirely — see the git log around this point for
that whole saga). Confirmed end-to-end with a real authenticated request:

```
GET https://veumfexjpxqhxemjaaor.supabase.co/functions/v1/regions-config?code=vizag-ap-in
Authorization: Bearer <a real user's access token, obtained via /auth/v1/token>

200 OK
{"code":"vizag-ap-in","display_name":"Visakhapatnam, Andhra Pradesh", ...}
```

That single request proves four things work together for real: the
database (with RLS actually enforcing it, not bypassed), a deployed Edge
Function, real Supabase Auth issuing and validating a session, and the
seed data being correctly queried. It also confirmed the auth boundary
itself is working as designed — the same request with only the
publishable key (not a real user session) correctly gets `401 Invalid or
expired session`, since `requireUser()` demands an actual signed-in user,
not just an API key.

**What this does *not* yet prove**: only `regions-config` has been
exercised this way. The other 10 functions deployed successfully (no
build/upload errors) but haven't each been individually invoked and
verified — `bookings-create`, `sos-trigger`, and the payments functions
in particular are worth testing next given what's riding on them.

Database + RLS were also validated locally beforehand (`tests/README.md`)
against a real Postgres 16 + PostGIS instance before ever touching the
live project. All 11 Edge Functions plus `_shared/` still type-check
clean (`deno check`) and lint clean (`deno lint`) under Deno 2.9, and the
two pure-logic shared modules have real passing unit tests:

```bash
deno test --allow-net=api.openai.com functions/_shared/
```

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

## DPDP data-subject rights (`me-data-export`, `me-erasure-request`)

PRD Part 2 §12/§13. Both require a real user session (`requireUser`), same as every other function.

- `GET /functions/v1/me-data-export` — returns every record the caller is the *data principal*
  for, scoped by `profiles.role` with explicit queries against the service-role client rather than
  by replaying the caller's own RLS-scoped session. That distinction matters: RLS answers "can this
  user *see* it" (which includes, say, a consented family member reading an elder's health notes),
  not "is this the *caller's own* data" — an elder's export includes their health notes, medications,
  locations, bookings, SOS events, AI interactions, consent grants, and payments; a family member's
  export is limited to records they themselves created or own (their own consent grants, bookings
  they requested, payments they made) and deliberately excludes elder data they merely have viewing
  consent to; a caregiver's export is their caregiver record, documents, assigned bookings, and
  payouts. Every export call logs an `audit_log` row.
- `POST /functions/v1/me-erasure-request` — inserts a row into `erasure_requests`
  (`migrations/0004_erasure_requests.sql`) and notifies every `super_admin`-scoped profile via
  `notifications`. It deliberately does **not** perform a hard delete: payment records, audit trails,
  and SOS events often carry independent legal retention requirements (tax law, safety-incident
  review) that a blanket delete would violate, so resolution is a human admin decision recorded via
  `erasure_requests.status`/`admin_notes` — no queue-draining job exists yet, by design.

## CI/CD

`.github/workflows/deploy-functions.yml` type-checks, lints, and unit-tests every function under
`functions/` on push to `claude/elder-care-platform-mx27jo` (whenever `supabase/functions/**`
changes), then runs `supabase functions deploy` against the live project if that passes. This is
deliberately separate from the Supabase Dashboard's GitHub integration configured earlier, which
only auto-applies `migrations/` — that integration does not know Edge Functions exist. Requires two
repository secrets that are not currently set: `SUPABASE_ACCESS_TOKEN` (generate a fresh personal
access token for this — the one used for the original manual deploy was meant to be revoked after
that setup) and `SUPABASE_PROJECT_REF` (`veumfexjpxqhxemjaaor`). Until those secrets exist, the
`deploy` job will fail after `check` passes; function changes still need a manual
`supabase functions deploy` in the meantime.

## Not yet implemented

- `payouts-run` (RazorpayX batch payout, meant to be triggered by n8n on a schedule per PRD Part 2 §15) — also
  blocked on a `fund_account_id`-equivalent not existing anywhere in the caregiver schema yet; see
  `apps/admin-dashboard`'s payouts page for the same gap from the read side.
- An admin-facing UI for reviewing/resolving `erasure_requests` (the table, RLS, and the
  submission endpoint exist; nothing in `apps/admin-dashboard` lists or resolves them yet).
- Write-side instrumentation for `audit_log` outside the two `me-*` functions above — the table, RLS, and an
  admin viewer all exist, but nothing else calls INSERT on it yet. Postgres has no native SELECT-trigger
  auditing, so this needs explicit logging added at each sensitive read path (consumer app repositories and
  the remaining Edge Functions alike), not a single migration.

These were deferred rather than stubbed with fake logic — see the PRD for their intended design before implementing.
