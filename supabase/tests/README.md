# RLS smoke test

`rls_smoke_test.sql` actually exercises the row-level security policies
in `../migrations/0002_rls.sql` as different simulated users — not a
read-through of the SQL, a real Postgres session asserting who can see
and write what.

## Why this exists

The consent model (PRD Part 1 §04) is the platform's core trust claim:
the elder, not the paying family member, controls what's shared, and
revoking access takes effect immediately. That's exactly the kind of
property that's easy to get subtly wrong and easy to *believe* is right
from reading the policy definitions — this test suite is what actually
confirmed it, and it already caught one real bug: `elder_profiles_select`
was missing its assigned-caregiver clause entirely (see TEST 11's
comment), which would have meant a caregiver couldn't see the elder they
were sent to help. Fixed in the same commit that added this test. TESTs
14-16 cover the `erasure_requests` table added in `0004_erasure_requests.sql`
the same way: a requester can file and read their own row, nobody else can
read or resolve it. TESTs 17-18 cover `caregiver_payout_accounts`
(`0005_caregiver_payout_accounts.sql`): a caregiver can submit their own
bank/UPI details, and a stranger can't read them. TESTs 19-22 cover the
`caregiver-documents` storage bucket RLS (`0006_caregiver_documents_storage.sql`):
a caregiver can upload and read their own document, a stranger can't, a
verification_agent admin can read any caregiver's. TESTs 23-35 cover PRD
Part 4 Batch 1 (`0007_wellbeing_checkins_consent_category.sql`,
`0008_family_experience.sql`) — daily check-ins are elder-only to write
and `wellbeing_checkins`-consent-gated to read, `elder_timeline_events`
follows the same caregiver/consent shape as `elder_health_notes`, and the
`family_links.coordinator` trigger genuinely blocks a non-elder from
changing it (TEST 33 caught a real false-positive in an earlier draft of
that test itself — the second of two update statements silently no-op'd
against a value the first statement's rollback had already left
unchanged, which looked like a bypass until traced through).

## Running it

Prefer the real Supabase CLI (`supabase db reset`) if you have it and
Docker/Docker Hub access. If not — e.g. this was originally run in a
container whose network policy blocks Docker Hub — a plain local
Postgres plus `local_auth_stub.sql` gets close enough to exercise RLS for
real:

```bash
createdb setu_test
psql -d setu_test -f local_auth_stub.sql
psql -d setu_test -v ON_ERROR_STOP=1 -f ../migrations/0001_schema.sql
psql -d setu_test -v ON_ERROR_STOP=1 -f ../migrations/0002_rls.sql
psql -d setu_test -v ON_ERROR_STOP=1 -f ../migrations/0003_realtime.sql
psql -d setu_test -v ON_ERROR_STOP=1 -f ../seed.sql
psql -d setu_test -f rls_smoke_test.sql   # no -v ON_ERROR_STOP=1 — TEST 8 is supposed to fail
```

Requires the PostGIS extension (`apt install postgresql-16-postgis-3` or
your platform's equivalent) — `0001_schema.sql` uses the `geography`
type for `elder_locations`/`sos_events`.

Every test's expected result is stated in its own `\echo` line; a row
count that doesn't match what the comment says is a real regression, not
a flaky test to rerun.

## What this doesn't cover

No PostgREST, GoTrue, or Realtime server — this validates the SQL and the
RLS logic, not the full request/response path an actual client would go
through. It also doesn't touch the Edge Functions in `../functions/` at
all — those have their own tests now (`../functions/_shared/*.test.ts`,
run with `deno test`), but even those are unit tests of the pure logic,
not a real invocation over HTTP against a live Supabase project. Nothing
in this repo has cleared that last bar yet.
