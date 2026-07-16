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

TESTs 61-81 cover `0013_batch3_visits_and_records.sql` (PRD Part 6, Batch
3: Family Notification Center, Companion Visits, Hospital Companion
Services, Health Records Management). TESTs 61-62 confirm the
must-deliver notification-type trigger blocks disabling `sos_triggered`
while allowing an ordinary type to be disabled. TESTs 66-69 cover
`visit_activity_logs`: the assigned in-progress caregiver can write it,
an unassigned caregiver can't, and — a real detail worth stating — the
family member who *requested* the booking still can't read the log
without `visit_history` consent, since (unlike `bookings_select`)
this table's RLS was written with no requester exemption at all. TESTs
70-76 cover Hospital Companion Services, and caught a real bug in the
first draft of `hospital_stay_bookings_select`: its cross-caregiver read
clause queried `hospital_stay_bookings` from inside that same table's own
RLS policy, which Postgres rejects outright with "infinite recursion
detected in policy" — not a subtle logic bug, a hard error on every query
against the table. Fixed the same way every other cross-table RLS check
in this schema is fixed: a `security definer` helper function
(`is_caregiver_on_hospital_stay()`), which runs under its owner's
privileges and so doesn't re-trigger RLS on the table it reads inside
itself. TEST 72 confirms the intended behavior once fixed (a caregiver on
one shift can read another shift's handoff note within the same stay);
TEST 74 confirms the write side stays narrower — that same caregiver
cannot *write* a note for a shift that isn't their own, a silent 0-row
no-op, not a bypass. TESTs 77-81 cover the two-tier health profile split:
TEST 78 confirms a caregiver on an in-progress booking reads
`elder_health_profile` with no consent grant needed, TEST 79 confirms a
totally uninvolved caregiver can't, TEST 80 confirms *no* caregiver, ever,
reads `elder_administrative_profile`, and TEST 81 confirms the dispatched
SOS responder gets the same emergency-info visibility with no booking at
all — mirroring the real, narrower `sos_events` precedent (visibility
only for the specifically dispatched `responder_caregiver_id`) rather
than the PRD's looser text implying any caregiver during an active SOS.

TESTs 82-83 cover `0014_hospital_stay_gap_reminders.sql`: without
registering `hospital_stay_gap` in `required_consent_for_source()`, the
shared reminder engine fails closed for the new type (null mapping means
no family visibility at all) — TEST 82 confirms a family member with
`visit_history` consent sees a coverage-gap reminder, TEST 83 confirms a
stranger doesn't.

TESTs 84-92 cover `0016_batch4_ai_layer.sql` (PRD Part 7, Batch 4:
AI Visit Reports and AI Recommendation Engine — the AI Care Assistant and
Voice Assistant modules add no tables). TESTs 84-87 exercise
`ai_visit_reports`' flagged-hold rule, which is deliberately stricter than
raw-data access: TEST 84 confirms **even the elder** sees only the cleared
report, not a flagged/held one — a flagged AI report is a machine draft
that failed the guardrail (potentially the exact hallucinated diagnosis
the guardrail exists to catch), so "never delivered until reviewed" has to
mean to *any* end user, elder included, admin-only until `human_reviewed`
(TEST 87). This is the one place a viewer is denied their *own* generated
content on purpose, and the reasoning is written into the migration.
TESTs 88-92 exercise `care_suggestions`' consent-mapping-by-type: TEST 89
(a family member with only `visit_history` sees neither a medication- nor
a wellbeing-gated suggestion) and TEST 90 (a family member with
`medication_list` + `wellbeing_checkins` sees both) confirm
`required_consent_for_suggestion()` gates visibility by what each
suggestion is *about*, exactly like `reminders` in Batch 2; TEST 92
confirms a stranger's dismiss attempt is a silent no-op, not a bypass.

TESTs 93-104 cover `0017_batch5_caregiver_and_platform_ux.sql` (PRD Part 8,
Batch 5: Caregiver Management, Caregiver Performance & Rating,
Accessibility — Multi-language adds no schema). TESTs 93-95 confirm a
caregiver profile is visible to the caregiver, admins, and any family
connected via a booking, but not to an unconnected stranger. TEST 96
confirms the onboarding checklist is admin-write-only (a caregiver can't
mark their own training complete). TESTs 97-100 are the security heart of
the rating system: TEST 97 confirms a 5-star rating isn't auto-flagged
(and, by the `<= 2` trigger, a low one would be), TEST 98 confirms the
`AFTER INSERT` trigger recomputed the summary to avg 5.00 / count 1, and
TESTs 99-100 confirm the *anonymity-toward-the-caregiver* property the PRD
insists must be enforced in the database, not client code: the caregiver
gets **0 rows** reading the base `caregiver_ratings` table (which contains
`rated_by`), but **1 row** through `caregiver_ratings_anonymized`, whose
schema has **0** `rated_by` columns — so a caregiver can read their own
reviews yet can never learn who wrote any given one, enforced by a view
running with definer rights over an RLS-blocked base table. TEST 101
confirms a user with no link to the elder and no part in the booking is
blocked from rating by RLS (before the unique constraint is even reached).
TESTs 102-104 cover `accessibility_preferences`' dual-writer model: the
elder sets their own, a linked family member can adjust them on the
elder's behalf (TEST 103, since many elders never open a settings screen),
and a stranger's change is a silent no-op (TEST 104).

Also worth stating: this migration does **not** implement column-level
encryption for `emergency_medical_notes`/`insurance_policy_number`, even
though the PRD claims it should reuse "an already-decided pattern." No
such pattern exists anywhere in this codebase — `elder_health_notes.note`
has always been plain text, RLS-protected only. Real encryption needs
Supabase Vault/pgsodium against the live project (not available in this
local Postgres+PostGIS harness to even test), so building a naive
client-visible-key scheme now would be worse than the honest gap: it
would look like protection without providing any. Flagged in the
migration's own comment as named future work, not silently dropped.

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
         0011_appointment_reminder_trigger 0012_medication_discontinue_trigger \
         0013_batch3_visits_and_records 0014_hospital_stay_gap_reminders \
         0015_ai_interaction_types 0016_batch4_ai_layer \
         0017_batch5_caregiver_and_platform_ux; do
  psql -d setu_test -v ON_ERROR_STOP=1 -f "../migrations/$f.sql"
done
psql -d setu_test -v ON_ERROR_STOP=1 -f ../seed.sql
psql -d setu_test -f rls_smoke_test.sql   # no -v ON_ERROR_STOP=1 — TESTs 8, 24, 33, 44, 46, 51, 61, 67 are supposed to fail
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
