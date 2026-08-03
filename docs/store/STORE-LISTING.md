# Play Store Listing Kit

Ready-to-paste copy and the confusing **Data Safety** answers.

Graphics in this folder:
- App icon (512×512): `icon-512-family-elder.png`
- Feature graphic (1024×500): `feature-graphic-family.png`
- Phone screenshots: take 2–8 after you install the app (Play requires at
  least 2). The three worth shooting are **Today** (a couple of doses due,
  Taken buttons visible), **Last 30 days** (the adherence history), and
  **Medical ID**.

> The `*-caregiver.png` graphics belong to the caregiver app, which no longer
> exists. Ignore them.

---

# CareHive

**App name:** `CareHive — Medicine Record`

Keep "Medicine Record" in the name for search. Nobody searches "CareHive";
they search "medicine reminder" and "pill tracker".

**Tagline / hook (use on screenshots, the feature graphic, everywhere):**
> **Know what you took. Prove it when it matters.**

**Short description** (max 80 characters):
```
Dose reminders that ring on time, and a record you can show a doctor.
```

**Full description** (paste as-is; well under Play's 4000-char limit):
```
CareHive answers one question, and answers it honestly: what do I take now,
and did I already take it?

If you or your parent takes several long-term medicines, the answer usually
lives in someone's head. It is not there in the morning when the strip looks
half-used. It is not there when the doctor asks how the last month went. And
it is not there for a paramedic, who cannot ask at all.

REMINDERS THAT ACTUALLY ARRIVE
The alarm is scheduled on your phone, not sent from a server. It rings on the
minute, works with no internet, and survives a restart. Tap "Taken" on the
notification itself — the dose is recorded without opening the app, at the one
moment the record can be honest: while the tablet is in your hand.

A RECORD THAT TELLS THE TRUTH
Most trackers show one number and call it adherence. CareHive keeps three
separate facts:
• Taken — somebody said so.
• Not taken — somebody said that too.
• No record — the time passed and nobody marked it either way.

A dose nobody marked is never counted as a missed dose, because the app does
not know that it was. You get "18 of 22 taken, 3 with no record" instead of a
percentage that reads like medical information and isn't.

There are no streaks and no score. The moment marking a dose honestly costs
you something, people stop doing it, and the record quietly becomes fiction.

READY FOR THE QUESTION
One Medical ID screen holds the current medicines, allergies, conditions and
blood group, with a QR code that carries the details themselves — so it scans
with no network at all. It is what you hand to a doctor, and what a paramedic
can read.

FAMILY CAN SEE, AND CAN HELP
Family members see the same day you do and can mark a dose themselves — the
record shows who marked it, so a doctor can tell the difference. Daily
check-ins and a shared timeline mean nobody has to phone to ask if today was
all right.

EMERGENCY SOS
One tap helps you call 108 and alerts your family at the same time. It is not
a replacement for calling emergency services — the screen says so, and it puts
the 108 button first.

BUILT FOR ELDERS
Large-text mode, high-contrast screens, and a home screen that is simply
today's doses with the buttons on them. Nothing to choose, nothing to open.
Available in English, Hindi and Telugu.

PRIVATE BY DEFAULT
The elder controls what each family member can see, category by category, and
can change it at any time. Every access is recorded. Location is read only
when you press SOS, never in the background. There is no advertising and
nothing is sold.

CareHive is free. There is no subscription and no payment.

CareHive is not a medical service and does not give medical advice. Never
change a dose because of what this app shows you. In an emergency, call 108.
```

**Category:** Medical
**Tags/keywords:** medicine reminder, pill reminder, medication tracker,
elder care, adherence, medical ID
**Contact email:** sanjanasarvani2111@gmail.com
**Privacy Policy URL:** [your hosted PRIVACY-POLICY link — see `docs/public-site/`]

---

# Data Safety form

Play Console → App content → **Data safety**. These match how the app actually
works. Confirm against `docs/legal/PRIVACY-POLICY.md` before you submit.

**Does your app collect or share user data?** → **Yes**.

**Is all data encrypted in transit?** → **Yes** (HTTPS/TLS to Supabase).

**Do you provide a way to request data deletion?** → **Yes** — the app has an
in-app erasure request, and users can email you.

For each data type below: collected = **Yes**; shared with third parties =
**No** (processors acting on your behalf, like hosting and push delivery, are
declared as "processing on your behalf", not "sharing" — read Play's
definition and match it). Purposes are **App functionality**, plus **Account
management** for the identifiers.

| Category | Data type | Notes |
|---|---|---|
| Personal info | Name | Display name |
| Personal info | Email address | Used to sign in |
| Personal info | Phone number | Used to sign in (OTP) |
| Personal info | Other info | Date of birth (elder), preferred language, region |
| Health & fitness | Health info | Medicines, dose times and the taken/not-taken record; blood type, allergies, conditions, notes, uploaded documents — all **optional** and user-entered |
| Location | Approximate/precise location | **Only** at the moment an SOS is raised |
| App activity | Other actions | Check-ins, appointments, hospital stays, reminders |
| App info & performance | — | Nothing yet. Declare it the day you add crash reporting |

**No payment info.** The app takes no payments. If you ever add them, this row
and the Privacy Policy both have to change.

**Optional vs required:** mark Health info and Location as **optional** — the
user chooses to add health details, and location is used only when they press
SOS. Mark email/phone as **required** (needed to sign in).

**Is your app designed for children?** → **No** (adults only).

> If you later add analytics or crash reporting (Firebase Analytics, Sentry),
> you MUST update this form and the Privacy Policy to declare it.

---

# Things Play will ask about, and the honest answers

**"Your app requests USE_EXACT_ALARM."** Correct, and it is justifiable: the
app's core user-facing function is an alarm at a specific time. Say exactly
that. If review pushes back, the fallback is `SCHEDULE_EXACT_ALARM` with the
user granting it in settings — but the reminder is the product, so make the
case first.

**"Is this a medical app?"** It records what a person says they took. It does
not diagnose, advise or dose. The in-app terms say so in those words; keep the
store answer consistent with them.

**Health app declaration.** Play may require the Health Apps declaration form
because the app handles health data. Answer that it is a personal health
record and medication reminder, with no clinical decision support.
