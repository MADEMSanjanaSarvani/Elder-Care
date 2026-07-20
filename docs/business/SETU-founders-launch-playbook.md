# SETU — Founding-Team Launch Playbook

*The 15-deliverable master document · India launch → global scale · v1.0*
*Read alongside `SETU-feasibility-and-launch-plan.md` (which covers the module-by-module
feasibility). This document goes deeper on lifecycle, AI, smart-home, family experience,
worst-case handling, global expansion, the 10-year vision, and launch/investor readiness.*

> Premise: UI/UX, architecture and feasibility are done. This is the **operating brain** of
> the company — what has to be true in the real world for SETU to work and scale. It is
> deliberately decisive. Where a number appears, it is an **order-of-magnitude planning
> figure** to pressure-test the model, not a quote; replace with real vendor/market data in
> the launch city before fundraising.

---

## Deliverable 1 — Product Requirement Document (the "why it exists")

**Core job-to-be-done:** *"Let me care for my ageing parent as if I were there, even when I'm not — and guarantee that help arrives in an emergency."*

**Primary personas:**
- **The Payer** — adult child, 30–55, often in another city or country (NRI). High income, high guilt, low time. Buys peace of mind.
- **The User** — elder, 65–90+, variable digital literacy and health. Values dignity, familiarity, human contact.
- **The Supply** — caregivers (GDAs/nurses) and RMPs (doctors). The constraint.

**Product pillars (already built):** SOS (108-first), medication management, caregiver booking + live visit, timeline/peace-of-mind, teleconsult, health records (consent-gated), AI companion, family circle, wellness, care plans/subscriptions.

**Non-negotiable product principles:**
1. **Safety is never paywalled** (SOS + emergency alerting free forever).
2. **The elder's dignity and consent are the anchor** — no surveillance-by-default.
3. **Every safety-critical path degrades offline** (SOS dials 108 + SMS without data).
4. **The AI never practices medicine.**
5. **Trust > features** — every decision judged by whether it raises trust.

---

## Deliverable 2 — Business Requirement Document + Business Model

### 2.1 Revenue models (five legs)
1. **Subscriptions (recurring, high-margin):** Free / Care+ / Care Pro / Managed Care.
2. **Service commission (transactional):** ~20% blended on caregiver visits & services.
3. **Teleconsult margin:** per-consult platform fee / revenue share with doctors.
4. **B2B2C:** corporate elder-care benefits, **insurer tie-ups**, hospital referral deals.
5. **Premium add-ons:** managed care manager, physiotherapy packages, diagnostic bundles.

### 2.2 Subscription ladder (India pricing, illustrative)
| Plan | Price/mo | Who | Includes |
|---|---|---|---|
| **Free** | ₹0 | Everyone | SOS (108 + family alert), med reminders, 1 elder, basic timeline |
| **Care+** | ₹499 | Engaged families | Full timeline, AI companion, health records, family circle, reduced commission |
| **Care Pro** | ₹1,499 | NRIs / multi-elder | Priority dispatch, teleconsults included/discounted, weekly AI wellness reports, multi-elder |
| **Managed Care** | ₹4,999–15,000 | High-touch / NRI | Dedicated care manager, bundled recurring visits, quarterly health reviews |

**Corporate plan:** employers buy elder-care as an employee benefit (₹X/employee/yr) — HR-facing dashboard, bulk onboarding.
**NRI plan:** premium managed-care priced in USD/AED, marketed on diaspora channels; highest ARPU.
**Insurance tie-up:** bundled with health/senior insurance policies; insurer subsidises subscription in exchange for adherence/wellness data (consent-gated) and reduced claims.
**Government collaboration:** state elder-welfare schemes, senior-citizen helplines, smart-city health programs — B2G pilots (slow money, strong credibility).

### 2.3 Illustrative financial model (see Deliverable 4 for cost detail)
- **Blended ARPU (paying family):** ₹700–1,100/mo (subscription + commission).
- **Managed-care ARPU:** ₹5,000–15,000/mo.
- **Contribution margin target:** positive per active family from Day 1; subscriptions cover fixed platform cost, commission funds growth.
- **Target:** LTV:CAC ≥ 3:1 within 12–18 months; referral density is the cheat code.

