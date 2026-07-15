-- Batch 3 database layer: Family Notification Center, Companion Visits,
-- Hospital Companion Services, Health Records Management
-- (docs/prd/06-prd-part6-visits-and-records.html).
--
-- Only one touch to an existing module in this whole batch, and it's in
-- bookings-match (Edge Function), not here — see that function's own
-- comment for the narrowly-scoped tiebreak this migration's
-- companion_visit_preferences table makes possible.

-- ---------------------------------------------------------------------
-- Module 9: Family Notification Center
-- ---------------------------------------------------------------------

create table notification_types (
  type text primary key,
  can_disable boolean not null default true,
  default_channel text not null default 'in_app',
  description text
);

-- No RLS write policy for `authenticated` at all — this is a config
-- table maintained by migrations/seed, not user data.
alter table notification_types enable row level security;
create policy notification_types_select on notification_types for select to authenticated using (true);

insert into notification_types (type, can_disable, default_channel, description) values
  ('sos_triggered', false, 'push', 'An SOS was triggered for this elder'),
  ('sos_ops_alert', false, 'push', 'Ops-facing SOS alert'),
  ('checkin_missed_escalation', false, 'push', 'A daily check-in was missed'),
  ('family_invite_sent', true, 'in_app', 'You were invited to join as family'),
  ('reminder_medication_dose', true, 'push', 'A medication dose reminder'),
  ('reminder_appointment', true, 'push', 'An upcoming appointment reminder'),
  ('erasure_request_submitted', true, 'in_app', 'A data erasure request was filed');

create table notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  type text not null references notification_types (type),
  channel text not null default 'push',
  enabled boolean not null default true,
  unique (user_id, type)
);

alter table notification_preferences enable row level security;

create policy notification_preferences_select on notification_preferences for select to authenticated
  using (user_id = auth.uid() or is_admin());
create policy notification_preferences_write on notification_preferences for all to authenticated
  using (user_id = auth.uid() or is_admin())
  with check (user_id = auth.uid() or is_admin());

-- Must-deliver enforcement is a trigger, not a UI restriction (PRD §09) —
-- mirrors the stock-decrement trigger pattern from Batch 2: a
-- cross-cutting invariant belongs in the database, not duplicated across
-- every client that could write this row.
create or replace function enforce_must_deliver_notification_types()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.enabled = false then
    if exists (select 1 from notification_types t where t.type = new.type and t.can_disable = false) then
      raise exception 'Notification type % cannot be disabled', new.type;
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_enforce_must_deliver_notification_types
  before insert or update on notification_preferences
  for each row execute function enforce_must_deliver_notification_types();

create table user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  fcm_token text not null,
  platform text not null,
  last_seen_at timestamptz not null default now(),
  unique (user_id, fcm_token)
);

alter table user_devices enable row level security;

create policy user_devices_select on user_devices for select to authenticated
  using (user_id = auth.uid() or is_admin());
create policy user_devices_write on user_devices for all to authenticated
  using (user_id = auth.uid() or is_admin())
  with check (user_id = auth.uid() or is_admin());

-- ---------------------------------------------------------------------
-- Module 10: Companion Visits
-- ---------------------------------------------------------------------

create table companion_visit_preferences (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null unique references elder_profiles (id) on delete cascade,
  preferred_caregiver_id uuid references caregivers (id),
  interests jsonb not null default '[]'::jsonb
);

alter table companion_visit_preferences enable row level security;

create policy companion_visit_preferences_select on companion_visit_preferences for select to authenticated
  using (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'visit_history') or is_admin());
create policy companion_visit_preferences_write on companion_visit_preferences for all to authenticated
  using (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'visit_history') or is_admin())
  with check (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'visit_history') or is_admin());

create table visit_activity_logs (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references bookings (id) on delete cascade,
  activities jsonb not null default '[]'::jsonb,
  caregiver_observed_mood text,
  note text,
  created_at timestamptz not null default now()
);

alter table visit_activity_logs enable row level security;

-- Read shape matches elder_health_notes_select's elder/consent/admin
-- baseline. Write additionally allows the caregiver assigned to the
-- booking during in_progress or just-completed — same shape as
-- elder_health_notes_insert.
create policy visit_activity_logs_select on visit_activity_logs for select to authenticated
  using (
    exists (
      select 1 from bookings b
      where b.id = visit_activity_logs.booking_id
        and (is_elder_self(b.elder_id) or has_consent(b.elder_id, auth.uid(), 'visit_history') or is_admin())
    )
  );
