# Stitch design integration — screen by screen

Every Stitch-generated screen, what it replaced, what changed, and what was
deliberately not carried over.

The Stitch designs are the source of truth for **layout, type, colour, shape
and motion**. They are not the source of truth for **data**, because the mocks
are populated with numbers SETU cannot produce. Where those two collide, the
design wins on appearance and the data is replaced with the real equivalent or
the element is dropped. Every such decision is listed below with its reason.

No business logic, provider, repository, Edge Function, route or auth path was
changed to accommodate a design. Where a design implied a capability that did
not exist and was worth having (preferred hospital, hydration, Memory Lane,
region selection), the capability was built properly — schema, RLS, repository
and UI — rather than faked in the widget tree.

---

## Global — applies to every screen

| Change | File | Build |
|---|---|---|
| Plus Jakarta Sans bundled (variable, OFL 1.1) | `assets/fonts/`, `pubspec.yaml`, `design_tokens.dart` | 39 |
| Pill buttons (radius 999), elevation 4 | `design_tokens.dart` | 39 |
| Card radius 24 + warm shadow, exposed as `SetuSurfaces` | `design_tokens.dart` | 39 |
| Input borders 1.4px → 2px | `design_tokens.dart` | 39 |
| Type scale: display 40, headline 34/28/24 | `design_tokens.dart` | 39 |
| Nav bar / chip / dialog / bottom-sheet themes | `design_tokens.dart` | 39 |
| `SetuNavSurface` — rounded top, upward shadow | `ui_helpers.dart`, `app_shells.dart` | 43 |
| `SetuAtmosphere` — corner colour blobs | `ui_helpers.dart`, `app_shells.dart` | 43 |
| `formatMoney()` — ₹ with Indian lakh grouping | `setu_core/src/money.dart` | 38 |

**Assets added:** `assets/fonts/PlusJakartaSans.ttf`, `assets/fonts/OFL.txt`.
**Dependencies added:** none. Every design was implemented with packages
already in the build.

`SetuAtmosphere` uses a radial gradient rather than the design's
`BackdropFilter`. Backdrop blur is among the most expensive operations on an
entry-level Android GPU and this sits behind every screen; a gradient gives
the same soft edge for nothing per frame.

---

## Per screen

### 1. Wellness Summary
- **Replaces:** `features/wellness/presentation/wellness_summary_screen.dart` (already built from this design in an earlier pass)
- **Modified:** none this round
- **Not carried over:** sleep 8.2h, hydration 1.4L, activity 4.2k steps, resting HR — no wearable. Tiles are wired to medicines-taken, check-in, logged activity and mood instead.
- **Bug in source:** `EdgeInsets.symmetric(horizontal: 12, py: 4)` — `py` is not a parameter.

### 2. Add Medication
- **Replaces:** `_AddMedicationSheet` in `features/medications/presentation/medications_screen.dart`
- **Modified:** same file — "Voice Reminders" → "Dose Reminders"
- **Why:** nothing in SETU speaks. No TTS dependency, no audio. The line had been shipped from an earlier Stitch pass and was a promise that fails at the moment it matters. Now names what actually happens: a push notification from `reminders-dispatch-sweep`.
- **Build:** 35

### 3. Caregiver Profile
- **Replaces:** `_CaregiverDetailSheet` in `features/booking/presentation/caregiver_select_screen.dart`
- **New widgets:** `_TrustBadges`, `_TrustBadge`
- **Derived, not decorative:** identity-verified is always true (the Edge Function filters on `bgv_status = 'cleared'`); clinically-verified requires `trust_tier = clinical_verified`; highly-rated requires 4.8 across ≥20 visits.
- **Not carried over:** the availability calendar with bookable slots. SETU knows working days and hours, not free slots — a family picking a slot nobody can honour is worse than no calendar.
- **Build:** 35

### 4. Elder Home
- **Replaces:** `features/elder_home/presentation/elder_home_screen.dart`
- **Modified:** `home_summary_repository.dart` (next-dose query), the screen (real next-dose label), bento tile elevation
- **Not carried over:** heart rate 72 BPM, steps 1,420/3,000, "Anjali and Rohan are online", mic button. On an elder-care home screen a fabricated vital reads as monitored.
- **Bugs in source:** `TextStyle(opacity:)` ×2 and `BackdropFilter(filter: ColorFilter…)` — neither compiles.
- **Builds:** 36, 44