---

## Deliverable 3 — Operations Requirement Document

### 3.1 Elderly User Lifecycle Management System
The product must adapt as the elder ages and declines. Model each user on a **care-stage axis**, and let the app + ops flex per stage.

| Timeline / Trigger | What happens | System behaviour |
|---|---|---|
| **Download → Day 0** | Onboarding, role pick, add elder, consent, emergency contacts, first caregiver/subscription. | Guided setup; "activation" = first SOS test + first med reminder + emergency profile complete. |
| **Day 1** | Habit formation. First daily check-in, first timeline events. | Nudge family; confirm reminders working; welcome-call from ops for premium. |
| **Month 1** | Value proof or churn. | Weekly AI report; caregiver visit; "is this working?" NPS check; convert Free→Care+. |
| **Month 6** | Deepening or drift. | Care review; adherence trends; upsell managed care if needs grew. |
| **Year 1** | Renewal / relationship. | Annual health review; loyalty; family expansion (more members). |
| **Year 5** | Ecosystem lock-in. | Lifetime medical history compounding; likely stage escalation (below). |
| **Health condition changes** | Care plan must escalate. | Re-assessment flow; new care plan tier; more frequent visits; doctor loop. |
| **Becomes bedridden** | Shift from "check-ins" to "continuous care". | Live-in/long-shift caregiver, physiotherapy, medical-equipment partners, bedsore/hygiene protocols, doctor home-visits. |
| **Dementia onset** | Safety + consent model changes. | **Guardian/capacity flow** — legal guardian assumes consent; wandering/location safeguards (opt-in), simplified elder UI, caregiver dementia-training tier, family gets more control by legal authority. |
| **Moves city** | Continuity of care. | Re-match local caregivers/doctors; port records; region config switch; warm handoff. |
| **Family member changes** | Access/authority transfer. | Coordinator reassignment with verification; audit-logged; old member access revoked. |
| **Multiple family members** | Concurrent access. | Role-scoped consent (Coordinator / Caregiver-family / Viewer); conflict resolved in favour of elder preference / legal guardian. |
| **End of life** | Dignity + closure. | Palliative-care mode, hospice partners, family support; **post-passing:** memorialise data, controlled export to family, respectful account closure per DPDP erasure. |

**Key build implications (no code here, just requirements):** a **care-stage field** driving UI/dispatch; a **guardianship/capacity module**; a **record-portability/city-transfer flow**; a **coordinator-handoff flow**; an **end-of-life/account-closure flow**. Several already have hooks (consent, RLS, erasure) — these extend them.

### 3.2 Caregiver Management System (complete)
- **Density before launch:** target a **caregiver:active-family ratio of ~1:8–1:12** in the launch cluster (a caregiver doing daily/short visits can serve multiple families; live-in is 1:1). **Minimum viable pool: ~25–40 verified caregivers** in one dense pincode cluster before opening bookings, so no request goes unmatched (cold marketplace death is a no-show, not a bad review).
- **Assignment:** match on proximity (service radius), skill fit, availability, language, and **reliability score** (on-time %, no-show %, rating, dispute rate). High reliability → priority + better jobs = quality flywheel.
- **Training:** mandatory onboarding (conduct, dignity, SOS, app, hygiene, privacy) → skill tiers (dementia, fall-prevention, palliative) via HSSC/nursing partners → rating-triggered retraining. Training gates access to higher-paying jobs.
- **Payment:** escrow → weekly settlement via Razorpay Route, minus 20% (15% intro). Optional instant-payout perk.
- **Promotion:** tiered (Bronze→Silver→Gold→Elite) by reliability + training + tenure → higher visibility, premium jobs, better rates.
- **Removal / resignation:** clean contractor offboarding; reassign their active families with warm handoff; withhold payout on unresolved disputes; deactivate on 3-strike or safety breach.
- **Fraud / abuse / wrong-location / emergency-unavailability:** see the Worst-Case Handbook (Deliverable 12) — each has detection, response, and prevention.

