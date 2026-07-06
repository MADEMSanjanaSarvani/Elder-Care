# Setu — Caregiver App

Flutter app implementing `docs/prd/03-prd-part3-execution.html` Section 17/18:
a job queue, not a smaller copy of the family app.

## Setup (requires the Flutter SDK)

```bash
flutter create --org com.projectsetu --platforms=android,ios .
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## What's here vs. not

Implemented: phone-OTP auth, a "pending verification" state for
caregivers who've signed up but haven't been onboarded into the
`caregivers` table by ops yet, the job queue (assigned bookings only —
this MVP uses server-side matching via `bookings-match`, not an
open job board caregivers browse and claim), OTP visit start/end, and an
earnings/payouts list.

Not yet implemented: live GPS tracking during an active visit (writes to
`elder_locations` with `source = 'caregiver_visit'` — the RLS policy for
it already exists in the backend, this app just doesn't collect/send
location yet), push notifications for new job assignments, and
multi-language support (the caregiver persona's language needs are the
same as the family/elder app's — reuse those ARB files rather than
duplicating translation effort when this is built out).