create policy visit_activity_logs_write on visit_activity_logs for all to authenticated
  using (
    exists (
      select 1 from bookings b join caregivers c on c.id = b.caregiver_id
      where b.id = visit_activity_logs.booking_id
        and c.user_id = auth.uid()
        and b.status in ('in_progress', 'completed')
    )
  )
  with check (
    exists (
      select 1 from bookings b join caregivers c on c.id = b.caregiver_id
      where b.id = visit_activity_logs.booking_id
        and c.user_id = auth.uid()
        and b.status in ('in_progress', 'completed')
    )
  );

-- ---------------------------------------------------------------------
-- Module 11: Hospital Companion Services
-- ---------------------------------------------------------------------

create type hospital_stay_status as enum ('active', 'discharged', 'cancelled');

create table hospital_stays (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  hospital_name text not null,
  admission_at timestamptz not null default now(),
  expected_discharge_at timestamptz,
  actual_discharge_at timestamptz,
  status hospital_stay_status not null default 'active',
  created_by uuid not null references profiles (id)
);

alter table hospital_stays enable row level security;

-- Same hybrid shape as appointments_select/_insert (Batch 2): the
-- creator sees their own stay without a separate self-granted consent, a
-- different linked family member needs visit_history consent.
create policy hospital_stays_select on hospital_stays for select to authenticated
  using (
    is_elder_self(elder_id)
    or created_by = auth.uid()
    or (is_linked_family(elder_id) and has_consent(elder_id, auth.uid(), 'visit_history'))
    or is_admin()
  );
create policy hospital_stays_insert on hospital_stays for insert to authenticated
  with check (created_by = auth.uid() and (is_elder_self(elder_id) or is_linked_family(elder_id)));
create policy hospital_stays_update on hospital_stays for update to authenticated
  using (is_elder_self(elder_id) or created_by = auth.uid() or is_admin())
  with check (is_elder_self(elder_id) or created_by = auth.uid() or is_admin());

create table hospital_stay_bookings (
  hospital_stay_id uuid not null references hospital_stays (id) on delete cascade,
  booking_id uuid not null unique references bookings (id),
  shift_note text,
  primary key (hospital_stay_id, booking_id)
);

alter table hospital_stay_bookings enable row level security;

-- The cross-caregiver read check below must not query
-- hospital_stay_bookings directly from inside its own RLS policy — doing
-- so re-triggers RLS evaluation on that same query and Postgres reports
-- "infinite recursion detected in policy," a real error hit while testing
-- this locally, not a hypothetical. A security-definer function runs
-- under its owner's privileges, which — same as every other helper in
-- 0002_rls.sql (is_assigned_caregiver, caregiver_id_for, etc.) — bypasses
-- RLS on the table it reads internally, breaking the cycle.
create or replace function is_caregiver_on_hospital_stay(target_hospital_stay_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from hospital_stay_bookings hsb
    join bookings b on b.id = hsb.booking_id
    join caregivers c on c.id = b.caregiver_id
    where hsb.hospital_stay_id = target_hospital_stay_id and c.user_id = auth.uid()
  );
$$;

-- The one deliberately extended policy in this batch: a caregiver may
-- read every shift note within a stay they have any booking in, not just
-- their own — exactly what handoff continuity requires (PRD §09). Writing
-- a shift note stays scoped to the caregiver's own booking; reading is
-- what's stay-wide, since you can't write a note for a shift you didn't
-- work.
create policy hospital_stay_bookings_select on hospital_stay_bookings for select to authenticated
  using (
    exists (
      select 1 from hospital_stays hs
      where hs.id = hospital_stay_bookings.hospital_stay_id
        and (
          is_elder_self(hs.elder_id)
          or hs.created_by = auth.uid()
          or (is_linked_family(hs.elder_id) and has_consent(hs.elder_id, auth.uid(), 'visit_history'))
          or is_admin()
        )
    )
    or is_caregiver_on_hospital_stay(hospital_stay_bookings.hospital_stay_id)
  );
create policy hospital_stay_bookings_insert on hospital_stay_bookings for insert to authenticated
  with check (
    exists (
      select 1 from hospital_stays hs
      where hs.id = hospital_stay_bookings.hospital_stay_id
        and (is_elder_self(hs.elder_id) or hs.created_by = auth.uid() or is_linked_family(hs.elder_id) or is_admin())
    )
  );