### 3.3 Doctor Operations
- **Onboarding:** partner model; RMPs onboarded with NMC/State-Council registration.
- **Verification:** NMC/IMR registry check + degree + ID + registration validity; periodic re-verify.
- **Consultation workflow:** book → pay/verify entitlement → Agora video room → clinical notes → e-prescription → shared to family/pharmacy with consent. Under **Telemedicine Practice Guidelines 2020**.
- **Availability:** doctor sets slots; SETU shows real-time availability; buffer + no-show handling.
- **Prescriptions:** digitally signed with registration number; respect drug-schedule tele-prescription limits; stored encrypted, consent-shared.
- **Ratings:** patient rates; aggregate shown, anonymized reviews to doctor.
- **Legal:** doctor carries clinical liability + indemnity; SETU is the platform, not the practitioner (disclaimers + agreements).

---

## Deliverable 4 — Financial Analysis Report (cost by scale)

Costs scale with **active usage** (visits, calls, SOS, AI turns, tracked trips), not raw installs. "Active %" and ARPU drive real numbers. Figures below are **planning order-of-magnitude** to validate unit economics.

| Cost line | 100 | 1,000 | 10,000 | 100,000 | 1,000,000 |
|---|---|---|---|---|---|
| **Cloud/DB (Supabase→managed PG)** | Free–Pro (~$25/mo) | Pro (~$25–100) | Team + replica (~$0.6–2k/mo) | Dedicated PG + replicas (~$3–8k/mo) | Sharded + cache + queues (~$20–50k/mo) |
| **AI / LLM** | trivial | ~$50–200/mo | scales w/ companion turns; cap free tier (~$1–4k) | meter per tier; small+large hybrid (~$10–40k) | committed spend (~$80–250k) |
| **Video (Agora)** | ~$0 | low | grows w/ consult-min (~$0.5–3k) | (~$5–25k) | negotiate committed-use (major line) |
| **Maps (Mappls)** | ~$0 | low | grows w/ active trips | moderate; cache tiles | enterprise contract |
| **SMS/OTP (MSG91/Gupshup)** | pennies | ~$20–100 | ~$500–2k | ~$5–20k | bulk contract; prefer push/WhatsApp |
| **Push (FCM)** | free | free | free | free | free (near-zero) |
| **Payment gateway (~2% GMV)** | ~2% | ~2% | ~2% | negotiate MDR | enterprise MDR |
| **3rd-party (KYC/BGV per caregiver, monitoring)** | per-verification | grows w/ supply | grows w/ supply | volume pricing | volume pricing |
| **Ops headcount (the real cost)** | founders | small ops+T&S | city ops teams | multi-city ops + T&S + support | regional org |

**Illustrative P&L logic (per active paying family/mo):**
- Revenue: ₹700–1,100 blended.
- Variable cost: payment ~2% GMV + AI/video/maps/SMS (small, metered) + support allocation → typically **< ₹150–250**.
- **Contribution margin: strongly positive.** The company's cost centre is **trust-and-safety ops, verification, insurance, and city-launch subsidy** — model these explicitly; servers are noise by comparison.

**Break-even logic:** fixed cost (ops + T&S + insurance + platform) ÷ contribution margin per family = break-even active families per city. Design the city-launch playbook to reach that number before opening the next city.

---

## Deliverable 5 — Legal Analysis Report (agreements & policies)

*All to be drafted/reviewed by an Indian healthcare + tech lawyer before launch. DPDP-first.*

