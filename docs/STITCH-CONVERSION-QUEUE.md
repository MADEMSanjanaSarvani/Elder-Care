# Stitch → Flutter conversion queue (all 28 screens)

*Copy-paste each block into your local Claude Code CLI, in order. Tick them off as you go.*

**Before you start each batch:**
```
git pull origin claude/elder-care-platform-mx27jo
```
(Claude and I are on the same branch — pull first or your push gets rejected.)

**Standing rules baked into every prompt below:**
- Keep all existing data providers, navigation and functionality — visuals only.
- Don't invent data the app doesn't have (no fake step counts, fake vitals, fake ETAs).
- Flutter isn't installed locally → skip `flutter analyze`, CI runs it.
- Commit and push after each batch.

---

## Progress

| # | Stitch design | Target file | Status |
|---|---|---|---|
| 1 | family_dashboard | `features/family_home/presentation/family_home_screen.dart` | ✅ done |
| 2 | elder_home_screen | `features/elder_home/presentation/elder_home_screen.dart` | ⬜ |
| 3 | daily_timeline_peace_of_mind (1+2) | `features/timeline/presentation/timeline_screen.dart` | ⬜ |
| 4 | wellness_summary (1+2) | `features/wellness/presentation/wellness_summary_screen.dart` | ⬜ |
| 5 | elder_wellness_activities | `features/wellness/presentation/wellness_activities_screen.dart` | ⬜ |
| 6 | notification_center + no_notifications | `features/notifications/presentation/notification_inbox_screen.dart` | ⬜ |
| 7 | settings_dashboard | `features/settings/presentation/settings_screen.dart` | ⬜ |
| 8 | ai_companion | `features/assistant/presentation/assistant_screen.dart` | ⬜ |
| 9 | add_medication (1+2) | `features/medications/presentation/medications_screen.dart` | ⬜ |
| 10 | emergency_medical_profile (1+2) | `features/health_profile/presentation/health_profile_screen.dart` | ⬜ |
| 11 | emergency_sos_active | `features/sos/presentation/sos_screen.dart` | ⬜ |
| 12 | premium_plans | `features/care_plans/presentation/care_plans_screen.dart` | ⬜ |
| 13 | secure_payment | `features/payments/presentation/payment_flow_screens.dart` | ⬜ |
| 14 | caregiver_marketplace | `features/booking/presentation/caregiver_select_screen.dart` | ⬜ |
| 15 | caregiver_details | `features/booking/presentation/caregiver_select_screen.dart` (detail sheet) | ⬜ |
| 16 | doctor_consultations | `features/doctors/presentation/doctors_screen.dart` | ⬜ |
| 17 | family_circle_permissions | `features/family_access/presentation/family_access_screen.dart` | ⬜ |
| 18 | login | `features/auth/presentation/login_screen.dart` | ⬜ |
| 19 | create_account | `features/auth/presentation/login_screen.dart` (sign-up mode) | ⬜ |
| 20 | forgot_password | `features/auth/presentation/login_screen.dart` (reset flow) | ⬜ |
| 21 | role_selection | `features/auth/presentation/choose_role_screen.dart` | ⬜ |
| 22 | splash_onboarding | `features/onboarding/presentation/onboarding_screen.dart` | ⬜ |
| 23 | add_elder_profile | `showAddElderDialog` in `features/family_home/presentation/family_home_screen.dart` | ⬜ |
| 24 | action_successful | `core/action_success.dart` | ⬜ |
| 25 | caregiver_dashboard | `features/job_queue/presentation/job_queue_screen.dart` | ⬜ |
| 26 | visit_task_checklist | `features/visit_tools/presentation/visit_tools_section.dart` | ⬜ |
| 27 | otp_verification | `features/otp_visit/presentation/otp_visit_screen.dart` | ⬜ |
| 28 | (bonus) trip tracking | `features/trips/presentation/trip_tracking_screen.dart` | ⬜ |

All paths are under `apps/family_elder_app/lib/`.

---

## BATCH A — the screens families see every day

> Using the Stitch MCP, convert these screens to Flutter, one after another, matching each design as closely as possible:
>
> 1. **elder_home_screen** → replace `apps/family_elder_app/lib/features/elder_home/presentation/elder_home_screen.dart`
> 2. **daily_timeline_peace_of_mind** (both frames 1 and 2) → replace `apps/family_elder_app/lib/features/timeline/presentation/timeline_screen.dart`
> 3. **wellness_summary** (both frames 1 and 2) → replace `apps/family_elder_app/lib/features/wellness/presentation/wellness_summary_screen.dart`
> 4. **elder_wellness_activities** → replace `apps/family_elder_app/lib/features/wellness/presentation/wellness_activities_screen.dart`
>
> For every screen: keep all existing data providers, routes, navigation and functionality — change only the visual layout. Do not invent data the app does not have (no fake step counts, vitals or ETAs); if the design shows a metric we don't track, either omit it or wire it to the nearest real value and leave a comment. Elder-facing screens must keep their large text and high-contrast treatment.
>
> Flutter isn't installed locally, so skip `flutter analyze` — CI runs it. When all four are done, commit and push to `claude/elder-care-platform-mx27jo`.

---

## BATCH B — notifications, settings, AI, medicines

