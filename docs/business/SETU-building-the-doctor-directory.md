# Building the doctor directory

*The workflow for getting real doctors and hospitals into SETU, and the one
shortcut that isn't worth taking.*

---

## The shortcut, and why not

The obvious move is to scrape Practo, Justdial and hospital websites and
import the doctors. I'd advise against it, for three reasons in increasing
order of importance:

**It's against their terms.** Those listings are a compiled database
somebody paid to build; the terms prohibit scraping and republishing. A
legal notice is a bad month for a pre-revenue startup, and it would arrive
addressed to you personally until you incorporate.

**A named doctor's listing is theirs to agree to.** A hospital's address is
public information about a business. "Dr. Rao, Cardiologist, sits Tue/Thu"
is a claim about a person, published to strangers, in a health context. Some
doctors will object, and they'd be right to.

**The one that actually matters: scraped data rots silently.** A snapshot
taken today is wrong within months — doctors move, change timings, retire,
die. The failure mode isn't a stale row in a table. It's a daughter in
Bangalore booking a caregiver to take her 80-year-old mother across Vizag to
a clinic that closed last year. That is the specific harm this directory
exists to prevent, so the data has to be something you can stand behind.

---

## What the pipeline does instead

**Facilities are imported. People are invited.**

```
Google Places  ──▶  clinic_imports  ──▶  admin review  ──▶  doctors
  (licensed)        (staging)            (a human)        (consented)
                                              │
  phone call to the doctor ────────────────────┘
```

### 1. Import the places

`clinics-import-places` pulls nearby hospitals and clinics from the Google
Places API — licensed for exactly this, and maintained by Google rather than
by a scrape you have to re-run.

```
POST /functions/v1/clinics-import-places
{ "region_id": "<vizag uuid>", "lat": 17.6868, "lng": 83.2185,
  "radius_m": 10000 }
```

Needs `GOOGLE_PLACES_API_KEY` in Supabase secrets. Admin-only. Re-running
refreshes listings rather than duplicating them, and **won't resurrect rows
an admin already rejected**.

Places returns *facilities*, never named doctors. That limit is the design,
not a gap.

### 2. Review what landed

Admin dashboard → **Clinic imports**. Everything sits at `status = 'pending'`
and nothing is visible to a family until you promote it. For each row: is it
real, is it in your service area, would you send someone's mother there?
There's a map link on each to check.

Promoting creates the *facility* record — inactive, and with consent still
unset, so it stays invisible until step 3. Rejecting is remembered: re-running
the import will not resurrect it.

### 3. Add the doctors — by phone, with consent

For each promoted clinic, call and ask which doctors sit there and when.
Then create the `doctors` row with:

| Field | Where it comes from |
|---|---|
| `display_name`, `specialty`, `qualification` | the call |
| `clinic_name`, `address`, `phone`, `lat`, `lng` | the promoted import |
| `consult_days`, `consult_start`, `consult_end` | the call |
| `registration_no` | the doctor |
| `registration_verified_at` | **you**, after checking nmc.org.in |
| `consent_status` | `'consented'` once they've said yes |
| `escort_available` | can a SETU caregiver take someone there? |

**The directory only shows `consent_status = 'consented'`.** A doctor who
hasn't agreed is not listed. This is enforced in the query, not left to
discipline.

### 4. Keep it fresh

`last_verified_at` records when a human last confirmed a listing. Anything
older than six months should be re-confirmed before a family is sent there.
Ten minutes of calls a month at your size.

---

## The script for the call

> "Namaste, I'm Sanjana from SETU. We help families in Vizag whose parents
> live alone — we take elders to their appointments and keep the family
> updated. I'd like to list Dr. ___ in our app so families can find him.
> There's no cost and no commission — we just show his name, specialisation
> and consulting hours, and families come to you. May I confirm his timings?"

You're offering them patients for free. Most will say yes. Note who said no
— set `consent_status = 'declined'` so nobody lists them by mistake later.

---

## Where it stands

**Built:** the staging table, the consent and verification fields, the
Places import function, and a directory screen that filters by specialty,
shows the clinic and hours, flags "sits today", and offers call and
directions.

**Yours to do:** get a Places API key, run the import for Vizag, and make
about twenty phone calls.

Twenty clinics and fifteen doctors is a comfortable directory for a pilot,
and it is roughly two afternoons of work. Zomato began the same way —
somebody typed the menus in.