| Instrument | Must contain |
|---|---|
| **Caregiver Agreement** | Independent-contractor status; conduct + dignity code; verification consent; confidentiality/DPDP; SLA + penalties; payout terms + commission; insurance; termination; anti-abuse + reporting. |
| **Doctor Agreement** | RMP registration warranty; Telemedicine-Guidelines compliance; clinical liability + indemnity on the doctor; prescription rules; data handling; ratings; termination. |
| **Hospital Agreement** | Referral/emergency terms; response expectations; liability boundaries; data-sharing scope + consent; branding. |
| **User (Family/Elder) Agreement** | Platform-intermediary positioning; service by independent providers; **SOS disclaimer (108-first, no guaranteed response)**; acceptable use; account/consent; liability limits. |
| **Subscription Agreement** | Plan terms, auto-renewal, Play-billing rules, price changes, cancellation. |
| **Privacy Policy** | DPDP notice: data types, purpose, consent, retention, rights, grievance officer, sub-processors (Agora, LLM, PG, maps, BGV), cross-border transfer. |
| **Cancellation Policy** | Windows, notice periods, per-service rules. |
| **Refund Policy** | Full/partial/credit matrix; no-show = full refund + goodwill credit. |
| **Emergency-Service Disclaimer** | SETU coordinates/notifies; not an emergency medical service; call 108/112; no SLA guarantee. |
| **AI Disclaimer** | Companion, not medical advice; may be processed by third-party model; escalation to human/doctor. |
| **Medical Disclaimer** | Teleconsults by licensed RMPs; SETU doesn't practice medicine. |
| **Data-Sharing Policy** | Consent-scoped, revocable, logged; who sees what (family roles, caregiver mid-visit subset, doctor consult scope). |

Plus: **insurance stack** (professional indemnity, public liability, caregiver accident, cyber), **entity/IP/founder agreements**, **grievance + DPO appointment**, **breach-notification runbook**.

---

## Deliverable 6 — Risk Assessment Report
See the module risk register in `SETU-feasibility-and-launch-plan.md §14` (fraud, fake doctors, payment, SOS failure, breach, disputes, supply shortage, regulatory, reputational). The **Worst-Case Handbook (Deliverable 12)** below expands the highest-severity ones into full playbooks. **Top existential risks:** (1) a mishandled safety incident, (2) a data breach, (3) SOS failure, (4) supply collapse in the launch city. Over-invest in T&S ops + insurance + SOS reliability early.

---

## Deliverable 7 — Technical Feasibility Report (summary)
Architecture is done (Supabase/Postgres + RLS, Edge Functions, Flutter, Agora, consent-gated model, audit logging). Feasibility verdict: **the tech is the tractable 30%.** Key technical requirements to add for the roadmap: **care-stage + guardianship modules, device/health-data aggregation (Health Connect/HealthKit), offline-first safety paths, and observability/alerting for SOS reliability.** Data residency: **ap-south-1 (Mumbai)**; add regions only when entering new geographies.

---

## Deliverable 8 — Scalability Report
See cost table (Deliverable 4). Principles: meter expensive optional features (video/AI) into paid tiers; keep cheap safety free; channel cost order **push > SMS > WhatsApp > voice**; read-replicas + caching before sharding; location/video cost scales with *active sessions*, not installs; region-pin data. The architecture scales to 1M with staged infra; the binding constraint at scale is **ops/T&S org design**, not servers.

---

## Deliverable 9 — Partnership Strategy Report

| Partner type | Why | Model |
|---|---|---|
| **Hospitals** | Emergency escalation, doctor supply, credibility, referrals. | Referral + emergency-response MoU; co-branded; revenue share on referred admissions/consults. |
| **Diagnostic centres** | Home sample collection, health-record enrichment. | Commission on booked tests; API for reports into records. |
| **Pharmacies** | Medicine refills, e-prescription fulfilment, adherence. | Commission on refills; integrate refill flow (already have refill hooks). |
| **Ambulance aggregators** (StanPlus/RED.Health, Ziqitza) | Secondary emergency transport after 108. | Per-dispatch; clearly secondary to 108. |
| **Physiotherapy** | Post-hospital, bedridden, mobility care. | Marketplace supply category; commission. |
| **Mental-wellness** | Loneliness, depression, dementia support. | Counsellor network; teleconsult category. |
| **Insurers** | Subsidised subscriptions, adherence data, lower claims. | B2B2C bundling; consent-gated wellness data; co-marketing. |
| **Caregiver agencies / training institutes** | Supply liquidity + certified pipeline. | Supply partnership + placement pipeline. |

**Sequencing:** hospitals + pharmacies + ambulance first (safety + refill loop), then diagnostics + physio (revenue expansion), then insurers + corporates (scale + ARPU), then government (credibility + volume).

---

