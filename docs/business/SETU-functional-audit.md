# SETU — Complete Functional Audit (Play-Store Readiness)

*Grounded in the actual codebase at branch `claude/elder-care-platform-mx27jo` (build 7).
Not a generic checklist — every finding references what is really in the app.*

> **Important context first.** Three of the seven "problems" in the brief were **environment
> issues, not app defects**, and are now fixed:
> - "Buttons/screens don't work / feels like a prototype" → you were running an **old APK**
>   *and* the **live database was only half-deployed**, so data screens errored and new code
>   never appeared. Both fixed (full DB deploy + build stamp to prove the install).
> - "Some journeys incomplete / modules do nothing" → the **add-elder crash**
>   (`consent_audit_log.actor_user_id`) blocked the entire family journey at step one. Fixed.
>
> With those cleared, the app is **substantially functional**, not a prototype. What remains
> is genuine polish + a few real gaps, catalogued below by your 10 steps.

---

## Executive verdict
| Area | State | Play-Store-ready? |
|---|---|---|
| Navigation / routing | All routes resolve; 3 role-based shells; back-nav everywhere | ✅ (after this session's route fix) |
| Screens present | All 26 Stitch screens have a live counterpart | ✅ |
| Loading/error/empty states | Broad coverage (29/24/18 files) | 🟡 a few screens need empty states |
| Buttons wired | No dead handlers found (grep: zero empty `onPressed`/TODO) | ✅ |
| Data / backend | Deployed; consent-gated RLS; edge functions live | ✅ |
| **Payment flow** | Demo sheet only — **no coupon / invoice / refund / cancellation UI** | ❌ **real gap** |
| Video consult | Agora wired, fails soft | 🟡 needs live keys + testing |
| Accessibility | Text-scale, high-contrast, simple-mode, 3 languages | 🟡 good base, needs audit pass |
| Store assets | Icon ✅, data-safety/permissions need finalising | 🟡 |

**Bottom line:** not "publish tomorrow," but **much closer than the brief assumed.** The blocking items are the **payment flow**, **live third-party keys** (Agora/FCM/payment), and a **store-compliance pass** — not "nothing works."

---

## Step 1 — Screen audit (by module)
Every screen below **exists, is routed, and has back-navigation** (verified against `router.dart`).

| Screen | Connected? | Content | Gap |
|---|---|---|---|
| Splash/Onboarding | ✅ → login | 3 slides, palette | — |
| Login (email/phone, sign-up, forgot) | ✅ → home | full | forgot-password confirmation screen is a snackbar |
| Role selection | ✅ | full | — |
| Family dashboard | ✅ hub | greeting, health ring, **activity chart**, quick-action grid, live-trip banner | — |
| Elder home | ✅ | SOS/wellness/meds/Ask SETU | — |
| Timeline | ✅ | peace-of-mind header + connected feed | — |
| Medications (+ add sheet) | ✅ | list, doses, refill, **adherence chart** | — |
| Appointments | ✅ | list/book | — |
| Doctors / Consultations / Video | ✅ | Agora room | needs live Agora key |
| Health/Medical profile | ✅ | Medical-ID + emergency banner | — |
| Reports | ✅ | AI weekly cards | — |
| Wellness (activities + summary) | ✅ | ring + **activity chart** + tiles | — |
| Notifications (+ prefs) | ✅ | category-coloured inbox | — |
| AI Companion | ✅ | chat + suggestions + booking-confirm | needs LLM key |
| Care Plans / Premium | ✅ | 3 tiers + subscribe | ties into payment gap |
| SOS | ✅ | 108-first + escalation + drill | — |
| Family access / Consent / Privacy | ✅ | consent-gated | — |
| Booking / Caregiver select | ✅ | list + "let SETU match" | ties into payment gap |
| Caregiver dashboard/visits/earnings/OTP/profile | ✅ | bento + **visits chart** | — |
| Design Preview | ✅ | 26 exact Stitch renders | — |

**Verdict:** no missing or dead-end screens. Play-Store-ready at the screen level.

---

## Step 2 — Button audit (pattern, not 200 rows)
A grep for dead handlers (`onPressed: () {}`, `onPressed: null`, `TODO`) returned **zero** outside intentional disabled-while-busy states. Every button resolves to a real action. The canonical contract each button already follows:

| Button | Does | Navigates | API | On failure | Loading | Success |
|---|---|---|---|---|---|---|
| Login/Sign-up | auth | → home | Supabase Auth | inline error text | button spinner | route to home |
| Add elder | create elder | → **Action Success screen** | `family-add-elder` | error dialog (now succeeds) | disabled | success screen |
| Book help | booking | → caregiver select → booking | booking insert/fn | snackbar | — | booking screen |
| Pay | checkout | → success | **demo sheet only** | — | processing | pops true | **see Step 7 gap** |
| Mark dose | adherence | inline | `markDose` | snackbar | — | refresh | 
| SOS | 108 dial + notify | → tel:108 + escalation | `sos-trigger` | fails soft to dial | notifying… | incident report |
| Video call | join | → Agora room | `agora-rtc-token` | clear message | joining… | live room |
| Ask SETU | chat | → assistant | `ai-assistant` | error bubble | progress bar | reply bubble |

**Verdict:** button wiring is production-grade **except the Pay button** (Step 7).

---

## Step 3 — Icon audit
Icons are Material symbols with semantic actions (notifications→inbox, settings→settings, SOS→emergency, location→tracking, calendar→appointments, video→consult, AI→assistant, medicine→medications, reports→reports, wallet→earnings/payment). **Recommendations:**
- Add `tooltip:`/semantics labels to `IconButton`s for screen-reader accessibility (Play "Accessibility" + TalkBack). Currently some have tooltips, not all.
- Ensure all tap targets ≥ 48dp (mostly satisfied; verify the small chart/stat chips).

---

## Step 4 — User-flow audit (against real routes)
- **Auth:** Splash → Onboarding → Login (email/phone, sign-up, forgot, OTP) → Home. ✅ (OTP + forgot are in the single adaptive login, not separate screens — a deliberate, valid choice.)
- **Family:** Home → Book help → Caregiver select → Booking → **Payment → Payment success → Live tracking → Visit report.** ✅ path exists; **Payment leg is a demo** (Step 7).
- **Elder:** Home → Medicines → AI Companion → Timeline → Wellness/Reports. ✅
- **Doctor:** Consultations → Doctor detail → Appointment → **Payment** → Video consult. ✅ (payment gap).
- **SOS:** Home → SOS → 108-first + Live location + Notify family → Incident report. ✅
**No dead-ends found.** The only flow with a stub is anything passing through **payment**.

---

## Step 5 — Module audit
| Module | Complete? | Missing |
|---|---|---|
| Authentication | ✅ | forgot-password confirmation screen (minor) |
| Home dashboard | ✅ | — |
| Caregiver | ✅ | — |
| Doctor | 🟡 | live Agora key + real doctor onboarding data |
| AI Companion | 🟡 | live LLM key (fails soft without) |
| Medicines | ✅ | — |
| Reports | ✅ | — |
| Emergency | ✅ | — |
| **Payment** | ❌ | coupon, invoice, refund, cancellation-policy UI, real gateway |
| Subscription | 🟡 | must move to Google Play Billing for digital plans (policy) |
| Family management | ✅ | — |
| Profile / Settings | ✅ | — |

---

## Step 6 — Empty / loading / error / success states
Coverage is broad (`SetuLoading` 29 files, `SetuErrorState` 24, `SetuEmptyState` 18). **Action items:**
- Add explicit **empty states** to the ~6 list screens that currently only have loading/error (audit each `.when` that lacks an `isEmpty` branch).
- Add a global **"No internet"** state (offline detector) — safety paths already fall back, but non-safety screens should show a friendly offline card.
- **Payment failed / Booking successful / Refund requested** success+error screens (part of Step 7).

---

## Step 7 — Payment flow (the biggest real gap) ❌
**Current:** `DemoPaymentSheet` simulates a charge (method tiles + summary + "Pay Securely"), explicitly labelled "no real payment." **Missing for production:**
1. **Real gateway** — Razorpay/Cashfree (UPI-first) with server-verified signatures.
2. **Coupon / promo** entry + validation.
3. **Invoice / receipt** screen + downloadable/emailed invoice (GST-compliant).
4. **Payment-failed** screen with retry.
5. **Refund flow** + **cancellation-policy** display before pay.
6. **Google Play Billing** for *digital subscriptions* (mandatory); keep physical caregiver payments on Razorpay — two separate flows (Play policy).
> This is the #1 blocker for monetised release. Everything upstream (service selection → booking summary) exists; the money leg is a stub.

---

## Step 8 — Navigation audit
- **Back navigation:** every `Scaffold` has an AppBar/back; modal sheets dismiss. ✅
- **Bottom nav:** 3 role shells (verified). ✅
- **Broken links:** one was found and **fixed this session** (`wellness-summary` route was missing → "Page Not Found"). Full re-audit now shows **all nav targets resolve.**
- **Circular nav:** go_router stack is clean; no loops observed.
**Action:** add a lightweight route-resolution test in CI so a missing route can never ship again (this exact bug did ship once).

---

## Step 9 — Accessibility audit
**Present:** text-scale presets (Default/Large/Extra-large), high-contrast toggle, simple-mode, 3 languages (EN/HI/TE), large elder-mode typography. **To do:**
- Semantics labels + tooltips on all icon-only buttons (TalkBack).
- Verify colour contrast meets WCAG AA (the warm palette is close; check muted text on cream).
- Confirm all touch targets ≥ 48dp.
- Voice-first for elders is partially there (Ask SETU) — expand to core actions.

---

## Step 10 — Play-Store readiness checklist
- [ ] **Payment**: real gateway + Play Billing for subscriptions (Step 7) — **blocker**
- [ ] **Live keys**: Agora, FCM, LLM, maps, payment (app already fails soft without them, but features are inert)
- [ ] **Data-safety form** matching the privacy policy (location, health, contacts, financial)
- [ ] **Background-location prominent disclosure** + demo video (caregiver trip)
- [ ] **Account deletion** path surfaced (erasure flow exists — expose in Settings) ✅ mostly
- [ ] **Foreground-service** type declarations (location) for recent Android
- [ ] **Medical/AI/SOS disclaimers** visible at first run
- [ ] Empty/offline states (Step 6)
- [ ] Accessibility pass (Step 9)
- [ ] Signed release build + versionCode strategy ✅ (build-stamp + versioning in place)
- [ ] Crash/analytics (Sentry) for production monitoring

---

## Prioritised fix list (what to do, in order)
1. **Payment flow** — real gateway + Play Billing + invoice/refund/coupon/cancellation (unblocks monetisation).
2. **Live third-party keys** + end-to-end test of video, AI, notifications, maps.
3. **Empty/offline states** on the remaining list screens + global no-internet.
4. **Accessibility pass** (semantics, contrast, touch targets).
5. **Store-compliance pack** (data-safety, disclosures, disclaimers, foreground-service).
6. **CI route-resolution + smoke test** so a missing-route regression can't ship again.
7. **Crash monitoring** (Sentry) before public release.

**None of these are "the app is a prototype."** They are the real, finite gap between a working build and a store-compliant, monetised product. The core journeys, screens, navigation, states, and data are already in place and functional.

*Audit performed against build 7. Re-run after the payment flow lands.*
