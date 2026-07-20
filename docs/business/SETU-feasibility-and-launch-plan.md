# SETU — Pre-Launch Feasibility, Business & Operations Plan

*Internal planning document · India launch → global scale · v1.0*
*Audience: founders, first hires, prospective investors, legal/ops partners*

> This document assumes the app UI/UX is finalized. It answers **how SETU works in the
> real world** before development scales. It is opinionated on purpose — a founder needs
> decisions, not a menu. Every recommendation is grounded in Indian regulation and
> unit economics, with the reasoning shown so you can overrule it deliberately.

---

## 0. Executive summary — the 12 decisions that matter

| # | Decision | Recommendation |
|---|---|---|
| 1 | **What is SETU?** | A **managed marketplace** for elder care — not a pure listing app. We own quality, verification and dispatch; caregivers are supply, not employees (at first). |
| 2 | **Caregiver supply** | **Hybrid**: partner with 3–4 vetted agencies for Day-1 liquidity in *one* city, while building a direct-onboarded pool. Do **not** self-employ caregivers at launch (cost + labour-law liability). |
| 3 | **Commission** | **20% blended** take rate on services; introductory **15%** for first 500 caregivers to win supply. |
| 4 | **Emergency (SOS)** | **Dial-108/112 first, always.** SETU *augments* government emergency services (notifies family + shares location + dispatches a nearby caregiver). We are **not** an ambulance provider. This is a hard legal line. |
| 5 | **Doctors** | **Partner model only.** Onboard NMC-registered RMPs and teleconsult platforms/hospitals. Verify NMC registration + follow the **Telemedicine Practice Guidelines 2020**. No self-declared doctors. |
| 6 | **Payments** | **Razorpay Route** (or Cashfree) for split settlements + escrow via nodal account. Subscriptions on **Google Play Billing** (mandatory for digital subscriptions). |
| 7 | **Maps** | **Mappls (MapmyIndia)** as primary in India (cheaper, India-tuned), Google Maps as fallback. Foreground service + prominent disclosure for background location. |
| 8 | **Data & privacy** | Build for the **DPDP Act 2023** from Day 1. Data residency in **ap-south-1 (Mumbai)**. Consent-gated access is already in the schema (RLS) — keep it as the crown jewel. |
| 9 | **Video** | Keep **Agora** (already integrated); it's cost-efficient and India-proven. |
| 10 | **AI companion** | Claude/GPT with a **hard clinical guardrail** — companionship + triage-to-human only. Never diagnoses, never prescribes. Disclaimers + human escalation are non-negotiable. |
| 11 | **Launch geography** | **One city, one pincode cluster** (Visakhapatnam is already seeded) → prove the loop → then Tier-1 metros. |
| 12 | **Monetization mix** | Subscriptions (recurring, predictable) + service commission (transactional) + B2B2C (corporate/insurer tie-ups). Aim for subscriptions to cover fixed cost, commission to fund growth. |

**Verdict on feasibility:** *Feasible and fundable*, conditional on three things being treated as first-class, not afterthoughts: **(a)** trust & safety operations (verification + SOS reliability), **(b)** DPDP-grade privacy, **(c)** caregiver supply liquidity in the launch city. The technology is the *easy* 30%. The other 70% is operations and compliance — which is why this document is mostly about those.

---

## 1. Business perspective

### 1.1 What business are we actually in?
SETU is a **trust business wearing a software coat.** Families are not buying an app — they are buying *peace of mind that a vetted human will show up and that help arrives in an emergency*. Every product and ops decision should be judged against: **does this increase or decrease trust?**

Three-sided market:
- **Families** (payers, the wallet) — adult children, often NRIs or in different cities.
- **Elders** (users, the experience) — low digital literacy, high anxiety cost of failure.
- **Caregivers / doctors** (supply) — the constraint. Supply liquidity determines whether the marketplace works at all.

### 1.2 Why "managed marketplace," not "listing app" or "agency"
- A **pure listing app** (Justdial for caregivers) can't guarantee quality → trust collapses on the first bad caregiver → churn.
- A **fully self-employed agency** (own all caregivers) gives quality control but is capital-heavy, slow to scale, and drags full labour-law/PF/ESI liability.
- A **managed marketplace** (Urban Company model) is the sweet spot: SETU controls **verification, training standards, dispatch, ratings, payments and disputes**, while caregivers remain independent professionals or agency-supplied. This is the only model that scales trust *and* capital efficiency.