## Deliverable 10 — Long-Term Elder-Care Roadmap (10 years)

SETU's endgame: **the lifetime operating system for ageing** — not an app, an ecosystem that follows a person from independent living to end-of-life, and holds the family together around them.

- **Years 1–2:** trusted caregiver + medication + SOS + teleconsult in Indian metros. Prove the loop.
- **Years 2–4:** managed care, insurer/corporate B2B2C, diagnostics/pharmacy/physio ecosystem, **lifetime medical history** as a moat.
- **Years 4–6:** **dementia & assisted-living** programs, long-term caregiver relationships (continuity, not gig churn), device/smart-home health aggregation, predictive wellness.
- **Years 6–10:** **end-of-life & palliative care**, **family succession** (records + care authority passing across generations), multi-provider care coordination, possibly **SETU-operated assisted-living / day-care centres** (asset-heavy, optional), and cross-border NRI care corridors.

**Ageing progression is the product roadmap:** independent → needs help → chronic/bedridden → cognitive decline → palliative → memorial. Each stage is a higher-ARPU, higher-trust product. The company that holds trust through stage 1 owns stages 2–6.

---

## Deliverable 11 — Global Expansion Roadmap

**Strategy: follow the diaspora, respect the regulator.** Start with corridors where NRIs pay for parents in India, then localise into each market's care system.

| Country | Emergency | Regulator / licensing | Privacy law | Payments | Key friction | Priority |
|---|---|---|---|---|---|---|
| **India** | 108/112 | NMC (doctors); RBI PA (payments); state gig laws | **DPDP 2023** | Razorpay/UPI | Supply liquidity, trust | **Launch** |
| **UAE** | 998/999 | DHA/DoH/MOHAP (health + telehealth licensing) | **PDPL (Decree-Law 45/2021)** | Network/Telr/Stripe | Health-facility licensing, Arabic localisation | **2nd (NRI corridor)** |
| **Singapore** | 995/995 | MOH / AIC; Healthcare Services Act licensing | **PDPA** | Stripe; PayNow | Licensing, high cost base | 3rd |
| **UK** | 999/111 | **CQC registration for regulated "personal care"**; GMC (doctors) | **UK GDPR + DPA 2018** | Stripe/GoCardless | CQC is a hard gate for care provision | 4th |
| **Australia** | 000 | My Aged Care; **Aged Care Quality & Safety Commission**; AHPRA | **Privacy Act / APPs** | Stripe | Aged-care regulatory regime | 5th |
| **USA** | 911 | **State-by-state medical licensing**; telehealth compacts | **HIPAA** + state (CCPA etc.) | Stripe | HIPAA + malpractice + 50-state licensing + litigation | Last (highest liability) |

**Localisation checklist per market:** emergency number + escalation, regulator licensing, privacy-law re-papering, payment rails, language + cultural norms, local supply (caregivers/doctors), insurance/liability, data residency. **DPDP-first architecture makes GDPR/PDPA adaptation cheaper; HIPAA + US litigation make the USA the last, most-capitalised move.**

---

## Deliverable 12 — Worst-Case Scenario Handbook

*Each scenario: Problem → Cause → Detection → Response → Resolution → Legal → Prevention.*

**1. Elder collapses / medical emergency**
- *Cause:* fall, cardiac, stroke, etc. *Detection:* SOS trigger / missed check-in / caregiver report / (future) device alert. *Response:* 108/112-first screen → notify emergency contacts + share location → dispatch nearest caregiver → ops on-call → secondary ambulance. *Resolution:* incident report; follow-up care plan; doctor loop. *Legal:* disclaimers hold (coordination, not EMS); document the 108-first evidence. *Prevention:* med adherence, wellness monitoring, drill mode, emergency profile pre-filled.

**2. Caregiver theft**
- *Cause:* bad actor slipped verification. *Detection:* family report, missing-item complaint, pattern in disputes. *Response:* immediate suspension; investigate; involve police if warranted; compensate family via insurance. *Resolution:* deactivation + blocklist; claim. *Legal:* contractor agreement + police report; SETU liability limited but reputationally exposed → act fast + transparently. *Prevention:* BGV + police check + interview; live-visit tracking; item-inventory norms for live-in; insurance.

