# Setu — Ops Console

Internal admin dashboard implementing `docs/prd/02-prd-part2-architecture.html`
Section 16 and `docs/prd/03-prd-part3-execution.html` Section 17/18's call for
a desktop web app rather than a Flutter surface for ops staff.

## Setup

```bash
npm install
cp .env.example .env.local   # fill in real values
npm run dev
```

Auth is email/password via Supabase Auth (`profiles.role = 'admin'`),
distinct from the phone-OTP flow the consumer apps use — ops staff are
internal employees, not the elder/family/caregiver personas.

## Bootstrapping the first super_admin

There is deliberately no self-serve path to grant `admin_scopes` — the
RLS policy on that table requires already having `super_admin` to insert
into it, which is intentional (PRD Part 2 §13's pattern of no shortcuts
around a trust boundary), but it means the *first* super_admin has to be
created directly against the database, not through this app:

```sql
-- after the person has signed up / been given a Supabase Auth account:
insert into profiles (id, role, display_name) values ('<their-auth-user-id>', 'admin', 'Founding Ops');
insert into admin_scopes (profile_id, scope) values ('<their-auth-user-id>', 'super_admin');
```

## Design decisions worth knowing

- **RLS is still the enforcement layer.** Server Components and most
  Server Actions use the request-scoped Supabase client (`lib/supabase/server.ts`),
  built from the signed-in admin's own session — the same RLS policies
  from `supabase/migrations/0002_rls.sql` apply here as everywhere else.
  `lib/supabase/admin.ts` (service role) is reserved for the handful of
  actions that call a secret-holding third party (Razorpay refunds).
- **This build surfaced several missing RLS policies** that the original
  schema/RLS pass didn't anticipate an admin UI would need: `ops_admin`
  updating `caregivers.active` and `bookings.status`, and `is_admin()`
  updating `ai_interactions`. All added to `0002_rls.sql` directly rather
  than as follow-up migrations, since nothing had been deployed yet.
- **Column-level permission is coarser than the UI implies** — e.g. an
  `ops_admin` granted UPDATE on `caregivers` to deactivate one could
  technically also edit `trust_tier`, since Postgres RLS is row-level, not
  column-level. Noted inline in the migration; real separation would need
  a trigger, and wasn't worth building before real usage shows whether
  `ops_admin` and `verification_agent` end up being different people.

## Known gaps (not built, not faked)

- **Payout retries**: read-only reconciliation only. RazorpayX payouts
  need a `fund_account_id` per caregiver (their bank/UPI destination),
  which doesn't exist in the schema yet — see the payouts page.
- **Audit log has no writers.** The viewer is real; nothing populates the
  table yet.
- **No document image viewer** for `caregiver_documents` (Supabase Storage
  signed URLs aren't wired up) — the verification queue shows verification
  *status*, not the uploaded ID/certificate images themselves.
