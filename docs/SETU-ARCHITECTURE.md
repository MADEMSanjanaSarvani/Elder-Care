# SETU — Technical Architecture (design-driven)

> Grounded in the **final Stitch UI/UX** (20 screens + "Warmth & Connection"
> design system) and the **existing production backend** (Supabase Postgres +
> RLS, 30+ Edge Functions, Flutter/Riverpod app). This document is
> architecture only — no implementation. It marks what **exists today** vs what
> is **new** for the finalized design, so development is a delta, not a rebuild.

Tagline: *"Because distance should never mean less care."*

---

## 0. Design system (from `warmth_connection/DESIGN.md`) — the contract

| Token | Value |
|---|---|
| Primary | `#944a18` (deep warm orange) · container `#ff9f66` |
| Secondary | `#62549b` (lavender) · container `#beaefd` |
| Tertiary | peach/beige `#c4b49b` / on-surface `#695d48` |
| Surface / background | warm white `#faf9f6`; cards white / soft peach |
| Error | `#ba1a1a`; success = soft pastel green |
| Type | **Plus Jakarta Sans**, body base **18px**, headings 700 |
| Radius | cards 16px (`2xl`), containers 24px (`3xl`), chips pill |
| Spacing | 8px scale, 24px margins, **≥24px** between tap targets |
| Touch target | **≥56×56px** everywhere (elder accessibility) |

The Flutter theme (`setu_core` design tokens) is the single source of truth and
must be updated **once** to these exact tokens; every screen inherits it. This
is the only "UI" change on my side — structural theming, not redesign.

---

## 1. Screen inventory → feature map (all 20 screens)

