# The feature list, reviewed honestly

*Your list has ~130 items across three priorities. This maps every group to
what already exists, what's a small addition, what's genuinely months of
work, and the four things I'd argue against building at all.*

Read the last section first if you read nothing else.

---

## Already built — just not obvious

Worth knowing before building anything: these exist and work today.

| You asked for | Where it already is |
|---|---|
| Blood group, allergies, conditions | `elder_health_profile` → Health profile screen |
| Insurance details, doctor contact | `elder_administrative_profile` → same screen |
| Emergency contacts | `elder_profiles.emergency_contacts` |
| Family members | `family_links` → Family access screen |
| Preferred language | `elder_profiles.primary_language` |
| Medicine schedule + adherence | `medication_doses` + the weekly chart |
| Weekly / monthly reports | Reports screen + `ai-visit-report-generate` |
| Appointments, caregiver visits | Appointments + booking |
| Medicine, appointment, health alerts | `reminders-dispatch-sweep` + FCM push |
| Video consultation | Agora, wired and keyed |
| Emergency alerts to family | `sos-trigger` |
| AI summary, recommendations | `ai-care-assistant`, `recommendations-generate` |
| Encryption, audit logs, privacy controls | RLS + `audit_log` + consent centre |
| Subscription tiers | Care plans + Razorpay |

**The gap is mostly surfacing, not building.** Several of these are one screen
away from being visible.

---

## Priority 1 — the real gaps 🔴

### Profile
| Item | Status |
|---|---|
| Age | Derive from `dob` — one line |
| Gender, height, weight, photo | **Added in migration 0028** |
| Everything else on your list | Already stored, needs surfacing on one screen |

**Work: ~1 day.** One "Profile" screen pulling three tables together.

### Medication
| Item | Status |
|---|---|
| Image, remaining pills, refill reminder, notes | **Added in migration 0028** |
| Dosage, history, weekly adherence, monthly report | Already exist |
| Missed-medicine alert | Sweep exists; needs the missed-dose branch |
| Medicine alarm | Needs `flutter_local_notifications` — a real addition |
| Medicine search, QR scanner | **See "what I'd push back on"** |

**Work: ~3 days**, excluding the scanner.

### Emergency
| Item | Status |
|---|---|
| One-tap SOS, auto-send location, emergency contacts | Already work |
| Medical ID card | Data exists; needs a lock-screen-style view — half a day |
| Auto-call family | `url_launcher` can dial — half a day |
| Flashlight blink, voice message | Small, needs one plugin each |
| Nearby hospitals | Needs Google Places API — paid, ~1 day |
| **Auto-call ambulance** | **See below. Please read.** |

---

## Priority 2 — mostly weeks, one blocker 🟠

**Family dashboard** — location, medicines, activity, appointments, mood, AI
summary and emergency alerts are all live. **Heart rate and battery % cannot
be built**: nothing measures them. Heart rate needs a wearable; battery %
needs the elder's phone reporting in, which is a background service and a
battery-drain problem of its own.

**Caregiver dashboard** — availability, schedule, patients, visits, notes and
medication updates exist. Chat and video are additions (~1 week).

**Doctor dashboard** — this is a **new role and a new app surface**, not a
screen. Prescriptions and lab reports are their own data model. Realistically
**3–4 weeks**, and I'd not build it until a doctor has agreed to use it.

**Health tracking** — this is the one to be careful about. Weight, BP, sugar,
water and temperature are *typed in* and buildable in ~1 week with charts.
Heart rate, SpO₂, sleep, steps and calories **need a device**. Without Health
Connect or a wearable, the only way to show them is to make them up.

**Reports / Calendar / Notifications** — extensions of what exists.
PDF export is the biggest single piece (~3 days).

---

## Priority 3 — the honest picture 🟢

| Group | Reality |
|---|---|
| AI risk prediction, blood-test explanation, medicine interactions | **Regulated medical advice.** The app's guardrail currently *refuses* medical questions on purpose. Changing that is a legal decision, not a coding one. |
| AI voice assistant ("Hey SETU") | Wake-word detection is genuinely hard. ~3–4 weeks for a poor version. |
| Wearables (Apple/Samsung/Fitbit/Garmin) | Health Connect on Android is realistic (~2 weeks). Apple Watch requires an iOS app you don't have. |
| Fall detection | **See below.** |
| Smart home (Alexa, Google Home, sensors) | Separate integrations, ~2 weeks each, and hardware you'd have to ship. |
| UI polish (animations, glassmorphism, dark mode, large font) | Dark mode and large-font already exist. Lottie, skeletons and shadows are ~1 week and genuinely worth it. |
| Security (biometrics, PIN, backup) | Biometric lock ~2 days and worth doing. Encryption, audit logs, permissions already exist. |

---

## Four things I'd argue against 🛑

I'll build any of these if you tell me to. But you should decide knowing this.

**1. Auto-call ambulance.** You have no ambulance partner, no dispatch
agreement, and no operations team. If the app dials 108 automatically and the
call fails, or dials for a false alarm and a real emergency is delayed, the
liability lands on you personally — you're not incorporated yet. Ambulance
services also don't accept automated calls without an agreement.
*Instead:* one large tap-to-call button, with the elder's medical ID on screen
for the human making the call.

**2. Fall detection.** Phone-accelerometer fall detection is notoriously
unreliable — Apple spent years on it with dedicated hardware. False positives
train families to ignore alerts, which is worse than having none. A missed
real fall in an app that promises detection is a lawsuit.
*Instead:* the missed-check-in escalation you already have. If Amma hasn't
checked in by 11am, the family is told. Less impressive, actually works.

**3. Heart rate, SpO₂, sleep, steps — without a device.** There is no honest
way to show these. Any number would be invented, and invented health data on a
screen a doctor might read is dangerous.
*Instead:* ship Health Connect integration, or leave them out and say so.

**4. Medicine interaction checking.** This is clinical decision support. In
India it edges toward regulation as a medical device, and a wrong answer can
kill someone. Your own AI guardrail refuses medical questions for exactly this
reason.
*Instead:* store the medicine list and make it easy to *show a pharmacist*.

---

## What I'd actually do, in order

**This week — finish what's nearly done (~1 week)**
1. Expanded profile: photo, age, gender, height, weight, all in one screen
2. Medication detail: photo, pill count, refill warning, notes
3. Medical ID card + tap-to-call family from SOS
4. Missed-medicine alert

That's most of Priority 1, and it makes the app feel complete.

**Then — get it in front of five families.** Everything below this line is a
guess until real families use it. The five families will tell you which of
your 130 items actually matter, and it will be a much shorter list than this
one.

**Then, based on what they say — pick two (~3 weeks)**
- Typed-in health tracking (BP, sugar, weight) with charts
- Biometric lock
- PDF report export and share
- UI polish: Lottie, skeleton loaders, shadows

**Later, once there's revenue**
- Health Connect / wearables
- Doctor dashboard (only after a doctor commits to using it)
- Voice assistant

---

## The one thing worth saying plainly

This list describes a product several years and a funded team away. That's not
a criticism — it's a good vision. But **shipping 20% of it to five real
families beats 100% of it to nobody**, and every week spent on smart-home
integration is a week not spent finding out whether a daughter in Bangalore
will pay ₹499 a month.

Build the four things at the top of this week's list. Then go and watch
someone's mother use it.
