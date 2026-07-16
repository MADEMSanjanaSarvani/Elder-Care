-- Batch 6 database layer: Care Plans & Subscription Management, Managed
-- Elder Care Services, Care Analytics Dashboard
-- (docs/prd/09-prd-part9-business-layer.html).
--
-- The single most important boundary in this batch: recurring
-- subscription billing lives ENTIRELY in new, parallel tables
-- (care_plan_charges), never in `payments`. `payments`,
-- payments-create-order, and payments-webhook are not touched at all —
-- the merchant-of-record per-visit flow keeps its exact meaning. The one
-- existing-Edge-Function touch (a coordinator authorization clause in
-- bookings-create) is application code, handled in that function.

-- ---------------------------------------------------------------------
-- Module 22's table + helper come FIRST, because Module 21's subscription
-- policies below reference the coordinator authority check.
-- ---------------------------------------------------------------------

create table care_coordinator_assignments (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  coordinator_profile_id uuid not null references profiles (id),
  assigned_at timestamptz not null default now(),
  active boolean not null default true
);

-- One ACTIVE coordinator per elder (MVP) — partial unique index, so a
-- past/deactivated assignment doesn't block a new one.
create unique index idx_one_active_coordinator_per_elder
  on care_coordinator_assignments (elder_id) where active;

alter table care_coordinator_assignments enable row level security;
-- A coordinator sees their own assignments; super_admin has full access.
create policy care_coordinator_assignments_select on care_coordinator_assignments for select to authenticated
  using (coordinator_profile_id = auth.uid() or has_admin_scope('super_admin'));
create policy care_coordinator_assignments_write on care_coordinator_assignments for all to authenticated
  using (has_admin_scope('super_admin')) with check (has_admin_scope('super_admin'));

-- The coordinator authority check reused by subscription RLS and by
-- bookings-create's additive authorization clause. Security definer so it
-- can read the assignment table regardless of the caller's own policies —
-- same pattern as is_linked_family / is_assigned_caregiver.
--
-- Deliberately narrow: this grants OPERATIONAL authority (scheduling,
-- subscriptions) only. It is NOT referenced by any consent-gated read
-- policy (health notes, medications, etc.) — a coordinator still needs
-- the same has_consent() grant as anyone else to read that data. That
-- boundary is the single most important design decision in Module 22.
--
-- Reasoned deviation from the PRD's literal framing: the PRD describes the
-- coordinator via has_admin_scope('care_coordinator') and an additive
-- admin_scope value. But is_admin() in this schema is role-based
-- (role = 'admin') and platform-wide — so a coordinator modeled as a
-- role='admin' user would read EVERY elder's health notes everywhere, the
-- exact over-grant this boundary exists to prevent. So coordinator
-- authority is keyed on the per-elder assignment table (this function),
-- and a coordinator is NOT a role='admin' user. The care_coordinator
-- admin_scope value (0018) still exists for admin-dashboard identification
-- of coordinator staff, but confers no is_admin() power on its own.
create or replace function is_care_coordinator_for(target_elder_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from care_coordinator_assignments
    where elder_id = target_elder_id
      and coordinator_profile_id = auth.uid()
      and active
  );
$$;

-- ---------------------------------------------------------------------
-- Module 21: Care Plans & Subscription Management
-- ---------------------------------------------------------------------

create table care_plans (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions (id),
  code text not null,
  name text not null,
  description text,
  monthly_price numeric not null,
  currency text not null default 'INR',
  active boolean not null default true,
  unique (region_id, code)
);

alter table care_plans enable row level security;
-- Catalog data, same visibility shape as service_catalog: readable by any
-- authenticated user, writable only by admins.
create policy care_plans_select on care_plans for select to authenticated using (true);
create policy care_plans_write on care_plans for all to authenticated
  using (is_admin()) with check (is_admin());

create table care_plan_allocations (
  id uuid primary key default gen_random_uuid(),
  care_plan_id uuid not null references care_plans (id) on delete cascade,
  service_id uuid not null references service_catalog (id),
  visits_per_period int not null,
  period text not null check (period in ('week', 'month'))
);

alter table care_plan_allocations enable row level security;
create policy care_plan_allocations_select on care_plan_allocations for select to authenticated using (true);
create policy care_plan_allocations_write on care_plan_allocations for all to authenticated
  using (is_admin()) with check (is_admin());

create type subscription_status as enum ('active', 'paused', 'cancelled');

create table elder_care_plan_subscriptions (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  care_plan_id uuid not null references care_plans (id),
  status subscription_status not null default 'active',
  started_at timestamptz not null default now(),
  paused_until date,
  cancelled_at timestamptz,
  subscribed_by uuid not null references profiles (id)
);

alter table elder_care_plan_subscriptions enable row level security;