**3. Caregiver abuses elder**
- Highest-severity. *Detection:* elder/family report, behavioural signals, camera (if opted-in). *Response:* **instant suspension, safety runbook, elder safeguarding, police report, family support.** *Resolution:* permanent ban; cooperate with authorities; independent review. *Legal:* mandatory reporting; indemnity; PR runbook. *Prevention:* rigorous vetting, dignity training, ratings, spot audits, easy one-tap "report concern."

**4. Doctor malpractice**
- *Cause:* clinical error. *Detection:* patient complaint, outcome review. *Response:* suspend from platform pending review; support patient. *Resolution:* remove if substantiated; report to council. *Legal:* clinical liability + indemnity on the **doctor**; SETU is platform (agreements + disclaimers). *Prevention:* NMC verification, ratings, Telemedicine-Guidelines compliance, prescription limits.

**5. Payment failure / double charge**
- *Detection:* PG webhook + reconciliation job. *Response:* auto-retry; auto-refund duplicates; support SLA. *Resolution:* reconcile; refund/credit. *Legal:* transparent billing; consumer-protection compliance. *Prevention:* idempotent payment ops, reconciliation, monitoring.

**6. SOS failure (no data / no response / unacknowledged)**
- Catastrophic. *Cause:* connectivity, app bug, contacts unreachable. *Detection:* SOS ack-timeout monitoring. *Response:* **offline direct-dial 108/112 + SMS fallback (works without data)**; escalation ladder; ops on-call. *Resolution:* post-incident review; fix root cause. *Legal:* disclaimers + honest SLA; never advertise guaranteed response. *Prevention:* offline-first safety path, redundant channels, SOS observability/alerting, drills.

**7. Internet failure**
- *Response:* queue-and-forward for events; SOS falls back to dial+SMS; cached last-known data. *Prevention:* offline-first design on safety paths.

**8. Data breach**
- Catastrophic. *Detection:* monitoring, anomaly detection, pen-test findings. *Response:* contain, assess, **DPDP breach notification to Data Protection Board + affected principals**, rotate creds, forensics. *Resolution:* remediate, notify, support users. *Legal:* DPDP obligations; cyber-insurance; potential penalties. *Prevention:* encryption, RLS least-privilege, audit logs, pen-tests, secrets hygiene, cyber-insurance.

**9. Location-tracking failure**
- *Response:* provider fallback (Mappls↔Google); cached last-known; degrade gracefully; SOS uses last-known + phone GPS. *Prevention:* provider abstraction, redundancy.

**10. Wrong medication reminder**
- Safety-critical. *Cause:* data entry / dose-gen bug. *Detection:* family/caregiver flag; validation. *Response:* correct + notify; audit. *Resolution:* fix data; review. *Legal:* disclaimers; but errors erode trust fast → strict validation. *Prevention:* double-entry confirmation on med setup, caregiver/doctor verification of regimen, clear "confirm before dose."

**11. Ambulance delay**
- *Response:* 108-first (not dependent on SETU); secondary aggregator; keep family informed with ETA. *Legal:* SETU doesn't guarantee transport. *Prevention:* multiple ambulance partners; realistic expectations set.

**12. Lost / stolen device**
- *Response:* remote logout, biometric lock, short sessions. *Prevention:* biometric app-lock, re-auth for sensitive actions, session management.

**13. Subscription issues (failed renewal, wrong charge, cancel dispute)**
- *Response:* Play-compliant billing, easy cancel, prorated refunds, clear invoices. *Prevention:* transparent terms, dunning, support.

**14. Family disputes / contested guardianship**
- *Response:* anchor to elder preference / legal guardian; ops escalation; documented decisions. *Legal:* guardianship documentation; POA handling. *Prevention:* clear role/consent model, capacity/guardianship flow.

**15. Fraudulent registration (fake caregiver/doctor/family)**
- *Response:* KYC/BGV catches most; suspend + investigate suspicious accounts. *Legal:* fraud reporting. *Prevention:* KYC, NMC checks, document forensics, anomaly detection.

---