### 1.3 Go-to-market
1. **Beachhead:** one city, one dense cluster of pincodes. Saturate it. A marketplace that is "everywhere and thin" dies; one that is "deep in one place" compounds.
2. **NRI wedge:** market to NRIs (US/Gulf/UK) whose parents are in the launch city. They have the highest willingness-to-pay and the sharpest pain. Facebook/Google geo-targeting + diaspora community groups.
3. **Trust proof:** publish verification standards, insurance cover, and SOS SLA prominently. Trust is the conversion lever, not features.
4. **Referral loop:** one satisfied family refers 2–3 others in the same building/locality — density compounds.

---

## 2. Caregiver module — the operational core

This is where the company is won or lost. Treat it as a **supply-chain + trust-and-safety** problem.

### 2.1 Where do caregivers come from?
Layered sourcing, in priority order:
1. **Agency partnerships (Day-1 liquidity):** tie up with 3–4 established home-healthcare agencies (regional players; national ones like Portea/Care24/HCAH for reference standards). They supply pre-trained General Duty Assistants (GDAs)/nurses. SETU adds a verification + quality layer on top. Revenue-share instead of full margin, but instant supply.
2. **Direct onboarding (the long-term moat):** recruit individual GDAs, nurses, attendants via:
   - Healthcare Sector Skill Council (HSSC) / NSDC-certified GDA training institutes (they *produce* graduates who need placement).
   - ANM/GNM nursing college placement cells.
   - Referrals from existing verified caregivers (bonus-driven; caregivers know caregivers).
   - Field recruitment in the launch city.
3. **Retired nurses / experienced attendants** for premium "senior caregiver" tier.

**Decision: hybrid.** Agencies for speed, direct pool for margin and quality control. Do not self-employ at launch.

### 2.2 Should we hire caregivers ourselves (employees)?
**Not at launch.** Employment triggers **PF, ESI, gratuity, minimum wages, and misclassification risk**, plus you carry idle-time cost. Keep caregivers as **independent contractors** with a clear contractor agreement. Revisit an *employed "SETU Elite" cadre* only once you have predictable, dense demand (Phase 3) — a small salaried core for premium/managed-care contracts can be a differentiator, but it is a deliberate cost decision, not a default.

*Caveat:* Indian gig-worker regulation is tightening (Code on Social Security 2020, state gig-worker welfare acts e.g. Rajasthan/Karnataka). Budget for a **welfare/insurance contribution per caregiver** and keep contracts clean to avoid deemed-employment.

### 2.3 Should caregivers register through the app?
Yes — **self-registration funnel, human-gated approval.** The app collects the application + documents; a **SETU verification team member approves/rejects.** Never auto-approve. The app already has a caregiver registration + pending-verification + active-state flow — that is exactly right.

### 2.4 What documents must a caregiver submit?
Mandatory:
- **Government photo ID** (Aadhaar via **DigiLocker/offline eKYC** — do *not* store raw Aadhaar numbers; Aadhaar Act limits usage), plus a second ID (PAN / Voter ID / DL).
- **Address proof.**
- **Skill certificate** (HSSC GDA cert / nursing registration / ANM-GNM diploma) where applicable.
- **Experience letters / references** (min 2 contactable references).
- **Recent photograph** (for the family-facing profile + identity match on visit check-in).
- **Police verification / character certificate** (see 2.6).
- **Health fitness certificate** (incl. relevant immunizations) — this is elder care; a sick caregiver is a safety event.
- **Bank/UPI details** for payouts (already modeled in schema).

### 2.5 How should verification happen, who does it, how long?
**Multi-stage funnel with a target SLA of 3–5 working days:**

| Stage | Owner | Tooling |
|---|---|---|
| 1. Document upload | Caregiver (app) | App upload → secure storage |
| 2. Identity + document authenticity | **Third-party KYC/BGV vendor** (IDfy / AuthBridge / SpringVerify) via API | Automated ID match + document forensics |
| 3. Credential check | SETU verification associate | Manual review of skill certs, references |
| 4. Background + police check | BGV vendor + local police channel | See 2.6 |
| 5. Video/in-person interview | SETU ops (trained interviewer) | Structured rubric (2.7) |
| 6. Approve / reject / waitlist | Verification lead | Recorded decision + reason in audit log |

The document viewer + verification queue already exists in the admin dashboard — that is the backbone. **Every decision must be logged (audit_log)** for liability defence.

### 2.6 Police verification & background checks
- **Police verification:** in India this is done via the **local police station / Passport Seva-style character verification**, or through **BGV agencies** that run court-record and criminal-database checks (e.g. IDfy, AuthBridge). Practical approach: **mandate a BGV vendor "criminal + court record" check for every caregiver**, and additionally require a **police-issued character certificate** for anyone doing **live-in / overnight** care.
- **Background checks (full):** identity, address, criminal/court records, employment history, reference calls, and (for nurses) registration validity with the **State Nursing Council**.
- **Re-verification:** re-run BGV **annually** and on any serious complaint. Trust is perishable.