-- Assignment CRUD scoped to the elder, consented family, admin, or the
-- assigned care coordinator (a coordinator's authority is operational —
-- scheduling and subscriptions — see is_care_coordinator_for below).
create policy elder_care_plan_subscriptions_select on elder_care_plan_subscriptions for select to authenticated
  using (
    is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin()
    or is_care_coordinator_for(elder_id)
  );
create policy elder_care_plan_subscriptions_insert on elder_care_plan_subscriptions for insert to authenticated
  with check (
    subscribed_by = auth.uid()
    and (is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin() or is_care_coordinator_for(elder_id))
  );
create policy elder_care_plan_subscriptions_update on elder_care_plan_subscriptions for update to authenticated
  using (
    is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin() or is_care_coordinator_for(elder_id)
  )
  with check (
    is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin() or is_care_coordinator_for(elder_id)
  );

create type care_plan_charge_status as enum ('pending', 'paid', 'failed');

create table care_plan_charges (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references elder_care_plan_subscriptions (id) on delete cascade,
  period_start date not null,
  period_end date not null,
  amount numeric not null,
  currency text not null default 'INR',
  -- Razorpay Subscriptions/recurring-charge reference — a DIFFERENT
  -- Razorpay product surface than the Orders API payments-create-order
  -- uses. Deliberately not `payments.razorpay_*`; this is not a payments row.
  razorpay_subscription_charge_ref text,
  status care_plan_charge_status not null default 'pending',
  created_at timestamptz not null default now(),
  unique (subscription_id, period_start)
);

alter table care_plan_charges enable row level security;
-- Billing history is billing-consent-gated for family, same as payments'
-- family visibility. Written only by the billing-run Edge Function.
create policy care_plan_charges_select on care_plan_charges for select to authenticated
  using (
    is_admin()
    or exists (
      select 1 from elder_care_plan_subscriptions s
      where s.id = care_plan_charges.subscription_id
        and (
          is_elder_self(s.elder_id)
          or (is_linked_family(s.elder_id) and has_consent(s.elder_id, auth.uid(), 'billing'))
        )
    )
  );

-- ---------------------------------------------------------------------
-- Module 23: Care Analytics Dashboard
--
-- Materialized views refreshed on a schedule, NOT live aggregate queries
-- against transactional tables (which would compete with real traffic).
-- Aggregate/statistical only — no PII, no health content, ever (matching
-- the existing PostHog principle). Access is admin-only, enforced by
-- wrapper views with an is_admin() predicate: a Postgres materialized
-- view cannot carry RLS itself, so each matview is read through a plain
-- view gated on is_admin(), granted to `authenticated` — a non-admin
-- selects zero rows. This is care-OPERATION analytics (how the operation
-- performs), deliberately distinct from PostHog's product analytics (how
-- families use the app).
-- ---------------------------------------------------------------------

create materialized view mv_booking_volume_daily as
  select date_trunc('day', created_at)::date as day, region_id, status, count(*) as bookings
  from bookings group by 1, 2, 3;

create materialized view mv_caregiver_utilization as
  select c.id as caregiver_id, c.region_id,
    count(b.id) filter (where b.status = 'completed') as completed_bookings,
    count(b.id) as total_bookings
  from caregivers c left join bookings b on b.caregiver_id = c.id
  where c.active group by c.id, c.region_id;

create materialized view mv_rating_trends as
  select date_trunc('month', created_at)::date as month,
    avg(stars)::numeric(3,2) as average_stars, count(*) as rating_count
  from caregiver_ratings group by 1;

create materialized view mv_suggestion_outcomes as
  select suggestion_type, status, count(*) as suggestions
  from care_suggestions group by 1, 2;

-- Admin-gated wrapper views (the matviews themselves are not granted to
-- authenticated). is_admin() is evaluated per-caller; non-admins get no rows.
create view analytics_booking_volume as select * from mv_booking_volume_daily where is_admin();
create view analytics_caregiver_utilization as select * from mv_caregiver_utilization where is_admin();
create view analytics_rating_trends as select * from mv_rating_trends where is_admin();
create view analytics_suggestion_outcomes as select * from mv_suggestion_outcomes where is_admin();

-- Refresh entry point (called by the analytics-refresh Edge Function on a
-- schedule). Security definer so the scheduled caller can refresh without
-- owning the matviews.
--
-- Not built: a scheduled-job-health view (reminders/check-in/payout/
-- billing sweep success rates). The PRD floats it, but there is no
-- job-run-history table anywhere in this schema to aggregate from —
-- building it honestly needs a job_runs table plus instrumentation in
-- every sweep function, which is real, named future work, not something to
-- fake from unrelated data here.
create or replace function refresh_analytics_views()
returns void
language plpgsql security definer set search_path = public as $$
begin
  refresh materialized view mv_booking_volume_daily;
  refresh materialized view mv_caregiver_utilization;
  refresh materialized view mv_rating_trends;
  refresh materialized view mv_suggestion_outcomes;
end;
$$;
