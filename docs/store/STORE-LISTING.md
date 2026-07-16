# Play Store Listing Kit

Ready-to-paste copy and the confusing **Data Safety** answers for both apps.
Graphics for the listing are in this folder:
- App icon (512×512): `icon-512-family-elder.png`, `icon-512-caregiver.png`
- Feature graphic (1024×500): `feature-graphic-family.png`, `feature-graphic-caregiver.png`
- Phone screenshots: take 2–8 after you install the app (Play requires at least 2).

---

# App 1 — Setu (family & elder app)

**App name:** `Setu — Elder Care`

**Short description** (max 80 characters):
```
Coordinate care, medicines, visits and emergencies for your elders — together.
```

**Full description** (paste as-is; under Play's 4000-char limit):
```
Setu helps families care for their elders — together, from anywhere.

One place to organise everything about your parent's or grandparent's day-to-day
care, with the elder's privacy and consent at the centre.

WHAT YOU CAN DO
• Book trusted caregivers for companionship, medicine pickup, appointment help,
  home nursing and more.
• Track medicines and get reminders so a dose is never missed.
• Keep appointments and daily well-being check-ins in one shared timeline.
• See a clear activity timeline of every visit and update.
• Manage who in the family can see what — the elder grants access per category
  and can change it any time.
• Emergency SOS that helps call 108 and alerts the family and on-call team at
  the same time.
• Choose a monthly care plan, or pay per visit.

BUILT FOR ELDERS
• A simple, large-text mode with clear, high-contrast screens.
• Works in multiple languages.

PRIVACY FIRST
• The elder controls what each family member can see.
• Sensitive health details are shared only with consent, and every access is
  recorded so you can see who viewed what.

Setu is a care-coordination platform. It is not an emergency service — in a
medical emergency, always call 108.
```

**Category:** Medical (or Health & Fitness)
**Tags/keywords idea:** elder care, caregiver, medicine reminder, family care
**Contact email:** [support@yourdomain]
**Privacy Policy URL:** [your hosted PRIVACY-POLICY link]

---

# App 2 — Setu Care (caregiver app)

**App name:** `Setu Care — for Caregivers`

**Short description** (max 80 characters):
```
Your caregiving jobs, visit check-ins and earnings — all in one simple app.
```

**Full description:**
```
Setu Care is the work app for caregivers on the Setu platform.

• See your assigned visits and job queue at a glance.
• Check in and out of visits securely with a one-time code.
• Log visit activities and write handoff notes for the next shift.
• See the emergency health info you need during a visit — only when you need it.
• Track your earnings and payouts.
• Complete your verification (ID, background check and, for clinical roles,
  credentials) to build trust and unlock more work.

Setu Care is for verified caregivers who provide services through Setu.
```

**Category:** Business (or Medical)
**Contact email:** [support@yourdomain]
**Privacy Policy URL:** [your hosted PRIVACY-POLICY link]

---

# Data Safety form — answers for BOTH apps

Play Console → App content → **Data safety**. Answer truthfully; these match
how the apps actually work. (Confirm against the Privacy Policy before you
submit.)

**Does your app collect or share user data?** → **Yes**.

**Is all data encrypted in transit?** → **Yes** (HTTPS/TLS to Supabase).

**Do you provide a way to request data deletion?** → **Yes** — the app has an
in-app erasure request, and users can email you.

For each data type below: collected = **Yes**; shared with third parties =
generally **No** (processors that act on your behalf like hosting/AI/payment are
usually declared as "processing on your behalf," not "sharing" — read Play's
definition and match it). Purposes are **App functionality** (and **Account
management** for the identifiers).

Data types to declare:

| Category | Data type | Notes |
|---|---|---|
| Personal info | Name | Display name |
| Personal info | Phone number | Used to sign in (account) |
| Personal info | Other info | Date of birth (elder), preferred language |
| Health & fitness | Health info | Blood type, allergies, conditions, medications, notes — **optional**, user-entered |
| Location | Approximate/precise location | **Only** during an SOS emergency |
| Financial info | Payment info | Handled by the payment provider; caregivers provide payout details |
| App activity | Other actions | Bookings, visit logs, check-ins, reminders |
| App info & performance | (only if you later add crash reporting) | Declare then |

**Optional-vs-required:** mark Health info and Location as **optional** (the
user chooses to add health details; location is used only when they trigger
SOS). Mark phone number as **required** (needed to sign in).

**Is your app designed for children?** → **No** (adults only).

> If you later add analytics or crash reporting (e.g. Firebase, Sentry), you
> MUST update this form and the Privacy Policy to declare it.
```