## Deliverable 13 — Complete Launch Checklist

**Legal/compliance:** entity + founder/IP agreements ✔ · lawyer-reviewed T&Cs, privacy (DPDP), all agreements/disclaimers ✔ · DPO + grievance officer ✔ · breach runbook ✔ · insurance stack bound ✔ · Play data-safety + policy pass ✔.
**Supply:** 25–40 verified caregivers in one cluster ✔ · 3–4 agency partnerships ✔ · doctor panel (NMC-verified) ✔ · pharmacy + ambulance partners ✔ · verification + BGV vendor live ✔.
**Product/tech:** SOS reliability tested (incl. offline) ✔ · payments + split + refunds tested ✔ · monitoring/alerting on SOS + payments ✔ · data residency (Mumbai) ✔ · account-deletion path exposed ✔ · **build stamp visible for QA** ✔.
**Ops:** verification, SOS, incident, dispute, refund runbooks written ✔ · on-call rota ✔ · support channel + SLA ✔ · admin/ops dashboard live (Deliverable 14) ✔.
**GTM:** launch-city cluster chosen (Visakhapatnam seeded) ✔ · NRI acquisition creatives ✔ · referral loop ✔ · trust page (verification standards, insurance, SOS SLA) ✔ · first-100-families success plan ✔.

**Go/No-Go gate:** do **not** open bookings until supply density + SOS reliability + insurance + legal are all green. A marketplace that no-shows on Day 1 doesn't get a Day 2.

---

## Deliverable 14 — Operations Dashboard (internal tools spec)
*Much of this exists in the admin dashboard; this is the complete target.*
- **Caregiver mgmt:** verification queue, document viewer, BGV status, reliability scores, tiers, suspensions, payouts.
- **Doctor mgmt:** NMC verification, availability, ratings, prescriptions audit.
- **Hospital/partner mgmt:** partner directory, MoUs, referral tracking.
- **Payments & refunds:** transactions, split-settlement, escrow, refunds/credits, reconciliation.
- **SOS monitoring:** live incident board, ack timers, escalation status, incident reports.
- **User mgmt:** families/elders, care-stage, consent map, guardianship.
- **Analytics:** activation, retention, GMV, ARPU, CAC, cohort, supply liquidity, no-show %.
- **AI monitoring:** guardrail hits, escalations, flagged/held reports, safety events.
- **Subscription mgmt:** plans, MRR, churn, dunning.
- **Reports & audit log:** every sensitive read/write (already instrumented) — the liability backbone.
- **Incident mgmt:** T&S cases, safety incidents, investigations, resolutions, legal flags.

---

## Deliverable 15 — Investor-Readiness + Startup Growth Strategy

**Investor-readiness checklist:**
- Clean cap table, entity, IP assignment, founder vesting.
- Data room: this playbook + feasibility doc + architecture + legal drafts + financial model.
- Metrics: activation, retention, GMV, ARPU, contribution margin, supply liquidity, NPS, SOS reliability, LTV:CAC.
- Proof: a **repeatable city-launch playbook** with real numbers from the beachhead.
- Compliance story: DPDP-first, 108-first SOS, verified supply, insurance — de-risked trust narrative.
- Clear ask + use of funds (supply density, T&S ops, city expansion, not servers).

**Growth strategy:**
1. **Win one city deep** (density > geography).
2. **NRI wedge** (highest WTP, sharpest pain) + **referral density** (buildings/localities compound).
3. **Repeatable playbook** → city-by-city, each hitting break-even before the next.
4. **ARPU expansion** via managed care + ecosystem (diagnostics, pharmacy, physio) + B2B2C (corporate, insurer).
5. **Moat = trust + lifetime medical history + supply relationships** — none of which a fast follower can copy quickly.

---

## The one-line strategy
**SETU wins by being the most *trusted* — not the most feature-rich — way to care for an ageing parent from anywhere; it grows by owning one city's trust at a time; and it becomes a billion-dollar company by holding that trust across the entire arc of ageing, from the first medication reminder to end-of-life, for a whole generation of families.**

*Living document — revisit after the first 100 families. Real operational data will overturn several assumptions here, and that is the point.*