### 5. Emergency Medical Profile
- **Replaces:** `features/health_profile/presentation/health_profile_screen.dart`
- **Modified:** migration `0037`, `health_profile_repository.dart`, the screen
- **Added:** preferred hospital — the second question a paramedic asks. Omitted originally because SETU had nowhere to put it; the clinic directory (0029/0030) ended that.
- **Not carried over:** the map. SETU geocodes clinics but has no map widget, and a picture of a map you cannot navigate helps nobody in an emergency.
- **Bug in source:** `Icons.pill` does not exist.
- **Build:** 37

### 6. Login
- **Replaces:** `features/auth/presentation/login_screen.dart`
- **Modified:** none — three of its four actions do not exist
- **Why:** "Get Security Code" is phone OTP (parked: SMS cost + TRAI DLT). Face ID / Touch ID cannot *be* a login with Supabase — biometrics only unlock an already-stored session, so on a fresh sign-in there is nothing to unlock. The design also omits Google Sign-In, which is what actually works.

### 7. Notification Center
- **Replaces:** `features/notifications/presentation/notification_inbox_screen.dart` (already grouped by the real `type` field from this design)
- **Refused:** "Fall Detected — Hallway". SETU has no fall detection. Shipping it makes a family believe the app watches for falls, and then the *absence* of the card reads as "no fall happened" — the exact inversion of the truth.
- **Also not carried over:** "Stable Heart Rate 72 BPM", "+12% movement".

### 8. Payment Success
- **Replaces:** `PaymentResultScreen` in `features/payments/presentation/payment_flow_screens.dart`
- **Modified:** `money.dart` (new), 7 call sites across booking, care plans, earnings, payments
- **Fixed:** the design prices in `$29/mo`. SETU is India-only. Separately, our own money was rendered three different ways — "INR 1200" on care plans, "₹1200.00" on the invoice — which is a hesitation at the exact moment someone is asked to pay.
- **Not carried over:** "Priority Support 24/7" (no support desk), "Unlimited Circle" (no member limits to lift).
- **Bug in source:** `Icons.alarm_smart_wake` does not exist; "© 2024" is two years stale.
- **Build:** 38

### 9. Role Selection
- **Replaces:** `features/auth/presentation/choose_role_screen.dart`
- **Modified:** the screen, `router.dart`, `providers.dart`, new `core/role_exit.dart`
- **Fixed:** role was a one-way door — no back arrow, hardware back closed the app, Sign Out was the only escape. Now has back navigation, a CURRENT badge, and "Keep my current role".
- **Bugs in source:** `final Size size = MediaQuery.of(size.width > 0 ? …)` references itself in its own initializer; `const Spacer()` inside a scrollable Column throws at runtime.
- **Build:** 32

### 10. Settings Dashboard
- **Replaces:** `features/settings/presentation/settings_screen.dart`
- **Modified:** none — card styling now comes from the global theme
- **Not carried over:** desktop sidebar (Android phone app), "App Version 2.4.1" (we show the real build stamp).

### 11. Wellness & Activity Tracking
- **Replaces:** `features/wellness/presentation/wellness_activities_screen.dart`
- **New:** migration `0038`, `hydration_repository.dart`, `hydration_card.dart`
- **Built one of four tiles:** water. Sleep, steps and heart rate need hardware. Water is self-reported and matters most here — thirst sensation declines with age, so the person least likely to notice dehydration is exactly this app's user, and in older adults it presents as confusion and falls.
- **Not carried over:** "top 5% of his age group" — no cohort data, and a comparison that would make a struggling family feel worse.
- **Build:** 40

### 12. Success / Confirmation
- **Replaces:** `core/action_success.dart`
- **Modified:** converted to `StatefulWidget`, added float animation and two drifting rings
- **Not carried over:** mouse-hover parallax — no mouse on a phone, and it called `setState` on every hover event.
- **Build:** 41

### 13. Add Elder Profile
- **Replaces:** `showAddElderDialog` in `features/family_home/presentation/family_home_screen.dart`
- **Modified:** medical details section, region picker, photo upload (builds 26, 28, 29)
- **Not carried over:** the 4-step wizard. Four screens to add one person is how a form gets abandoned halfway, and everything below the name is optional.
- **Bug in source:** `DropdownButtonFormField(value:)` is deprecated — this codebase uses `initialValue:`.
- **Outstanding:** the 9-language list (we offer 3).