> Using the Stitch MCP, convert these screens to Flutter, one after another, matching each design as closely as possible:
>
> 1. **notification_center** → replace `apps/family_elder_app/lib/features/notifications/presentation/notification_inbox_screen.dart`, and use the **no_notifications** design as that screen's empty state
> 2. **settings_dashboard** → replace `apps/family_elder_app/lib/features/settings/presentation/settings_screen.dart` (keep the build-stamp label from `core/app_build.dart` visible somewhere)
> 3. **ai_companion** → replace `apps/family_elder_app/lib/features/assistant/presentation/assistant_screen.dart`
> 4. **add_medication** (both frames 1 and 2) → replace `apps/family_elder_app/lib/features/medications/presentation/medications_screen.dart`
>
> Keep all existing data providers, routes, navigation and functionality — visuals only. Don't invent data. Skip `flutter analyze` (not installed locally, CI runs it). Commit and push to `claude/elder-care-platform-mx27jo` when done.

---

## BATCH C — health, emergency, money

> Using the Stitch MCP, convert these screens to Flutter, one after another, matching each design as closely as possible:
>
> 1. **emergency_medical_profile** (both frames 1 and 2) → replace `apps/family_elder_app/lib/features/health_profile/presentation/health_profile_screen.dart`
> 2. **emergency_sos_active** → replace `apps/family_elder_app/lib/features/sos/presentation/sos_screen.dart`
> 3. **premium_plans** → replace `apps/family_elder_app/lib/features/care_plans/presentation/care_plans_screen.dart`
> 4. **secure_payment** → restyle `apps/family_elder_app/lib/features/payments/presentation/payment_flow_screens.dart`
>
> **Critical:** the SOS screen's trigger logic and the care-plans Razorpay payment-link flow must keep working exactly as they do now — restyle only. Keep all providers, routes and functionality. Skip `flutter analyze`. Commit and push to `claude/elder-care-platform-mx27jo`.

---

## BATCH D — caregivers and doctors

> Using the Stitch MCP, convert these screens to Flutter, one after another, matching each design as closely as possible:
>
> 1. **caregiver_marketplace** → restyle the list in `apps/family_elder_app/lib/features/booking/presentation/caregiver_select_screen.dart`
> 2. **caregiver_details** → restyle the caregiver detail view/sheet in that same file
> 3. **doctor_consultations** → replace `apps/family_elder_app/lib/features/doctors/presentation/doctors_screen.dart`
> 4. **family_circle_permissions** → replace `apps/family_elder_app/lib/features/family_access/presentation/family_access_screen.dart`
>
> Keep the trust-tier badges, verification states and consent toggles working exactly as they do — these are trust surfaces, so no functional change, visuals only. Skip `flutter analyze`. Commit and push to `claude/elder-care-platform-mx27jo`.

---

## BATCH E — the front door (auth + onboarding)

> Using the Stitch MCP, convert these screens to Flutter, one after another, matching each design as closely as possible:
>
> 1. **login** → restyle `apps/family_elder_app/lib/features/auth/presentation/login_screen.dart`
> 2. **create_account** → restyle the sign-up mode of that same login screen
> 3. **forgot_password** → restyle the password-reset flow in that same file
> 4. **role_selection** → replace `apps/family_elder_app/lib/features/auth/presentation/choose_role_screen.dart`
> 5. **splash_onboarding** → replace `apps/family_elder_app/lib/features/onboarding/presentation/onboarding_screen.dart`
>
> Keep the build stamp `kAppBuildLabel` visible on the login screen, keep the tagline "Your parents' safety net. / A trusted elder-care ecosystem for families.", and keep email/password + Google Sign-In working. The app is branded **SETU** — never "CareHive". Skip `flutter analyze`. Commit and push to `claude/elder-care-platform-mx27jo`.

---

## BATCH F — the last mile

> Using the Stitch MCP, convert these screens to Flutter, one after another, matching each design as closely as possible:
>
> 1. **add_elder_profile** → restyle the `showAddElderDialog` flow in `apps/family_elder_app/lib/features/family_home/presentation/family_home_screen.dart`
> 2. **action_successful** → restyle the shared success view in `apps/family_elder_app/lib/core/action_success.dart` so every "done!" moment across the app uses it
> 3. **caregiver_dashboard** → replace `apps/family_elder_app/lib/features/job_queue/presentation/job_queue_screen.dart`
> 4. **visit_task_checklist** → restyle `apps/family_elder_app/lib/features/visit_tools/presentation/visit_tools_section.dart`
> 5. **otp_verification** → restyle `apps/family_elder_app/lib/features/otp_visit/presentation/otp_visit_screen.dart`
>
> Keep all providers, routes and functionality — visuals only. The OTP visit flow's start/end verification must keep working unchanged. Skip `flutter analyze`. Commit and push to `claude/elder-care-platform-mx27jo`.

---

## After every batch

1. Tell me (in the web chat) which batch you finished — I pull it in, audit it, and fix anything CI flags.
2. Every push auto-builds an APK: **GitHub → Actions → Build APK → latest run → `setu-apk`**.
3. Install it and check the build stamp on the login screen matches the newest version.

## If a screen comes out worse

Just say to Claude: **"revert that screen, don't commit it."** Nothing is lost — the old version is safe in git.

## Rough time

Each batch is roughly 30–50 minutes of Claude working. Six batches ≈ one focused afternoon. You don't have to do them in one sitting — the order above is most-important-first, so stopping halfway still leaves the app much better than it was.