### 2.7 Interviews — approve/reject
- **Structured video interview** with a scoring rubric: empathy & communication, elder-care scenario handling (e.g. "elder refuses medicine," "elder falls"), language fit (Hindi/Telugu/English as needed), reliability signals, red-flag screening.
- **Practical/skills check** for clinical tasks (BP, glucose, mobility support, medication administration) — either a demo or a certificate.
- **Rejection reasons are logged and standardized** (fairness + audit). Waitlist borderline candidates for training.

### 2.8 Training
- **Baseline onboarding module** (mandatory before first job): SETU code of conduct, elder dignity & consent, SOS protocol, app usage, hygiene, boundaries, data privacy, incident reporting.
- **Skill top-ups:** dementia care, fall prevention, medication management, palliative basics — partner with HSSC / a nursing college for certification.
- **Continuous:** micro-lessons in-app; rating-triggered retraining. Tie **badges/tiers** to training completion (unlocks higher-paying jobs) — training becomes a carrot, not a cost.

### 2.9 Availability, ratings, reliability
- **Availability:** caregivers set availability windows + service radius (already modeled). Use it for dispatch/matching.
- **Ratings/reviews:** family rates each visit (stars + tags + optional text). Show **aggregate rating to families, anonymized reviews to the caregiver** (already designed this way — good). Weight recent visits higher.
- **Reliability score (internal):** combine on-time %, no-show %, completion %, rating, and dispute rate into a single dispatch-priority score. High reliability → more/better jobs. This is your quality flywheel.

### 2.10 Cancellations, lateness, no-shows
Codify an **SLA + penalty/backup matrix** (make it explicit in the caregiver contract and app):

| Event | Detection | Immediate action | Consequence |
|---|---|---|---|
| Caregiver cancels >X hrs before | App | Auto re-dispatch to next best caregiver; notify family | Small reliability hit; free if enough notice |
| Caregiver cancels <X hrs | App | Priority re-dispatch + ops alert | Reliability penalty; repeated → suspension |
| Late (no check-in by T+15) | Geofenced OTP check-in miss | Auto-nudge caregiver; ops watch; notify family with ETA | Lateness penalty |
| **No-show** | No check-in by T+30 | **Ops scrambles backup caregiver; family notified + compensated (credit)** | Strike; 3 strikes → deactivation; payout withheld |

The OTP visit check-in + trip tracking already in the app are the detection mechanism — wire these SLA rules on top of them.

### 2.11 Disputes
- **In-app dispute flow** (already have bookings/disputes in admin). Categories: no-show, quality, safety, billing, behaviour.
- **Resolution ladder:** auto-refund/credit for clear-cut cases (no-show) → ops mediation → escalation to a trust-and-safety lead for safety/abuse.
- **Safety incidents** (alleged abuse, theft, injury) bypass the normal queue → immediate caregiver suspension pending investigation → documented + potentially reported to police. Have a written **incident-response runbook** before launch.

---

## 3. Payment module

### 3.1 How caregivers are paid & the split
- **Flow:** family pays SETU → funds held in **escrow (nodal/settlement account)** → on verified visit completion (OTP check-in/out), payout is released to the caregiver, **minus SETU commission**.
- **Split engine:** use **Razorpay Route** or **Cashfree Easy-Split** — purpose-built for marketplace split-settlement and RBI-compliant fund flow. This avoids you becoming an unlicensed money-transmitter.
- **Payout timing:** **weekly settlement** to caregivers (predictable, reduces float risk), with an optional **instant-payout (for a small fee)** as a caregiver perk. Hold a **rolling reserve** to cover refunds/chargebacks.

### 3.2 Commission
- **20% blended** standard; **15% introductory** for first 500 caregivers.
- Vary by service: lower on high-frequency low-margin visits, higher on premium/managed care. Be transparent to caregivers — hidden cuts destroy supply trust.