| # | Screen | Role | Backend status |
|---|---|---|---|
| 1 | `splash_onboarding` | all | ✅ onboarding carousel exists |
| 2 | `family_dashboard` (greeting, "Dad is safe", live map, meds 2/3, mood, activity, SETU Memories) | family | ⚠️ exists; needs Home restructure + live-location tile + memories tile |
| 3 | `elder_home_screen` (greeting, Talk to AI, big SOS, next dose) | elder | ✅ exists; re-skin |
| 4 | `caregiver_dashboard` (today's visits, Active Trip + Start Navigation, earnings) | caregiver | ✅ job queue + earnings exist; add trip/navigation state |
| 5 | `caregiver_marketplace` (search, Top-Rated/Nearby filters, verified cards, SETU Standard) | family | ✅ `caregivers-for-service` browse + distance |
| 6 | `add_elder_profile` | family | ✅ `family-add-elder` |
| 7 | `add_medication` | family/elder | ✅ medications |
| 8 | `doctor_consultations` | family/elder | 🆕 **new** (doctors, appointments, video) |
| 9 | `wellness_summary` (AI health cards) | family | ✅ AI reports; reshape to cards |
| 10 | `ai_companion` (chat + voice) | all | ✅ assistant; add voice I/O |
| 11 | `action_successful` (success state) | all | 🆕 shared success screen/animation |
| 12 | `daily_timeline_peace_of_mind` | family | ✅ timeline |
| 13 | `settings_dashboard` | all | ✅ settings |
| 14 | `emergency_medical_profile` | family | ✅ health profile |
| 15 | `elder_wellness_activities` | elder | 🆕 **new** (guided activities) |
| 16 | `emergency_sos_active` | all | ✅ SOS; add "active" live state |
| 17 | `no_notifications` (empty) | all | ✅ empty state |
| 18 | `notification_center` | all | ✅ inbox |
| 19 | `premium_plans` | family | ✅ care plans + Razorpay |
| 20 | `family_circle_permissions` (consent) | family | ✅ consent grants |

**Net new features:** Doctor consultation + video calling, elder wellness
activities, SETU Memories (emotional daily AI summary), shared success/empty/
skeleton states, rewards & referrals (in the product brief, not in these 20).

---

## 2. Navigation architecture

Three role-based shells, each with a persistent **bottom navigation bar**
(exactly as designed). Role is decided once from `profiles.role`.

```
Splash → Onboarding → Role select → Auth (email / Google / phone-OTP)
      → Guided setup (add elder / caregiver application) → Role Shell
```

- **Family shell:** `Home · Care · AI · Reports · Profile`
  - Home → dashboard; Care → marketplace + bookings + tracking + doctors;
    AI → companion; Reports → wellness summary + memories + timeline;
    Profile → settings, plans, consent, medical profile, rewards.
- **Elder shell:** `Home · Care · Reports · Profile` (SOS is a large home
  button, "Talk to AI" a large home card — minimal chrome, 56px targets).
- **Caregiver shell:** `Home · Visits · [center booking action] · Earnings · Profile`.

Everything "advanced" (consent, timeline, hospital stays, documents, privacy,
legal, notification prefs) lives **under Profile → More**, off the primary
flow — matching the design.

Router: keep `go_router` with three `StatefulShellRoute` branches (one per
role) so each tab keeps its own navigation stack.

---

## 3. Folder structure (Flutter, feature-first — already in place)

```
packages/setu_core/         # design tokens (→ update to Warmth tokens), models, shared UI
apps/family_elder_app/lib/
  core/        router, providers, env, preferences
  features/<feature>/
    data/        repositories (Supabase calls / Edge Function invokes)
    presentation/ screens + widgets
  ...
```
New feature folders to add: `doctor_consultation/`, `wellness_activities/`,
`memories/`, `video_call/`, `rewards/`. This matches the existing convention —
no restructure needed.

---

## 4. Database schema

**Exists today (23 migrations):** `profiles`, `elder_profiles`, `family_links`,
`consent_grants`, `caregivers`, `caregiver_profile_details` (+lat/lng),
`caregiver_application_details`, `caregiver_rating_summary`, `service_catalog`,
`bookings`, `booking_events`, `payments`, `caregiver_payouts`, `medications`,
`medication_doses`, `appointments`, `reminders`, `notifications`,
`elder_health_profile`, `elder_administrative_profile`, `medical_documents`,
`care_plans` + `subscriptions` + `charges`, `sos_events`, `elder_locations`,
`timeline_events`, `checkins`, `hospital_stays`, `audit_log`, `erasure_requests`.

**New tables for the finalized design:**

| Table | Purpose | Key columns |
|---|---|---|
| `doctors` | doctor directory | id, name, specialty, reg_no, photo, languages, fee, rating |
| `doctor_appointments` | consultations | id, elder_id, doctor_id, booked_by, scheduled_at, status, mode(video/in_person) |
| `doctor_prescriptions` | digital Rx | id, appointment_id, elder_id, doctor_id, items(jsonb), notes, issued_at |
| `video_calls` | call sessions | id, appointment_id/booking_id, room_id, provider, started_at, ended_at, participants |
| `caregiver_trips` | live tracking | id, booking_id, caregiver_id, status(accepted→on_way→arrived→started→completed), live_location, eta |
| `wellness_activities` + `elder_activity_log` | guided activities | activity catalog + per-elder completion |
| `setu_memories` | emotional daily AI summary | id, elder_id, date, highlights(jsonb), mood, generated_at |
| `rewards` + `referrals` | loyalty | points ledger, referral codes/attribution |

Relationships mirror existing patterns (all elder-scoped tables FK
`elder_profiles`, consent-gated by `has_consent(...)`). Every new table gets
**RLS** consistent with the existing consent model.

---

## 5. Backend & API architecture (Supabase-first, already the stack)

Pattern (unchanged): **thin client → RLS-guarded reads → Edge Functions for any
cross-table/secret write**. 30+ functions exist. New functions for the design:

| Service | New Edge Functions |
|---|---|
| Doctor | `doctors-list`, `doctor-appointment-book`, `doctor-prescription-issue` |
| Video | `video-call-create` (mint room + token), `video-call-end` |
| Live tracking | `caregiver-trip-update` (status/location), read via realtime |
| Memories | `setu-memories-generate` (AI daily summary, nightly cron) |
| Rewards | `rewards-accrue`, `referral-redeem` |

Reuse existing: auth, bookings, payments (Razorpay plan/booking), SOS, AI
assistant/reports, notifications, DPDP export/erasure.

Realtime: Supabase Realtime channels for **caregiver trip location**, **SOS
active state**, and **notifications** (live "Dad is safe" / ETA updates).

---

## 6. Authentication architecture

- **Email + password** ✅ (name, confirm, validation, forgot-password).
- **Google Sign-In** — provider config pending (`in.carehive.app` + SHA-1 + Web
  client ID). Native `signInWithIdToken`.
- **Phone OTP** — code path ✅; needs SMS provider in Supabase.
- **Face/biometric unlock** — local re-auth gate (local_auth) over an existing
  session; not a primary login. 🆕
- **Session** — Supabase persisted session; **role-based** routing from
  `profiles.role`; RLS is the true authority server-side.

---

## 7. State management architecture (Riverpod — in place)

Provider families per domain, already established: `authState`,
`currentProfile`, `myElderProfiles`, `myCaregiver`, bookings, medications,
notifications (`unreadCount`), care plans, etc. New providers per new feature
(doctors, appointments, trip-tracking stream, memories, rewards). Streams
(`StreamProvider`) for realtime trip/SOS/notifications.

---

## 8. AI architecture (SETU AI)

Modular, server-side (keys never on device), graceful-degradation when
`OPENAI_API_KEY` absent (already the pattern):
- **Companion chat + voice** — text now; add STT/TTS (device speech + optional
  server) for the voice screen; suggested-prompt chips ("I feel lonely", "Call
  my daughter", "What medicine now?").
- **Daily summary / SETU Memories** — nightly job turns the day's timeline
  (meds, check-ins, activity, mood) into a warm, human paragraph + highlights.
- **Wellness summary** — weekly report as cards (not graphs): sleep, medicine
  completion %, mood, recommendations. Guardrailed (existing AI review flow).
- **Mood / loneliness signals** — derived from check-ins + companion sentiment;
  surfaced as gentle insights, never clinical claims. Emergency phrases in the
  companion trigger the SOS path.

---

## 9. Caregiver architecture (Uber/Urban-Company style)

Registration → admin verification → active. Marketplace browse (verified,
rated, distance). Booking (service → date/time → chosen caregiver) → **trip
lifecycle** `accepted → on_way → arrived → started → medicine_given →
completed`, streamed live to the family (map + ETA + call/message). OTP at
visit start/end (exists). Ratings feed `caregiver_rating_summary`. Payouts via
RazorpayX (exists).

---

## 10. Emergency (SOS) architecture

108-first (mandatory), then parallel fan-out: notify family + on-call ops +
assigned caregiver, share **live location**, show nearby help. `emergency_sos_
active` is a realtime live state (responder + location). Evidence trail in
`sos_events` + `audit_log`. Practice/drill mode exists.

## 11. Doctor consultation architecture 🆕

Doctor directory → book appointment (video/in-person) → **video call**
(WebRTC provider: Agora/Daily/Twilio Video — room + token minted server-side)
→ digital **prescription** stored to `doctor_prescriptions`, surfaced in the
elder's medical profile and (optionally) auto-creating medications.

## 12. Notification architecture

In-app inbox ✅ + preferences ✅. Add **FCM push** (needs `google-services.json`)
for: medicine reminders, SOS, caregiver/trip updates, appointment alerts, AI
nudges. Server sends via `notifications` rows + a push dispatch function.

## 13. Payment & subscription architecture

Razorpay ✅ for **plans** (`premium_plans`: Basic / Premium / Family Plus) and
**per-visit** bookings — hosted checkout + **server-side signature
verification** before activation; webhook for capture. Invoices/history from
`payments` + `charges`. Refund/cancellation policies at checkout.

## 14–16. Security · Offline · Play Store

- **Security:** RLS everywhere, service-role only in Edge Functions, secrets in
  Supabase (never client), HTTPS, signed URLs for medical files, consent-gated
  medical data, DPDP export/erasure, audit log, biometric app-lock.
- **Offline:** cache last dashboard + reports + medicine schedule locally
  (shared_preferences/Isar), queue check-ins, sync on reconnect; SOS always
  falls back to a native `tel:108` dial.
- **Play Store:** in-app Privacy Policy + Terms ✅, account deletion + data
  export ✅, runtime permission rationale, minimal permissions, Data Safety
  form, warm icon ✅, screenshots (from these 20 designs), support email,
  crash-free flows, accessibility (elder mode, large fonts, high contrast).

## 17. Scalability & deployment

Supabase (Postgres + PgBouncer + Storage + Realtime + Edge Functions) scales
horizontally; indexes on all elder-scoped hot paths (exist). CI builds the APK
on push ✅; Edge Functions + migrations auto-deploy ✅. Media on Storage/CDN.
Video offloaded to the WebRTC provider. AI calls rate-limited server-side.

---

## 18. Build order (once this architecture is approved)

1. **Theme swap** to Warmth tokens + **3 bottom-nav shells** (biggest visible
   lift; reorganizes existing screens — no feature loss).
2. **Family Home** restructure (greeting + "safe" + live-location tile + meds +
   mood/activity + **SETU Memories**).
3. **SETU Memories** + wellness-summary-as-cards (AI daily/weekly).
4. **Live caregiver tracking** (trip lifecycle + realtime + Start Navigation).
5. **Doctor consultation + video calling** (new tables + WebRTC).
6. **Voice** on the AI companion; **elder wellness activities**.
7. **Rewards/referrals**, **push (FCM)**, **Google/phone/biometric** login.
8. Success/empty/skeleton/offline states + Play Store polish.

Each step reuses existing data/repositories; the design is the north star and
is not modified.
