# Setu — Family & Elder App

Flutter app implementing `docs/prd/03-prd-part3-execution.html` Section 17/18: one
codebase, two experience modes selected by `profiles.role`.

## Setup (requires the Flutter SDK — not installed in the container this was scaffolded in)

```bash
flutter create --org com.projectsetu --platforms=android,ios .
```

Run that **once**, in this directory, before the first `flutter pub get` —
it generates the native `android/`/`ios/` platform folders this repo
intentionally doesn't include (they're machine-generated boilerplate, not
hand-authored source). It's safe against the existing `lib/` — it only
adds platform folders and won't overwrite them.

```bash
flutter pub get
flutter gen-l10n   # or just `flutter run`, which triggers this automatically
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## What's here vs. not

Implemented: phone-OTP auth + role selection, elder-mode 3-button home,
family-mode dashboard, consent management (elder-editable, family
read-only), booking creation + service list, SOS (108-first).

Not yet implemented (see PRD Part 2 §14 / Part 3 for the intended design
before building these): a screen to actually *view* AI visit summaries
(the caregiver app now generates them via `ai-visit-summary` and they land
in `elder_health_notes`, gated by the `health_notes` consent category —
but nothing in this app reads that table yet), medication reminders,
in-app payments checkout (Razorpay Flutter SDK integration against
`payments-create-order`), push notification handling (FCM), and the full
10-language rollout (Phase 2).

## Translations

`lib/l10n/app_hi.arb` and `app_te.arb` are a first-pass draft, not the
native-speaker-reviewed copy the PRD's testing plan (Part 3 §20) requires
before launch — get them reviewed before shipping.