### 3.3 Refunds & cancellations
- **Family cancels early:** full refund/credit.
- **Family cancels late:** partial (covers caregiver's committed time).
- **Caregiver no-show:** full refund **+ goodwill credit** (SETU eats it; it's a trust investment).
- Refunds via original payment method; **credits** are cheaper for SETU and encourage retention — default to credit where the customer accepts it.

### 3.4 Gateways
- **Razorpay** (primary) or **Cashfree** — both support UPI, cards, netbanking, wallets, autopay/subscriptions, and marketplace split. UPI will be 60–70% of volume in India — make it the default, one-tap.
- **Subscriptions (digital):** **must** use **Google Play Billing** for in-app digital subscriptions per Play policy. Physical services (a caregiver visit) are billed **outside** Play via Razorpay — this distinction is critical for Play compliance (see §11).

### 3.5 Subscriptions, free plan, premium
- **Free (Basic):** profile, SOS (108-dial + family alert), medication reminders, 1 elder, limited timeline. Free tier is the trust on-ramp — keep SOS free forever; safety must never be paywalled.
- **Care+ (~₹499/mo):** full timeline, AI companion, unlimited reminders, health records, family circle, discounted visit commission.
- **Care Pro (~₹1,499/mo):** priority dispatch, teleconsults included/discounted, weekly AI wellness reports, multiple elders, priority SOS ops.
- **Managed Care (~₹4,999–15,000/mo):** dedicated care manager, scheduled recurring caregiver visits bundled, quarterly health reviews — the high-ARPU NRI product.

---

## 4. Maps & live tracking

- **Provider:** **Mappls (MapmyIndia)** primary in India — materially cheaper than Google, India-optimized geocoding, and aligned with data-localization sentiment. **Google Maps** as fallback/for regions Mappls is weaker. Abstract the maps layer so you can switch per-region.
- **Caregiver tracking:** live location **only during an active trip/visit** (from "on my way" to check-out). Update every **10–20 s while moving**, back off when stationary to save battery/cost. Uses a **foreground service + persistent notification** (Android requirement + honest to the user).
- **Elder tracking:** **not** continuous surveillance — that's a privacy and dignity red line. Location is captured **on SOS** and optionally during a caregiver visit. Continuous elder tracking, if ever offered, must be **explicit opt-in by the elder** with a always-visible indicator.
- **Permissions:** foreground + (for trip) background location, with **Play "prominent disclosure"** before the OS prompt. Precise location only when needed.
- **Privacy:** location retention minimized (e.g. purge trip breadcrumbs after N days; keep only SOS location for the incident record). Never sell/secondary-use location.
- **Cost at scale:** tracking cost scales with **active trips**, not total users — this keeps it bounded. Cache map tiles; use SDK (not per-request REST) for live tracking.
- **Connectivity loss:** **queue-and-forward** — the app buffers location + check-in events locally and syncs when back online; SOS falls back to a **direct 108/112 dial + SMS to emergency contacts** (works without data). Design offline-first for the safety-critical paths.

---

## 5. SOS module — the legal & reliability crown jewel

**Golden rule (already correctly implemented): 108/112 first.** SETU never *replaces* emergency services; it **augments** them. Getting this wrong is existential legal liability.

### 5.1 How SOS works
1. Elder/family triggers SOS.
2. App **immediately surfaces the 108/112 dialer** (the mandatory primary action; showing this screen is itself the legal evidence that emergency services were prioritized).
3. **In parallel:** notify emergency contacts (push + SMS + call), share live location, alert SETU ops, and dispatch the **nearest verified caregiver** if one is nearby.
4. Escalation ladder if contacts don't respond: contact 1 → contact 2 → SETU ops on-call → (optionally) a partnered ambulance aggregator.
5. **Incident report** auto-generated (timeline of who was notified when, location, actions) — for the family and for liability defence.

### 5.2 Ambulance integration
- **Do not become an ambulance provider** (heavy regulation, liability, ops).
- **Integrate/partner** with private ambulance aggregators (e.g. StanPlus/RED.Health, Ziqitza, or local networks) as a **secondary** option after 108. Present them as "additional options," never as the primary emergency response.

### 5.3 Legal implications
- **Explicit disclaimer + consent:** SETU is a *coordination and notification tool*, not an emergency medical service; response times are not guaranteed; users must call 108/112 for medical emergencies. Surface this at onboarding and near the SOS button.
- **SLA honesty:** never advertise a guaranteed emergency response time you can't uphold — that's both a legal and a trust bomb.
- **Abuse handling:** rate-limit + confirm accidental triggers; track repeat false alarms; a **practice/drill mode** (already in the app) trains elders without firing real alerts — keep it.

---

## 6. Doctor consultation module

### 6.1 Source & model
- **Partner model only.** Onboard **NMC-registered Registered Medical Practitioners (RMPs)**, teleconsult platforms, or hospital tie-ups. No self-declared doctors, ever.

### 6.2 Verification
- Verify **NMC / State Medical Council registration number** against the NMC/IMR registry.
- Verify **degree (MBBS/MD/specialist), ID, and registration validity**; re-verify periodically.
- For specialists, verify the specialty registration.

### 6.3 Consultation, prescriptions, uploads — under Telemedicine Practice Guidelines 2020
- Teleconsults are legal in India under the **Telemedicine Practice Guidelines 2020** (part of the IMC/NMC framework). Follow them precisely:
  - RMP must exercise professional judgement; identity of patient and doctor verified.
  - **Prescriptions** issued digitally with the RMP's signature/registration; certain drug schedules (e.g. **List O/A/B/C** distinctions, and prohibited/restricted lists — notably narcotics and Schedule X) have limits on tele-prescription. Encode these limits.
  - **e-prescriptions** stored securely, shareable to the family/pharmacy with consent.
- **Prescription uploads** (external): store **encrypted**, access-controlled, consent-gated — treat as sensitive health data (see §7).
- **Video** via Agora (existing). Record consultations **only** with explicit consent of both parties, and store per health-data rules.

---

## 7. Medical records module

- **Storage:** encrypted at rest in **ap-south-1 (Mumbai)** (data localization + latency). Supabase/Postgres + object storage for documents; **client-uploaded files encrypted**; signed, expiring URLs for access.
- **Encryption:** TLS in transit; AES-256 at rest; consider **field-level encryption** for the most sensitive fields.
- **Access control:** **consent-gated RLS is already the architecture** — this is SETU's biggest compliance asset. A family member sees only what the elder (or coordinator) consented to; a caregiver mid-visit sees only the emergency subset; doctors see only what's shared for the consult. Keep this model sacrosanct.
- **Laws:** **DPDP Act 2023** (consent, purpose limitation, data-principal rights, breach notification to the Data Protection Board), plus health-data sensitivity norms and the spirit of the (now-superseded) SPDI rules. If you ever touch other markets: **HIPAA** (US), **GDPR** (EU) — but build DPDP-first.
- **Sharing:** always consent-scoped, time-boxed where possible, revocable, and logged (audit trail already present).

---

## 8. AI companion module

- **Model:** a frontier LLM (Claude / GPT-class) behind a **strict system prompt + guardrail layer**. The app already has an AI guardrail Edge Function — that is the right pattern; harden it.
- **Scope:** companionship, reminders, routine, gentle wellness nudges, and **triage-to-human** ("this sounds like something to discuss with your doctor — shall I book a teleconsult / alert your family?"). 
- **Hard limits — the AI must NEVER:** diagnose, prescribe, interpret labs/vitals as medical fact, give dosage advice, or discourage seeking real care. All health-adjacent outputs carry a **disclaimer** and an **escalation path to a human/doctor/SOS**.
- **Conversation storage:** store **only with consent**, encrypted, for continuity + safety review; allow the user to delete. Be explicit in the privacy notice that conversations may be processed by a third-party model provider (and choose a provider with a no-training-on-your-data / zero-retention API tier).
- **Safety:** self-harm / crisis detection → surface helplines + notify family/ops (with consent framing). Test adversarially before launch.

---

## 9. Family management module

- **Invitations:** existing family member (or the elder) invites by email/phone; invitee accepts → linked with a **role**. (Already implemented.)
- **Permissions / access levels:** granular, consent-gated. Suggested roles: **Coordinator** (full, manages consent — elder or elder-appointed), **Caregiver-family** (care actions), **Viewer** (read-only reports), each scoped by consent categories. The **elder's autonomy is the anchor** — the elder (or their legal guardian) controls who sees what.
- **Emergency notifications:** a defined **emergency-contact list with priority order**; SOS fans out in that order. Keep this separate from general access — someone can be an emergency contact without seeing medical records, and vice-versa.
- **Reports:** family (per permission) can view timeline + weekly AI wellness reports. Reports that fail the AI guardrail are withheld (already designed).
- **Disputes within family:** consent conflicts (e.g. estranged sibling) resolve in favour of **the elder's stated preference / the legal guardian**; provide an ops escalation for contested guardianship. Document everything.

---

## 10. Legal & compliance (India-first)

| Area | What's required | Action |
|---|---|---|
| **Privacy Policy** | DPDP-compliant notice: what data, why, legal basis (consent), retention, rights, grievance officer, third parties (Agora, LLM provider, payment, maps, BGV). | Draft + legal review; already have DPDP-aware drafts in `docs/legal`. |
| **Terms & Conditions** | Marketplace T&Cs: SETU is an intermediary/coordination platform; service performed by independent caregivers/RMPs; liability limits; SOS disclaimer; no medical-service guarantee. | Lawyer-reviewed before launch. |
| **DPDP Act 2023** | Consent architecture, data-principal rights (access/correction/erasure), breach notification, **Consent Manager** readiness, appoint a **grievance/data-protection officer**, minors/guardianship handling. | Consent + RLS already built; add DPO + breach runbook. |
| **Consent** | Explicit, granular, revocable, logged. Elder consent for data sharing; guardian consent where capacity is impaired. | Already RLS-gated; add capacity/guardianship flow. |
| **Medical disclaimer** | AI is not medical advice; teleconsult is by RMPs under Telemedicine Guidelines; SETU doesn't practice medicine. | Surface at onboarding + relevant screens. |
| **Telemedicine** | Telemedicine Practice Guidelines 2020; NMC registration checks; prescription rules. | Encode in doctor module. |
| **Payments** | RBI payment-aggregator norms — **use a licensed PA (Razorpay/Cashfree)**; don't hold funds yourself; GST registration + invoicing; TDS on caregiver payouts as applicable. | Use PA + CA for tax setup. |
| **Play Store** | Health/medical policy, subscriptions via Play Billing, background-location prominent disclosure + demo video, data-safety form, sensitive-permissions justification. | See §11. |
| **Emergency services** | No guaranteed response; 108/112-first; disclaimers; abuse handling. | Already 108-first. |
| **Labour** | Contractor agreements; avoid deemed employment; gig-welfare/insurance contributions; POSH readiness as you grow. | Clean contractor contracts. |
| **Insurance** | **Professional indemnity + public liability + caregiver accident cover + cyber-insurance.** Non-negotiable before scaling. | Buy before Phase 2. |
| **Corporate** | Entity (Pvt Ltd), founder agreements, IP assignment, cap table hygiene. | Standard incorporation. |

---

## 11. Play Store perspective

- **Subscriptions:** in-app **digital** subscriptions **must** use **Google Play Billing** (Play takes its cut). **Physical/real-world services** (caregiver visits, teleconsults performed by humans) are billed **outside Play** via Razorpay — this is explicitly allowed and must be architected as two separate flows. Getting this wrong = app removal.
- **Background location:** requires **prominent in-app disclosure before the system prompt**, a data-safety declaration, and often a **demo video** in the Play Console review. Only request it for the caregiver-trip use case; justify clearly.
- **Health app policy:** accurate claims only; no unverified medical claims; clear that teleconsults are by licensed RMPs; medical disclaimers.
- **Data safety form:** declare every data type (location, health, contacts, financial), sharing, and security. Must match the privacy policy exactly.
- **Sensitive permissions:** location, camera/mic (video), notifications, phone (SOS dial) — each needs justification.
- **Foreground service** type declarations (location) per recent Android requirements.
- **Account deletion:** Play requires an in-app + web **account-deletion** path (already have erasure flow — expose it clearly).

---

## 12. Security perspective

| Layer | Recommendation |
|---|---|
| **Authentication** | Supabase Auth (email/OTP already). Add **phone-OTP as primary for elders** (easier than passwords). |
| **Biometric login** | Device biometric (fingerprint/face) to unlock the app + re-auth for sensitive actions (viewing records, payments). Store nothing biometric server-side. |
| **Encryption** | TLS 1.2+ in transit; AES-256 at rest; field-level for the most sensitive health fields; encrypted document storage with signed expiring URLs. |
| **Medical data protection** | Consent-gated **RLS** (the core control) + least-privilege + audit logging on every read/write of sensitive data (already instrumented). |
| **RBAC** | Roles (elder, family-coordinator, family-viewer, caregiver, doctor, admin/ops) enforced **server-side via RLS**, never trusting the client. |
| **Session management** | Short-lived access tokens + refresh; re-auth for sensitive ops; remote logout / revoke on lost device; session listing. |
| **API security** | All privileged logic in Edge Functions (already the pattern); input validation; rate limiting; secrets in vault; no service-role key on client; WAF/abuse protection at scale. |
| **Ops security** | Admin dashboard behind SSO + 2FA; audit every admin action (done); background-verify ops staff who see sensitive data. |
| **Incident response** | Documented breach runbook + DPDP breach-notification timeline; pen-test before Series-A scale. |

---

## 13. Scalability & cost — by user tier

Assumptions: costs scale with **active usage** (visits, calls, SOS, AI turns), not raw registered users. "Active %" and ARPU drive the real numbers. Figures are **order-of-magnitude planning estimates** to validate unit economics, not quotes.

| Dimension | 100 | 1,000 | 10,000 | 100,000 | 1,000,000 |
|---|---|---|---|---|---|
| **DB / backend** | Supabase Free/Pro | Supabase Pro | Supabase Team + read replicas | Dedicated Postgres (managed), replicas, PgBouncer | Sharded/partitioned Postgres, caching (Redis), queue infra |
| **Cloud** | Single region (Mumbai) | Same + CDN | Autoscaling Edge Functions | Multi-AZ, load-balanced | Multi-region read, DR |
| **Storage (docs/records)** | GBs | 10s GB | 100s GB | TBs | 10s TB, lifecycle tiering |
| **Video (Agora)** | negligible | low | scales with consult minutes | significant — meter & bundle into paid tiers | major line item — negotiate committed-use pricing |
| **Maps (Mappls)** | negligible | low | scales with active trips | moderate | negotiate enterprise contract; cache aggressively |
| **Notifications** | FCM push = free; SMS pennies each | low | SMS/WhatsApp costs grow — prefer push | route via cheapest channel; WhatsApp for critical | bulk SMS/WhatsApp contracts |
| **AI (LLM)** | trivial | low | scales with companion usage — cache, cap free-tier turns | meter per tier; use smaller models for routine turns | committed spend; hybrid small+large models |
| **Payments (PA fees)** | ~2% of GMV (UPI cheaper) | same | same | negotiate lower MDR | enterprise MDR |

**Scaling principles:**
1. **Meter the expensive, safety-optional things** (video minutes, AI turns) into paid tiers; keep the cheap safety things (SOS dial, push alerts) free.
2. **Push > SMS > WhatsApp > voice** on cost — default to the cheapest channel that works; reserve SMS/voice for safety-critical.
3. **Location/video cost scales with active sessions, not users** — this keeps the model sane at 1M registered.
4. **Read replicas + caching** before sharding; don't pre-optimize.
5. **Data residency**: stay in Mumbai region; only add regions when you enter new geographies.

---

## 14. Real-world operations — risk register & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Caregiver fraud / theft / abuse** | Med | Severe | BGV + police check + interview; live-visit OTP + tracking; insurance; instant-suspension incident runbook; family ratings; audit trail. |
| **Fake doctor registration** | Med | Severe | NMC registry verification; no self-declared doctors; periodic re-verification; partner via hospitals. |
| **Payment failure / double-charge** | Med | Med | Idempotent payment ops; PA retries; reconciliation job; support SLA; auto-refund logic. |
| **Elder safety event (fall/medical)** | Med | Severe | 108-first SOS; medication reminders; caregiver visits; emergency profile auto-shared on SOS; drill mode. |
| **SOS failure (no data/no response)** | Low | Catastrophic | Offline direct-dial 108/112 + SMS fallback; escalation ladder; ops on-call; never sole-dependency on internet. |
| **Maps/tracking outage** | Low | Med | Provider fallback (Mappls↔Google); cached last-known location; degrade gracefully. |
| **Subscription/billing disputes** | Med | Low | Clear T&Cs; Play-compliant billing; easy cancel; prorated refunds; transparent invoices. |
| **Family disputes / contested guardianship** | Med | Med | Elder-preference-anchored consent; ops escalation; documented decisions; legal-guardian override path. |
| **Privacy breach** | Low | Catastrophic | Encryption, RLS, least-privilege, audit, pen-tests, cyber-insurance, DPDP breach runbook. |
| **Lost/stolen device** | Med | Med | Biometric lock; remote logout; short sessions; re-auth for sensitive actions. |
| **Account compromise** | Low | High | OTP/2FA, anomaly detection, session revoke, re-auth on sensitive ops. |
| **Emergency-service abuse / false alarms** | Med | Med | Confirm/rate-limit triggers; drill mode; repeat-offender tracking. |
| **Caregiver supply shortage** | High | High | Agency partnerships for liquidity; referral bonuses; density-first geo strategy; surge incentives. |
| **Legal liability (medical outcome)** | Med | Severe | Intermediary positioning; disclaimers; RMP-performed care; indemnity insurance; never "practice medicine." |
| **Regulatory shift (gig/health/data)** | Med | High | Clean contracts; compliance buffer budget; legal counsel on retainer; DPDP-first architecture. |
| **Reputational (one viral bad incident)** | Med | Severe | Trust-and-safety ops, fast transparent response, insurance-backed remediation, PR runbook. |

---

## 15. Financial perspective (illustrative unit economics)

*Numbers are planning placeholders to validate the model — refine with real market data in the launch city.*

- **Revenue lines:** (a) subscription MRR, (b) 20% service commission on GMV, (c) teleconsult margin, (d) premium/managed-care contracts, (e) future B2B2C (corporate wellness, insurer tie-ups).
- **Illustrative per-active-family economics (Care+):** subscription ₹499/mo + ~₹200–600/mo commission on visits → **blended ARPU ≈ ₹700–1,100/mo**. Managed-care families are multiples higher.
- **Variable cost per active family:** payment fees (~2% GMV) + AI/video/maps/notifications (small, metered) + support allocation. Keep **contribution margin positive per active family from Day 1**; subscriptions should cover fixed platform cost.
- **CAC:** NRI-targeted digital + referral. Target **LTV:CAC ≥ 3:1** within 12–18 months; referral density is the cheat code.
- **Burn drivers:** trust-and-safety ops headcount, verification/BGV cost per caregiver, insurance, and city-launch subsidies. Model these explicitly — they're the real cost, not servers.
- **Path to profitability:** subscriptions (recurring, high-margin) fund fixed cost; commission funds growth; managed-care + B2B2C drive ARPU expansion.

---

## 16. Third-party services shortlist

| Need | Recommended | Alt |
|---|---|---|
| Backend/DB/Auth | **Supabase (Mumbai)** | AWS RDS + Cognito |
| Payments + split | **Razorpay Route** | Cashfree Easy-Split |
| Subscriptions (digital) | **Google Play Billing** | — (mandatory) |
| Video consults | **Agora** | 100ms, Zoom SDK |
| Maps/tracking | **Mappls (MapmyIndia)** | Google Maps |
| KYC / background verification | **IDfy / AuthBridge / SpringVerify** | — |
| Identity docs | **DigiLocker / offline Aadhaar eKYC** | — |
| SMS/OTP/WhatsApp | **MSG91 / Gupshup** | Twilio (pricier) |
| Push | **FCM** (free) | — |
| LLM (AI companion) | **Anthropic Claude / OpenAI** (zero-retention tier) | — |
| Ambulance (secondary) | **StanPlus/RED.Health, Ziqitza** | local networks |
| Error/monitoring | Sentry + uptime/APM | — |
| Insurance | Professional indemnity + public liability + cyber + caregiver accident | — |

---

## 17. Startup, roadmap & recommendations

**Phase 0 — Pre-launch (0–2 months):** legal entity + T&Cs/privacy (lawyer-reviewed); insurance; PA + KYC/BGV contracts; sign 3–4 caregiver agencies + onboard first 20–30 direct caregivers; ops runbooks (verification, SOS, incident, dispute); DPO + breach process; Play compliance pass.

**Phase 1 — Beachhead (2–6 months):** launch in one pincode cluster; NRI-targeted acquisition; obsess over the first 100 families and the visit-completion loop; measure no-show %, SOS reliability, NPS. Fix the loop before spending on growth.

**Phase 2 — City depth (6–12 months):** density in launch city → adjacent clusters; referral engine; managed-care product for NRIs; second city only after the first is a repeatable playbook. Raise seed on the proven loop.

**Phase 3 — Multi-city (12–24 months):** replicate the playbook city-by-city; build the salaried "SETU Elite" caregiver cadre for premium; B2B2C (corporate eldercare benefits, insurer partnerships); Series A.

**Phase 4 — Global (24 months+):** diaspora corridors (Gulf/US/UK ↔ India first), then localize (regulation, payments, emergency numbers, language) per market. **DPDP-first architecture makes GDPR/HIPAA adaptation cheaper.**

**Founder watch-list:** (1) supply liquidity in the launch city, (2) SOS reliability, (3) one bad safety incident handled badly can end the company — over-invest in trust-and-safety ops and insurance early.

---

## 18. Product improvement suggestions (pre-scale)

1. **Caregiver reliability score → dispatch priority** (make quality the flywheel).
2. **Automated no-show backup dispatch** wired onto the existing OTP check-in.
3. **Guardianship / capacity flow** for consent when the elder can't self-consent.
4. **Offline-first SOS + queue-and-forward** for connectivity gaps.
5. **Care-manager console** for the managed-care tier (human-in-the-loop premium).
6. **Insurer/corporate B2B2C dashboard** (future revenue line).
7. **Vernacular voice-first** for elders (Telugu/Hindi/Tamil…) — accessibility *is* the market.
8. **Medication-adherence analytics** feeding the AI wellness report (already have the data).
9. **Zero-retention LLM tier** + on-device redaction for the AI companion.
10. **Trust page**: public verification standards, insurance, SOS SLA — conversion lever.

---

*End of plan. This is a living document — revisit after the first 100 families; real operational data will overturn several assumptions here, and that's the point.*