### 14. Add Medication (frame 2)
- **Refused:** the "AI SUGGESTION — take with food" card. It is a hardcoded string with a robot icon, and it is wrong for a large class of drugs: levothyroxine and alendronate require an empty stomach, several antibiotics bind to dairy calcium. A card that reduces a medicine's effect, in an app the family trusts, with an AI badge implying it was reasoned about.
- **Outstanding:** the Morning/Afternoon/Evening/Night grid — more legible than `08:00, 20:00` and maps to the same `schedule` field.

### 15. AI Companion
- **Replaces:** `features/assistant/presentation/assistant_screen.dart`
- **Unblocked Memory Lane** — see 17 below. This screen finally defined it.
- **Not carried over:** mic button and "I'm listening". Third design to show a mic; still no speech recognition.
- **Bug in source:** `Icons.ecg_heart_outlined` likely does not exist.

### 16. Caregiver Marketplace
- **Replaces:** `features/booking/presentation/caregiver_select_screen.dart` (search, sort, verified badges and ratings already built)
- **Not carried over:** "24x7 Care" filter chip — nobody in the data works 24/7, and a filter that always returns nothing is worse than no filter.
- **Open question for the business:** the design prices per hour; our catalogue is per visit.

### 17. Care Circle Signup
- **Replaces:** `features/auth/presentation/login_screen.dart` (signup mode)
- **Modified:** none needed — password visibility toggle already present
- **Not carried over:** Apple Sign-In (not configured, and `Icons.apps` is a placeholder). The design's terms checkbox defaults to `value: true`; a pre-ticked consent box is not valid affirmative consent under DPDP. Ours is a statement, which avoids the problem.
- **Bug in source:** `_SetuTextFieldState` never disposes its `FocusNode`.

### 18–19. Daily Timeline (frames 1 and 2)
- **Replaces:** `features/timeline/presentation/timeline_screen.dart`
- **Modified:** the connector rail — a `CustomPaint` drawing dashes became one `Container` with the event's colour fading into sand, and medallions were lifted off it so they read as nodes on a line rather than holes punched through it
- **Also cheaper:** the dashes re-rasterised on every scroll frame
- **Not carried over:** photos on timeline events (SETU Memories has images; timeline events do not), and the contextual call FAB
- **Build:** 46

### 20. Elder Wellness
- **Replaces:** `features/wellness/presentation/wellness_summary_screen.dart`
- **Modified:** `_RingCard` — the health score now counts up over 1.5s on `easeInOut`, arc and number together
- **Implementation note:** `TweenAnimationBuilder`, not an `AnimationController`. The score is live, so the tween starts from the value already on screen and moves to the new one; a controller would replay from zero on every rebuild, leaving the number the family came to read wrong for a second and a half each time they touched anything.
- **Build:** 47

### 21. Emergency Medical Profile (frame 2)
- **New screen:** `features/health_profile/presentation/medical_id_screen.dart`, route `/elder/:elderId/medical-id`
- **Modified:** `health_profile_screen.dart` (the MEDICAL ID badge is now the way in), `router.dart`
- **Dependency added:** `qr_flutter ^4.1.0` — pure Dart, depends only on `qr`, no native code
- **Why a second screen rather than a rewrite:** the health profile is a form, and a form is right for the family filling it in on a Sunday and wrong for the ninety seconds it exists for. Nobody scrolls a text field while somebody is on the floor. Same data, read-only, blood group at 44pt, allergies in red at the top, a call button on every contact.
- **The QR holds the record, not a link.** "SCAN FOR FULL RECORD" normally means a URL to a hosted page — a public unauthenticated endpoint serving medical records to whoever holds the token, which would also fail in exactly the situation it exists for, because an ambulance on the Vizag bypass may have no signal. The code carries the text itself: any camera app shows it instantly, offline, and there is no server-side surface to leak.
- **Bug fixed on the way through:** `_ContactRow` still read an embedded `row['profiles']` object, but `fetchFamily` has returned flat rows from `family_circle()` since migration 0034 — so every emergency contact rendered as "Family member" with no call button, on the screen where that matters most.
- **Not carried over:** the map image (unchanged reasoning from screen 5), and the fabricated Chennai hospital address.
- **Bugs in source:** `Icons.pill` does not exist (second appearance); `colorScheme.background` and `surfaceVariant` are deprecated; `withOpacity` is deprecated in favour of `withValues`; `_buildNavItem` takes an `isActive` flag it never reads.

