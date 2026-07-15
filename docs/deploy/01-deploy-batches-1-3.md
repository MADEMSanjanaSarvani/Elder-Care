# Deploying Batches 1–3 to the live project

Live project ref: `veumfexjpxqhxemjaaor`. Status when this runbook was written (2026-07-15):

| Layer | Live state |
|---|---|
| Edge Functions (all 19, incl. the 5 modified + 5 new sweep/invite functions) | **Already deployed** — `deploy-functions.yml` ran green on every push; latest deploy is commit `127a385`. Nothing to do. |
| Migrations `0001`–`0005` | Applied during earlier live smoke-testing. |
| Migrations `0006`–`0014` | **Not applied** — this runbook's Step 1. |
| Sweep shared secrets (4) | **Not set** — Step 2. |

Until Step 1 runs, the already-deployed functions degrade gracefully (their
new-table reads/writes fail as no-ops), but every Batch 1–3 feature is inert
live. Order matters: migrations first, then secrets, then verification.

## Step 1 — apply migrations 0006–0014

From a checkout of this repo at `claude/elder-care-platform-mx27jo`, in the
`supabase/` directory, with your database connection string (the same one used
for the `0001`–`0005` rounds — Dashboard → Connect → Direct connection):

PowerShell:

```powershell
$env:DB = "postgresql://postgres:<DB_PASSWORD>@db.veumfexjpxqhxemjaaor.supabase.co:5432/postgres"
foreach ($f in @(
  "0006_caregiver_documents_storage",
  "0007_wellbeing_checkins_consent_category",
  "0008_family_experience",
  "0009_checkin_timeline_trigger",
  "0010_batch2_care_logistics",
  "0011_appointment_reminder_trigger",
  "0012_medication_discontinue_trigger",
  "0013_batch3_visits_and_records",
  "0014_hospital_stay_gap_reminders"
)) {
  Write-Host "=== $f ==="
  psql $env:DB -v ON_ERROR_STOP=1 -f "migrations/$f.sql"
  if ($LASTEXITCODE -ne 0) { Write-Host "FAILED at $f — stop here and report the error"; break }
}
```

bash equivalent:

```bash
DB="postgresql://postgres:<DB_PASSWORD>@db.veumfexjpxqhxemjaaor.supabase.co:5432/postgres"
for f in 0006_caregiver_documents_storage 0007_wellbeing_checkins_consent_category \
         0008_family_experience 0009_checkin_timeline_trigger 0010_batch2_care_logistics \
         0011_appointment_reminder_trigger 0012_medication_discontinue_trigger \
         0013_batch3_visits_and_records 0014_hospital_stay_gap_reminders; do
  echo "=== $f ===" && psql "$DB" -v ON_ERROR_STOP=1 -f "migrations/$f.sql" || { echo "FAILED at $f"; break; }
done
```

Notes:
- The order is load-bearing once: `0007` adds the `wellbeing_checkins` enum
  value in its own file specifically so it is committed before `0008`
  references it. Running the files one at a time (as above) is exactly right;
  do not concatenate them into a single `psql -1` transaction.
- Each file is idempotent-hostile by design (plain `create table`, no
  `if not exists`) — if a file half-applied on a previous attempt, tell me
  before re-running rather than editing the migration.

## Step 2 — set the sweep shared secrets

Four scheduled functions authenticate with a shared-secret header. Generate
four independent random values and set them (Supabase CLI, logged in, from the
repo root):

PowerShell (generates and sets in one go — note the values, you'll need them
for Step 3 and for the n8n schedules later):

```powershell
$secrets = @{}
foreach ($name in @("CHECKINS_SWEEP_SHARED_SECRET","MEDICATIONS_SWEEP_SHARED_SECRET","REMINDERS_SWEEP_SHARED_SECRET","HOSPITAL_GAP_SWEEP_SHARED_SECRET")) {
  $v = -join ((48..57)+(97..122) | Get-Random -Count 40 | ForEach-Object {[char]$_})
  $secrets[$name] = $v
  Write-Host "$name=$v"
}
supabase secrets set --project-ref veumfexjpxqhxemjaaor `
  CHECKINS_SWEEP_SHARED_SECRET=$($secrets.CHECKINS_SWEEP_SHARED_SECRET) `
  MEDICATIONS_SWEEP_SHARED_SECRET=$($secrets.MEDICATIONS_SWEEP_SHARED_SECRET) `
  REMINDERS_SWEEP_SHARED_SECRET=$($secrets.REMINDERS_SWEEP_SHARED_SECRET) `
  HOSPITAL_GAP_SWEEP_SHARED_SECRET=$($secrets.HOSPITAL_GAP_SWEEP_SHARED_SECRET)
```

(Or set them in Dashboard → Edge Functions → Secrets with any long random
values.) Store them wherever the existing `PAYOUTS_RUN_SHARED_SECRET` value
lives — n8n will need them when the schedules are created.

## Step 3 — verify

**3a. Schema landed** (psql, same `$DB`):

```sql
select count(*) as notification_types_seeded from notification_types;  -- expect 8
select count(*) from daily_checkins;         -- expect 0, but the table must exist
select count(*) from medication_doses;       -- expect 0
select count(*) from hospital_stays;         -- expect 0
select proname from pg_proc where proname in
  ('required_consent_for_source','is_caregiver_on_hospital_stay',
   'enforce_must_deliver_notification_types','log_checkin_to_timeline');  -- expect 4 rows
```

**3b. Sweeps respond and reject bad credentials** (curl; secrets from Step 2):

```bash
BASE="https://veumfexjpxqhxemjaaor.supabase.co/functions/v1"
# wrong secret → expect {"error":"Invalid credentials"} HTTP 401
curl -s -o - -w "\n%{http_code}\n" -X POST "$BASE/checkins-escalation-sweep" -H "x-checkins-sweep-secret: wrong"
# right secret → expect {"processed":0,...} HTTP 200 (no schedules exist yet)
curl -s -o - -w "\n%{http_code}\n" -X POST "$BASE/checkins-escalation-sweep" -H "x-checkins-sweep-secret: <CHECKINS_SWEEP_SHARED_SECRET>"
curl -s -o - -w "\n%{http_code}\n" -X POST "$BASE/medications-generate-doses" -H "x-medications-sweep-secret: <MEDICATIONS_SWEEP_SHARED_SECRET>"
curl -s -o - -w "\n%{http_code}\n" -X POST "$BASE/reminders-dispatch-sweep" -H "x-reminders-sweep-secret: <REMINDERS_SWEEP_SHARED_SECRET>"
curl -s -o - -w "\n%{http_code}\n" -X POST "$BASE/hospital-stays-gap-sweep" -H "x-hospital-gap-sweep-secret: <HOSPITAL_GAP_SWEEP_SHARED_SECRET>"
```

**3c. The booking path still works with the new tiebreak** — re-run the same
`bookings-create` → `bookings-match` smoke pair from the earlier live round
with the existing test users; matching must succeed exactly as before (no
`companion_visit_preferences` row exists yet, so the tiebreak's fallback path
is what's being exercised — which is the important one).

## Not covered by this runbook (known, deliberate)

- n8n schedules that actually call the four sweeps on a timer — the functions
  are live and secured, nothing invokes them periodically yet.
- FCM/SMS delivery — `reminders-dispatch-sweep` delivers to the in-app
  `notifications` table by design (documented deviation).
- Column-level encryption for `emergency_medical_notes` /
  `insurance_policy_number` — named future work (see `0013`'s comment).
