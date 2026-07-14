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
were sent to help. Fixed in the same commit that added this test.

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