### 22. Emergency SOS (active)
- **Replaces:** `features/sos/presentation/sos_screen.dart` (pulsing button, SOS badge, "Emergency Mode Activated", location strip, Active actions and the AI Dispatcher card were already built from this design)
- **New:** migration `0040`, Edge Function `sos-cancel`, `SosRepository.cancel()`, the "Cancel — it was a false alarm" action and its stood-down state
- **Modified:** `notification_inbox_screen.dart` and `timeline_screen.dart` (a `sos_cancelled` row, green rather than red, and a cancelled SOS stands the timeline's day-banner down), `admin-dashboard/lib/types.ts` + `SosMonitor.tsx`
- **Why it was worth building:** the emergency button had no undo. A pocket-press sent the whole care circle across the city with no way to call them back, and every false alarm makes the next real one less believed. `cancelled` is its own status rather than reusing `resolved` because the two mean opposite things to whoever reads the queue next — one says something happened and was handled, the other says nothing happened at all.
- **Contradiction fixed:** the Active-actions checklist claimed "Location shared — Responders can find you" even while the strip directly above it said NO GPS.
- **Not carried over:** "Ambulance called — ETA 8 minutes" (108 dispatches ambulances, not SETU, and there is no ETA to show), "Nurse Sarah alerted" (no nurse roster), the map image and street address, and the "Device: Ramesh's Watch • Battery 84%" footer (there is no watch).

---

## Capabilities built because a design implied them

| Capability | Migration | Why it was worth building |
|---|---|---|
| Preferred hospital | 0037 | Paramedics ask it second |
| Hydration logging | 0038 | Only wearable-free wellness metric, and the one that prevents incidents |
| Memory Lane + dismissals | 0039 | Reminiscence prompting; dismissals so "not now" means something |
| SOS cancel | 0040 | The emergency button had no undo |
| Region selection (36 states) | 0031 | Decides which doctors and caregivers a family ever sees |
| Region waiting list | 0035 | The picker promises to tell them when we arrive |
| Stories | 0036 | The story button did nothing |

---

## Closed, and why

- **Time-of-day grid for medications (screen 14).** Built. The
  once/twice/thrice frequency picker is replaced by Morning / Afternoon /
  Evening / Night tiles. Four independent slots express fifteen combinations
  instead of four, and they match how a dose is described at home — "the white
  one after breakfast and before bed" — rather than making somebody translate
  that into "twice daily" and hope the app picks the same hours. The exact
  reminder times are printed underneath so nobody is surprised by when the
  phone goes off. No selection means "as needed", which is the honest reading
  of a medicine with no fixed time.

- **Additional languages (screen 13).** Not built, deliberately. The design
  offers nine; SETU has real translations for three (`app_en.arb`,
  `app_hi.arb`, `app_te.arb`), and `preferred_language` sets the app's actual
  locale. Listing Bengali or Marathi would let a family choose it and then get
  an English interface — a worse outcome than not offering it. This reopens the
  day someone translates the strings, not before.

- **Trust footer on the caregiver marketplace (screen 16).** Already built as
  `_SetuStandard`.

- **Photos on timeline events (screen 19).** Not built. `elder_timeline_events`
  has no image column and nothing writes one; the photos in the design live in
  SETU Memories, which is a separate feature with its own screen. Wiring
  Memories images into timeline rows would show a photo from one day against an
  event from another.

---

## Known gaps

- **96 analyzer infos** (mostly `prefer_const_constructors`). Not fixed by hand: Flutter cannot be run in this environment, and adding `const` to an expression that is not actually constant is a compile error. This needs one `dart fix --apply` run on a machine with the SDK — it is a single command and I would rather it be run than guessed at.
- A cancel path for an SOS raised in a previous session. `_sosEventId` is held for the screen's lifetime only; after the app is closed, standing an alert down goes through the on-call operator. Reloading the elder's open SOS on screen entry would close this.
