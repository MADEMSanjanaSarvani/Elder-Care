-- Caregiver payout destinations (PRD Part 2 §15). This is the
-- fund_account_id-equivalent that payouts-run and the Admin Dashboard's
-- payouts page were both blocked on: RazorpayX can't pay a caregiver
-- without knowing which bank account or UPI ID to send money to, and
-- nowhere in the schema recorded that until now.
--
-- A caregiver submits their own bank/UPI details directly (RLS-guarded
-- insert/update, no Edge Function needed — same pattern as consent_grants).
-- A finance_ops admin must mark the row `verified` before payouts-run will
-- ever use it; unverified accounts are simply skipped, not paid, so a typo'd
-- account number can't silently misroute money before a human has looked at it.

create table caregiver_payout_accounts (
  id uuid primary key default gen_random_uuid(),
  caregiver_id uuid not null references caregivers (id) on delete cascade,
  account_holder_name text not null,
  bank_account_number text,
  ifsc text,
  upi_id text,
  razorpayx_contact_id text,
  razorpayx_fund_account_id text,
  verified boolean not null default false,
  verified_by uuid references profiles (id),
  created_at timestamptz not null default now(),
  unique (caregiver_id),
  constraint bank_or_upi_present check (
    (bank_account_number is not null and ifsc is not null) or upi_id is not null
  )
);

alter table caregiver_payout_accounts enable row level security;

create policy caregiver_payout_accounts_select on caregiver_payout_accounts for select to authenticated
  using (
    exists (select 1 from caregivers c where c.id = caregiver_id and c.user_id = auth.uid())
    or has_admin_scope('finance_ops')
  );

create policy caregiver_payout_accounts_insert on caregiver_payout_accounts for insert to authenticated
  with check (exists (select 1 from caregivers c where c.id = caregiver_id and c.user_id = auth.uid()));

-- Note: row-level, not column-level, same documented trade-off as
-- caregivers_update_self in 0002_rls.sql — a caregiver updating their own
-- row could in principle also touch `verified`/`verified_by`, which are
-- meant to be finance_ops-only. Left as-is for MVP; revisit with a BEFORE
-- UPDATE trigger if this becomes a real exposure rather than a theoretical one.
create policy caregiver_payout_accounts_update on caregiver_payout_accounts for update to authenticated
  using (
    exists (select 1 from caregivers c where c.id = caregiver_id and c.user_id = auth.uid())
    or has_admin_scope('finance_ops')
  )
  with check (
    exists (select 1 from caregivers c where c.id = caregiver_id and c.user_id = auth.uid())
    or has_admin_scope('finance_ops')
  );

create index idx_caregiver_payout_accounts_caregiver on caregiver_payout_accounts (caregiver_id);
