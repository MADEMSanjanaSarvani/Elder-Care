# Setu — Go-Live Checklist

The platform is fully built and the database is fully deployed (migrations
0001–0020 live, 124/124 RLS tests passing). What remains is **operational
configuration**, not code: setting the secrets each Edge Function reads, and
pointing schedulers/webhooks at the functions that expect them.

Do the steps in order. Nothing here changes application code.

---

## 0. Prerequisites

- Supabase project: `Elder-Care` (production).
- Edge Functions are deployed automatically by the GitHub Action
  (`.github/workflows/deploy-functions.yml`) on every push to the working
  branch — no manual `supabase functions deploy` needed.
- You set secrets either in the dashboard
  (**Project → Edge Functions → Manage secrets**) or with the CLI:
  ```bash
  supabase secrets set NAME=value --project-ref veumfexjpxqhxemjaaor
  ```
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are
  injected by the platform automatically — you never set those yourself.

---

## 1. Secrets to set

### 1a. AI features (optional — functions stay dormant without it)

| Secret | Used by |
|---|---|
| `OPENAI_API_KEY` | `ai-care-assistant`, `ai-visit-summary`, `ai-translate`, `ai-visit-report-generate`, `recommendations-generate` |

Until this is set, the AI functions fail closed (guardrail returns a safe
refusal) — the rest of the app is unaffected.

### 1b. Payments (Razorpay — needed to actually charge/collect)

| Secret | Used by |
|---|---|
| `RAZORPAY_KEY_ID` | `payments-create-order`, `payments-webhook` |
| `RAZORPAY_KEY_SECRET` | `payments-create-order`, `payments-webhook` |
| `RAZORPAY_WEBHOOK_SECRET` | `payments-webhook` (signature verification) |

### 1c. Payouts (RazorpayX — needed to pay caregivers)

| Secret | Used by |
|---|---|
| `RAZORPAYX_KEY_ID` | `payouts-run` |
| `RAZORPAYX_KEY_SECRET` | `payouts-run` |
| `RAZORPAYX_ACCOUNT_NUMBER` | `payouts-run` |

### 1d. Verification webhook (IDfy)

| Secret | Used by |
|---|---|
| `IDFY_WEBHOOK_SHARED_SECRET` | `verification-idfy-webhook` |

### 1e. Scheduler shared secrets (one per scheduled function)

Each scheduled function authenticates the caller with a shared secret sent
in a named header — **not** a user JWT (these functions have
`verify_jwt = false` in `config.toml`, so the Supabase gateway lets the
request through and the function checks the header itself). Generate a
strong random value for each (e.g. `openssl rand -hex 32`) and set it:

| Secret | Function | Request header the scheduler must send |
|---|---|---|
| `MEDICATIONS_SWEEP_SHARED_SECRET` | `medications-generate-doses` | `x-medications-sweep-secret` |
| `REMINDERS_SWEEP_SHARED_SECRET` | `reminders-dispatch-sweep` | `x-reminders-sweep-secret` |
| `HOSPITAL_GAP_SWEEP_SHARED_SECRET` | `hospital-stays-gap-sweep` | `x-hospital-gap-sweep-secret` |
| `CHECKINS_SWEEP_SHARED_SECRET` | `checkins-escalation-sweep` | `x-checkins-sweep-secret` |
| `ANALYTICS_REFRESH_SHARED_SECRET` | `analytics-refresh` | `x-analytics-refresh-secret` |
| `CAREPLAN_VISITS_SWEEP_SHARED_SECRET` | `care-plans-generate-visits` | `x-careplan-visits-sweep-secret` |
| `CAREPLAN_BILLING_SWEEP_SHARED_SECRET` | `care-plans-billing-run` | `x-careplan-billing-sweep-secret` |
| `PAYOUTS_RUN_SHARED_SECRET` | `payouts-run` | `x-payouts-run-secret` |
| `RECOMMENDATIONS_SWEEP_SHARED_SECRET` | `recommendations-generate` | `x-recommendations-sweep-secret` |
| `REPORTS_SWEEP_SHARED_SECRET` | `ai-visit-report-generate` | `x-reports-sweep-secret` |

---

## 2. Schedules to configure (n8n, or any cron/HTTP scheduler)

Each schedule is a single HTTP POST to the function URL with the matching
header from the table above. URL pattern:

```
POST https://veumfexjpxqhxemjaaor.functions.supabase.co/<function-name>
Header: <x-...-secret>: <the shared secret value>
```

Suggested cadences (tune to real load):

| Function | Suggested cadence | Why |
|---|---|---|
| `reminders-dispatch-sweep` | every 5–15 min | reminders must fire close to their due time |
| `checkins-escalation-sweep` | every 15–30 min | escalate a missed daily check-in promptly |
| `hospital-stays-gap-sweep` | hourly | gap-in-coverage nudges are not minute-critical |
| `medications-generate-doses` | daily (early AM, e.g. 00:30 IST) | materialises the day's dose rows ahead of reminders |
| `care-plans-generate-visits` | daily | provisions each active subscription's included visits |
| `recommendations-generate` | daily (needs `OPENAI_API_KEY`) | refresh AI suggestions once per day |
| `ai-visit-report-generate` | daily or on-demand (needs `OPENAI_API_KEY`) | draft reports for completed visits |
| `analytics-refresh` | daily (or hourly if dashboards need it fresher) | refreshes the analytics materialized views |
| `care-plans-billing-run` | monthly (1st, early AM) | records the month's plan charges |
| `payouts-run` | weekly (fixed day/time) | batches caregiver payouts |

**Ordering within a day:** run `medications-generate-doses` and
`care-plans-generate-visits` **before** the frequent `reminders-dispatch-sweep`
so the day's rows exist when reminders look for them.

**Smoke test any schedule** before trusting it — wrong secret should be
rejected, right secret should return a JSON summary:
```bash
# wrong secret -> 401 from the function itself
curl -s -X POST https://veumfexjpxqhxemjaaor.functions.supabase.co/reminders-dispatch-sweep \
  -H 'x-reminders-sweep-secret: WRONG'
# right secret -> 200 {"processed":N,...}
curl -s -X POST https://veumfexjpxqhxemjaaor.functions.supabase.co/reminders-dispatch-sweep \
  -H "x-reminders-sweep-secret: $REMINDERS_SWEEP_SHARED_SECRET"
```

---

## 3. Provider-side webhooks to register

These are called **by the provider**, not on a schedule. Register the URL in
the provider's dashboard; the function verifies the signature/secret itself.

| Provider | Register this URL | Verifies with |
|---|---|---|
| Razorpay | `.../functions/v1/payments-webhook` | `RAZORPAY_WEBHOOK_SECRET` |
| IDfy | `.../functions/v1/verification-idfy-webhook` | `IDFY_WEBHOOK_SHARED_SECRET` |

---

## 4. Final verification

- [ ] Section 1 secrets set (at minimum 1e for background jobs; 1a/1b/1c/1d as those features go live).
- [ ] Section 2 schedules created and each smoke-tested (wrong secret → 401, right secret → 200).
- [ ] Section 3 webhooks registered in the provider dashboards.
- [ ] Dose generation + visit generation run **before** the first reminder sweep of the day.
- [ ] `analytics-refresh` has run at least once so the admin analytics page shows data.

Once these are checked, the platform is fully operational: all 25 modules,
live database, background automation, and payment/verification integrations.
