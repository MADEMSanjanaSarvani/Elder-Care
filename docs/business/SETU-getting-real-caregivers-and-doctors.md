# Where real caregivers and doctors actually come from

*You asked whether SETU can plug into a website or API and get real
caregivers and doctors from hospitals. Short answer: no, and it's important
to understand why, because the belief that supply is an integration problem
is what kills most healthcare marketplaces.*

---

## The honest answer

**There is no API in India that gives you caregivers or doctors.** Not
Practo, not Apollo, not any hospital chain. Here's why:

- **Hospitals don't have an API for their doctors** because their doctors
  aren't theirs to lend. A consultant at KIMS has his own practice and
  decides for himself which platforms he joins.
- **Practo and Apollo 24|7 are competitors, not suppliers.** Their doctor
  network is the entire asset — it's what they'd be giving away.
- **Caregivers aren't in any database at all.** Home-care nurses and
  attendants in India work through local nursing bureaus, word of mouth, and
  WhatsApp groups. There is nothing to integrate with.

Supply in this business is a **feet-on-the-ground problem**, not a software
problem. Every Indian player you'd recognise — Portea, Care24, Emoha, Yodda
— built supply by walking into nursing bureaus and signing them up one at a
time. There was no shortcut for them and there isn't one for you.

---

## What *does* exist as an API — and what it's actually for

Three real integrations exist. None of them supply people; two verify them
and one finds buildings.

### 1. ABDM — Ayushman Bharat Digital Mission (`abdm.gov.in`)

India's national health stack. Two registries matter:

- **HPR** (Healthcare Professionals Registry) — a doctor's registration
  details. Use it to **verify** that Dr. Rao is genuinely registered, not to
  discover doctors.
- **HFR** (Health Facility Registry) — registered clinics and hospitals.

You register as a **Health Information User**, get sandbox credentials, then
production access. Free, but the paperwork expects a registered entity, so
this realistically waits until you incorporate.

**What it gives you:** a trust badge that says "registration verified
against the national registry". That's genuinely valuable for elder care —
it's exactly what a worried daughter wants to see.

**What it does not give you:** a list of doctors willing to work with SETU.

### 2. NMC — National Medical Commission registry (`nmc.org.in`)

Public search for a doctor's registration number. No bulk API, and scraping
it would breach their terms. Use it manually to verify each doctor you
onboard — with five doctors, manual is completely fine.

### 3. Google Places API

Genuinely useful and available today. Finds real hospitals, clinics and
pharmacies near a location — this is how you'd build "nearby hospitals" on
the SOS screen. Paid, but the free tier covers a pilot comfortably.

**It finds facilities, not people.** A hospital pin on a map is not a doctor
who will take your patient's call.

---

## The real process, for Vizag, starting this week

### Caregivers — nursing bureaus are the answer

Every Indian city has them. They already employ trained attendants and
nurses and are constantly hunting for work.

1. **Search "nursing bureau Visakhapatnam" / "home nursing services Vizag"**
   on Google Maps. You'll find 10–20. Also ask at any diagnostic centre.
2. **Visit three in person.** Not a call — turn up. Ask: how many attendants
   do you have free, what do you charge per 12-hour shift, are your people
   police-verified?
3. **The pitch:** *"I'll send you bookings. You supply the caregiver. I take
   a commission and handle the family relationship, scheduling and payment."*
   They keep their staff, you get supply without payroll.
4. **Start with 5–6 caregivers, not 50.** You have five families.

**Also worth trying:** nursing colleges in Vizag. Final-year students and
recent graduates want part-time work and are cheaper, though they need more
supervision.

### Doctors — one at a time, and start with people who know you

1. **Your own family's GP first.** Someone who already trusts your family is
   worth ten cold approaches.
2. **The pitch is patient flow, not technology.** *"I have families in Vizag
   whose parents need follow-up consultations. Would you take video calls for
   them? You set your fee."*
3. **Two doctors is enough** for five families — one general physician, one
   with geriatric experience.
4. **Verify each registration number** on the NMC site yourself. Save the
   screenshot.

Don't build a doctor dashboard until a doctor has said yes. Build for a
person you can name.

---

## SETU is already built for this

You don't need new software to onboard real people — the pipeline exists:

| What you have | Where |
|---|---|
| Caregiver self-registration with document upload | `caregiver-register` function |
| Background-check and police-verification status | `caregivers.bgv_status`, `police_verification_status` |
| Trust tiers gating which services they may take | `probationary` → `standard` → `clinical_verified` |
| Admin verification queue with document viewer | Admin dashboard → Verification |
| Doctors with specialty, fee, languages, availability | `doctors` table |

Every caregiver starts at `probationary` with `bgv_status: not_started` and
appears in your verification queue. **That queue is you**, for now. You look
at their Aadhaar, their certificate and their police verification, and you
approve or you don't.

**Do not skip this because it's manual.** You are sending a stranger into an
elderly person's home. The one thing that ends this business overnight is an
unverified caregiver harming someone. Manual and careful beats automated and
negligent, and at five families manual costs you an afternoon.

---

## What to actually do

**This week**
1. Visit three nursing bureaus in Vizag. Sign one.
2. Ask your family's GP if they'd take video consultations.
3. Replace the six demo caregivers in `seed.sql` with real ones.

**Before taking money**
4. Police verification for every caregiver. Non-negotiable.
5. Verify each doctor's NMC registration by hand.
6. Written agreement with the bureau: commission, cancellation, who's liable.

**Once incorporated**
7. Register for ABDM sandbox, verify against HPR, show the badge in-app.
8. Add Google Places for nearby hospitals on the SOS screen.

---

## The thing worth internalising

A marketplace with no supply is a directory of nothing, and a marketplace
with unverified supply is a liability. **The moat here is not the app — it's
the roster of caregivers families trust.** That roster is built by turning
up in person, not by finding the right API.

The good news: you only need five caregivers and two doctors to serve five
families. That's a week of walking around Vizag, not a technology project.
