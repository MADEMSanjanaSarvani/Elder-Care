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
unchanged, which looked like a bypass until traced through). TESTs 36-38
cover `0009_checkin_timeline_trigger.sql`, added while building the
Timeline screen on top of Batch 1's tables: `elder_timeline_events` has no
insert policy for `authenticated` at all (service-role only), so without
this trigger a successful check-in would never appear on the timeline —
only the missed-check-in escalation would, which reads as "the timeline
only shows bad news." The trigger closes that gap and the existing
`wellbeing_checkins` consent grant from TEST 26 covers visibility for
free.

TESTs 39-55 cover `0010_batch2_care_logistics.sql` (PRD Part 5, Batch 2:
Medicine Management, Medicine Refill Management, Appointment Management,
Smart Reminder System). TEST 40 confirms the stock-decrement trigger
fires on a dose marked taken. TESTs 44-46 are the security-critical ones:
they caught a real bug in the first draft of `medication_doses_write`,
where the clinical-administration branch was written as a bolt-on `AND`
over a single general-eligibility `OR`, rather than two mutually
exclusive branches partitioned on `marked_via`. That first draft failed
in two different directions at once — it let a consented family member's
existing eligibility slip through for `marked_via = 'caregiver_clinical'`
regardless of who they were, *and* it had no eligibility branch for the
caregiver actually assigned to the booking, so the legitimate case
(TEST 45) failed too. Rewritten as two self-contained, mutually exclusive
branches (elder/family/admin explicitly excluding `caregiver_clinical`;
caregiver explicitly requiring it plus the full in-progress-and-clinical
chain) fixed both at once. TESTs 47-50b cover `appointments`' hybrid
visibility (creator sees their own without needing self-granted consent,
a different linked family member needs `visit_history` consent, a
booking-linked caregiver can see the linked appointment), the same shape
already used by `bookings_select`. TESTs 51-55 cover `reminders`: no
client insert path at all (service-role only, TEST 51), and the
`required_consent_for_source()` helper correctly gating visibility per
row by the sensitivity of what the reminder is *about*, not a single
fixed category (TEST 53 — a family member with `medication_list` but not
`visit_history` consent sees exactly the medication-sourced reminder,
not the appointment-sourced ones).

TESTs 56-57 cover `0011_appointment_reminder_trigger.sql`, a same-day
follow-up to 0010: the Batch 2 PRD's functional requirements for
Appointment Management mention a "reminder lead time" field, but the
Database Design section for `appointments` never defined a column for
it, so nothing could ever enqueue a reminder for an appointment without
this migration — caught while actually wiring Smart Reminder System up to
its stated source modules, the same way the Batch 1 check-in timeline gap
was caught by building the Timeline screen on top of it. Adding the
trigger changed real row counts TESTs 52 and 53 depend on (TEST 47 and
TEST 50 each now genuinely enqueue a reminder on insert), so those two
tests were updated to assert on the real resulting counts rather than a
synthetic stand-in row — the synthetic 'appointment'-sourced reminder in
the original draft was removed as redundant once the trigger made a real
one available to test against instead. TEST 56 confirms rescheduling an
appointment cancels its stale pending reminder and creates exactly one
new one (not a duplicate); TEST 57 confirms cancelling the appointment
itself cancels its pending reminder too.

TESTs 58-60 cover `0012_medication_discontinue_trigger.sql`, a third
same-batch follow-up caught the same way as 0011: the Batch 2 PRD's
functional requirements for discontinuing a medication describe two side
effects (cancel pending future doses, log a `medication_stopped` timeline
event) that 0010 never actually wired up, since neither was in the
Database Design schema cards. Caught while building the medications
screen's "discontinue" action against the real backend, not a hypothetical.

## Running it

Prefer the real Supabase CLI (`supabase db reset`) if you have it and
Docker/Docker Hub access. If not — e.g. this was originally run in a
container whose network policy blocks Docker Hub — a plain local
Postgres plus `local_auth_stub.sql` gets close enough to exercise RLS for
real:

```bash
createdb setu_test
psql -d setu_test -f local_auth_stub.sql
for f in 0001_schema 0002_rls 0003_realtime 0004_erasure_requests \
         0005_caregiver_payout_accounts 0006_caregiver_documents_storage \
         0007_wellbeing_checkins_consent_category 0008_family_experience \
         0009_checkin_timeline_trigger 0010_batch2_care_logistics \
         0011_appointment_reminder_trigger 0012_medication_discontinue_trigger; do
  psql -d setu_test -v ON_ERROR_STOP=1 -f "../migrations/$f.sql"
done
psql -d setu_test -v ON_ERROR_STOP=1 -f ../seed.sql
psql -d setu_test -f rls_smoke_test.sql   # no -v ON_ERROR_STOP=1 — TESTs 8, 24, 33, 44, 46, 51 are supposed to fail
```

Re-running against the same database without a fresh `createdb` will fail on
duplicate-key errors from the seed/test data, not real RLS regressions —
drop and recreate `setu_test` between runs.

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
