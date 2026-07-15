-- Batch 1 database layer: Family Dashboard, Elder Care Timeline, Daily
-- Check-ins System, Family Member Management
-- (docs/prd/04-prd-part4-family-experience.html).
--
-- Every touch to an existing table here is additive and was named
-- precisely in that document's "Touches to existing modules" section:
-- one column on family_links, one column on elder_profiles. No existing
-- column, policy, or Edge Function behavior changes.

-- ---------------------------------------------------------------------
-- Elder Care Timeline (Module 2)
-- ---------------------------------------------------------------------

create table elder_timeline_events (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  event_type text not null,        -- app-level, extensible without migration (see PRD)
  category consent_category not null,
  actor_user_id uuid references profiles (id),
  related_booking_id uuid references bookings (id),
  summary text not null,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

alter table elder_timeline_events enable row level security;

-- No insert policy for `authenticated` — every row is written by an Edge
-- Function via the service-role client, same as ai_interactions.
create policy elder_timeline_events_select on elder_timeline_events for select to authenticated
  using (
    is_elder_self(elder_id)
    or has_consent(elder_id, auth.uid(), category)
    or is_admin()
    or (
      related_booking_id is not null
      and exists (
        select 1 from bookings b join caregivers c on c.id = b.caregiver_id
        where b.id = elder_timeline_events.related_booking_id and c.user_id = auth.uid()
      )
    )
  );

create index idx_elder_timeline_events_elder_time on elder_timeline_events (elder_id, occurred_at desc);

-- ---------------------------------------------------------------------
-- Daily Check-ins System (Module 3)
-- ---------------------------------------------------------------------

create table daily_checkins (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  checked_in_at timestamptz not null default now(),
  mood text,                        -- small fixed vocabulary, enforced at the application layer, not freeform
  note text,                        -- capped at the application layer; never fed to AI without the existing guardrail
  source text not null default 'elder_app'  -- 'elder_app' | 'voice_assistant'
);

alter table daily_checkins enable row level security;

create policy daily_checkins_select on daily_checkins for select to authenticated
  using (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'wellbeing_checkins') or is_admin());
-- Elder-initiated only, per the PRD's functional requirements — no family-proxy check-in for MVP.
create policy daily_checkins_insert on daily_checkins for insert to authenticated
  with check (is_elder_self(elder_id));

create index idx_daily_checkins_elder_time on daily_checkins (elder_id, checked_in_at desc);

create table checkin_schedules (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade unique,
  expected_by_time time not null default '18:00',
  timezone text not null default 'Asia/Kolkata',
  paused_until date,
  escalation_contact_family_user_id uuid references profiles (id)
);

alter table checkin_schedules enable row level security;

create policy checkin_schedules_select on checkin_schedules for select to authenticated
  using (is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin());
create policy checkin_schedules_write on checkin_schedules for all to authenticated
  using (is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin())
  with check (is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin());

create table checkin_escalations (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  date date not null,
  escalated_at timestamptz not null default now(),
  handled_by uuid references profiles (id),
  handled_at timestamptz,
  unique (elder_id, date)
);

alter table checkin_escalations enable row level security;

-- No insert policy for `authenticated` — written by the escalation sweep
-- Edge Function via the service-role client.
create policy checkin_escalations_select on checkin_escalations for select to authenticated
  using (is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin());
-- Any linked family member may mark it handled, suppressing the alert for all of them (per PRD).
create policy checkin_escalations_update on checkin_escalations for update to authenticated
  using (is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin())
  with check (is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin());

-- ---------------------------------------------------------------------
-- Family Member Management (Module 4)
-- ---------------------------------------------------------------------

alter table family_links add column coordinator boolean not null default false;

-- At most one coordinator per elder, enforced at the database level,
-- race-safe against two simultaneous "make me coordinator" taps.
create unique index idx_family_links_one_coordinator on family_links (elder_id) where coordinator = true;

-- Coordinator is a UX/notification-priority concept, never a security
-- boundary (see the PRD — stated three times there, enforced once here):
-- only the elder or an admin may ever change it, even though the existing
-- family_links_update policy already lets a family member update their
-- own row for other fields (relationship, status self-revoke, etc.).
create or replace function enforce_coordinator_change_by_elder()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.coordinator is distinct from old.coordinator then
    if not (is_elder_self(new.elder_id) or is_admin()) then
      raise exception 'Only the elder (or an admin) may change coordinator status';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_enforce_coordinator_change
  before update on family_links
  for each row execute function enforce_coordinator_change_by_elder();

alter table elder_profiles add column share_family_list boolean not null default false;

-- Additive to the existing family_links_select policy (Postgres OR's
-- multiple policies for the same command together) — a linked family
-- member may see every other active link for the same elder, but only if
-- the elder has opted in. Off by default; nothing changes for an elder who
-- never touches this setting.
create policy family_links_select_shared on family_links for select to authenticated
  using (
    exists (
      select 1 from elder_profiles ep
      where ep.id = family_links.elder_id
        and ep.share_family_list = true
        and is_linked_family(ep.id)
    )
  );