create policy hospital_stay_bookings_update on hospital_stay_bookings for update to authenticated
  using (
    exists (
      select 1 from hospital_stays hs
      where hs.id = hospital_stay_bookings.hospital_stay_id
        and (is_elder_self(hs.elder_id) or hs.created_by = auth.uid() or is_admin())
    )
    or exists (
      select 1 from bookings b join caregivers c on c.id = b.caregiver_id
      where b.id = hospital_stay_bookings.booking_id and c.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from hospital_stays hs
      where hs.id = hospital_stay_bookings.hospital_stay_id
        and (is_elder_self(hs.elder_id) or hs.created_by = auth.uid() or is_admin())
    )
    or exists (
      select 1 from bookings b join caregivers c on c.id = b.caregiver_id
      where b.id = hospital_stay_bookings.booking_id and c.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------
-- Module 12: Health Records Management
--
-- Security note, stated plainly: the PRD claims emergency_medical_notes
-- and insurance_policy_number should get "the same pgsodium/pgcrypto
-- treatment PRD Part 2 §13 already applies to raw medical notes" — but no
-- such treatment exists anywhere in this codebase. elder_health_notes.note
-- has always been plain text, RLS-protected only. Real column-level
-- encryption (via Supabase Vault + pgsodium) needs a service-role-managed
-- key that a plain client-side RLS-guarded read/write can't hold without
-- defeating the point, and pgsodium isn't available in this project's
-- local Postgres+PostGIS test harness to even validate against. Building
-- a naive pgcrypto scheme with a client-visible key would be security
-- theater, not protection, so these two columns are plain text, exactly
-- as sensitive-but-unencrypted as elder_health_notes already is, with
-- real column encryption flagged as named future work against the live
-- Supabase project — not silently dropped, not faked.
-- ---------------------------------------------------------------------

create table elder_health_profile (
  elder_id uuid primary key references elder_profiles (id) on delete cascade,
  blood_type text,
  allergies jsonb not null default '[]'::jsonb,
  chronic_conditions jsonb not null default '[]'::jsonb,
  emergency_medical_notes text,
  updated_by uuid references profiles (id),
  updated_at timestamptz not null default now()
);

alter table elder_health_profile enable row level security;

-- The caregiver clause here is a direct, reasoned extension of the real
-- existing sos_events pattern — not the PRD's looser "any caregiver
-- during an active SOS" gloss. sos_events only ever grants visibility to
-- the specifically dispatched responder_caregiver_id (see
-- sos_events_select in 0002_rls.sql), so this mirrors that precisely:
-- the assigned caregiver during an in-progress booking, or the actual
-- dispatched responder on an unresolved SOS for this elder — not a
-- broader "any caregiver" rule this codebase has never actually had.
create policy elder_health_profile_select on elder_health_profile for select to authenticated
  using (
    is_elder_self(elder_id)
    or has_consent(elder_id, auth.uid(), 'health_notes')
    or is_admin()
    or exists (
      select 1 from bookings b join caregivers c on c.id = b.caregiver_id
      where b.elder_id = elder_health_profile.elder_id and c.user_id = auth.uid() and b.status = 'in_progress'
    )
    or exists (
      select 1 from sos_events s join caregivers c on c.id = s.responder_caregiver_id
      where s.elder_id = elder_health_profile.elder_id and c.user_id = auth.uid() and s.status != 'resolved'
    )
  );
create policy elder_health_profile_write on elder_health_profile for all to authenticated
  using (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'health_notes') or is_admin())
  with check (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'health_notes') or is_admin());

create or replace function touch_elder_health_profile_updated_at()
returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_touch_elder_health_profile
  before update on elder_health_profile
  for each row execute function touch_elder_health_profile_updated_at();

create table elder_administrative_profile (
  elder_id uuid primary key references elder_profiles (id) on delete cascade,
  primary_physician_name text,
  primary_physician_contact text,
  insurance_provider text,
  insurance_policy_number text,
  updated_by uuid references profiles (id),
  updated_at timestamptz not null default now()
);

alter table elder_administrative_profile enable row level security;

-- Identical shape minus the caregiver clause entirely — no caregiver
-- override, ever (PRD §07/§13).
create policy elder_administrative_profile_select on elder_administrative_profile for select to authenticated
  using (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'health_notes') or is_admin());
create policy elder_administrative_profile_write on elder_administrative_profile for all to authenticated
  using (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'health_notes') or is_admin())
  with check (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'health_notes') or is_admin());

create trigger trg_touch_elder_administrative_profile
  before update on elder_administrative_profile
  for each row execute function touch_elder_health_profile_updated_at();
