-- ============================================================================
-- Water, which is the one vital sign you can track without hardware
-- ----------------------------------------------------------------------------
-- The wellness design shows four metric cards: sleep duration, water intake,
-- steps and resting heart rate. Three of them need a wearable SETU does not
-- have and will not pretend to have.
--
-- Water is different. It is self-reported — somebody taps a glass — and it is
-- arguably the most useful of the four for this audience. Dehydration in older
-- adults is not a wellness nicety: it presents as sudden confusion, it drives
-- urinary infections, and it puts people on the floor. Thirst sensation
-- declines with age, so the person least likely to notice they are dehydrated
-- is exactly the person this app is for.
--
-- One row per glass rather than a running total per day. A tally can only be
-- corrected by overwriting it; discrete entries can be undone, which matters
-- because the commonest interaction here is a mis-tap by someone with unsteady
-- hands.
-- ============================================================================

create table if not exists hydration_logs (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  logged_at timestamptz not null default now(),
  -- Who tapped: the elder, or a family member/caregiver logging on their
  -- behalf. Kept because "she has drunk two glasses" means something different
  -- when it is the elder saying it and when it is a caregiver who watched.
  logged_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists hydration_logs_elder_day_idx
  on hydration_logs (elder_id, logged_at desc);

alter table hydration_logs enable row level security;

-- Same visibility as the rest of an elder's day-to-day care record: the elder
-- themselves, an actively linked family member, or an admin.
drop policy if exists hydration_logs_select on hydration_logs;
create policy hydration_logs_select on hydration_logs for select to authenticated
  using (is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin());

drop policy if exists hydration_logs_insert on hydration_logs;
create policy hydration_logs_insert on hydration_logs for insert to authenticated
  with check (is_elder_self(elder_id) or is_linked_family(elder_id));

-- Deletable so a mis-tap can be undone, and only by whoever recorded it.
drop policy if exists hydration_logs_delete on hydration_logs;
create policy hydration_logs_delete on hydration_logs for delete to authenticated
  using (logged_by = auth.uid() or is_elder_self(elder_id) or is_admin());

comment on table hydration_logs is
  'One row per glass of water. Self-reported, because it is the only one of
   the design''s four wellness metrics that needs no hardware — and the one
   that matters most for this audience, since thirst sensation declines with
   age and dehydration in older adults presents as confusion and falls.';

-- The daily target. Eight glasses is the familiar number rather than a
-- clinical one, and it is per-elder because someone on fluid restriction for
-- heart or kidney reasons must not be nudged to drink more.
alter table elder_health_profile
  add column if not exists daily_water_glasses smallint
    check (daily_water_glasses is null or daily_water_glasses between 1 and 20);

comment on column elder_health_profile.daily_water_glasses is
  'Target glasses per day. Nullable, defaulting to 8 in the UI. Per-elder and
   editable because fluid restriction is real — someone in heart failure being
   told to drink more water is the kind of nudge that does harm.';
