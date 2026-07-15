-- Batch 2 database layer: Medicine Management, Medicine Refill Management,
-- Appointment Management, Smart Reminder System
-- (docs/prd/05-prd-part5-care-logistics.html).
--
-- Fully additive per that document's "Touches to existing modules"
-- section: no column, policy, or existing Edge Function from booking,
-- OTP, caregiver verification, SOS, payments, or DPDP is touched. Reuses
-- the existing medication_list and visit_history consent categories —
-- no new consent category needed for this batch.

-- ---------------------------------------------------------------------
-- Module 5: Medicine Management
-- ---------------------------------------------------------------------

create type dose_status as enum ('pending', 'taken', 'missed', 'skipped', 'cancelled');

create table medication_doses (
  id uuid primary key default gen_random_uuid(),
  medication_id uuid not null references elder_medications (id) on delete cascade,
  scheduled_at timestamptz not null,
  taken_at timestamptz,
  status dose_status not null default 'pending',
  marked_by uuid references profiles (id),
  -- Fixed vocabulary, not freeform: this value is load-bearing for RLS
  -- below, so a typo here is a security question, not just a data one.
  marked_via text check (marked_via in ('elder_self', 'family_proxy', 'caregiver_clinical', 'system_auto_missed')),
  -- Set only when marked by a caregiver — lets RLS confirm the booking
  -- is in_progress and clinical (see policy below).
  related_booking_id uuid references bookings (id),
  administered_note text,
  unique (medication_id, scheduled_at)
);

alter table medication_doses enable row level security;

-- Read: the elder, consented family, admin, or any caregiver with an
-- in-progress booking for this elder (booking-scoped, same as the
-- persona table's "booking-scoped" access for both caregiver types —
-- a caregiver needs to see the schedule before they can act on it, so
-- this can't depend on related_booking_id already being set on the row).
create policy medication_doses_select on medication_doses for select to authenticated
  using (
    exists (
      select 1 from elder_medications m
      where m.id = medication_doses.medication_id
        and (
          is_elder_self(m.elder_id)
          or has_consent(m.elder_id, auth.uid(), 'medication_list')
          or is_admin()
          or exists (
            select 1 from bookings b join caregivers c on c.id = b.caregiver_id
            where b.elder_id = m.elder_id and c.user_id = auth.uid() and b.status = 'in_progress'
          )
        )
    )
  );

-- Write: USING mirrors the SELECT policy above (broad — can this row be
-- targeted at all). WITH CHECK is where the clinical-administration claim
-- is actually enforced, restated from the PRD: "Non-clinical caregiver
-- attempts to mark administered -> blocked at RLS, not just UI."
--
-- The two branches below are deliberately mutually exclusive on
-- marked_via, not just OR'd together loosely: the first branch (elder/
-- family/admin) explicitly excludes marked_via = 'caregiver_clinical', and
-- the second (caregiver) explicitly requires it plus the full clinical
-- chain. Two OR'd branches that *don't* partition on marked_via would let
-- a consented family member — who already satisfies the general
-- eligibility branch for any marked_via value — write
-- marked_via = 'caregiver_clinical' themselves, which defeats the whole
-- point of restricting that value to real clinical caregivers.
--
-- Note: the PRD's persona table also describes a non-clinical caregiver
-- "reminded" action, but neither dose_status nor marked_via's vocabulary
-- above defines what that write looks like — left out of this migration
-- rather than inventing an unspecified value on a safety-relevant table;
-- non-clinical caregivers get read access only until that's designed.
create policy medication_doses_write on medication_doses for all to authenticated
  using (
    exists (
      select 1 from elder_medications m
      where m.id = medication_doses.medication_id
        and (
          is_elder_self(m.elder_id)
          or has_consent(m.elder_id, auth.uid(), 'medication_list')
          or is_admin()
          or exists (
            select 1 from bookings b join caregivers c on c.id = b.caregiver_id
            where b.elder_id = m.elder_id and c.user_id = auth.uid() and b.status = 'in_progress'
          )
        )
    )
  )
  with check (
    (
      marked_via is distinct from 'caregiver_clinical'
      and exists (
        select 1 from elder_medications m
        where m.id = medication_doses.medication_id
          and (is_elder_self(m.elder_id) or has_consent(m.elder_id, auth.uid(), 'medication_list') or is_admin())
      )
    )
    or (
      marked_via = 'caregiver_clinical'
      and related_booking_id is not null
      and is_assigned_caregiver(related_booking_id)
      and exists (
        select 1 from bookings b join caregivers c on c.id = b.caregiver_id
        where b.id = related_booking_id and b.status = 'in_progress' and c.caregiver_type = 'clinical'
      )
    )
  );

create index idx_medication_doses_medication_time on medication_doses (medication_id, scheduled_at);

-- ---------------------------------------------------------------------
-- Module 6: Medicine Refill Management
-- ---------------------------------------------------------------------

create table medication_stock (
  id uuid primary key default gen_random_uuid(),
  medication_id uuid not null unique references elder_medications (id) on delete cascade,
  quantity_on_hand numeric not null default 0,
  -- Fixed vocabulary, chosen so a future pharmacy-stock integration has
  -- a clean mapping target instead of freeform text needing cleanup.
  unit text not null check (unit in ('tablets', 'capsules', 'ml', 'drops', 'sachets', 'puffs', 'units')),
  refill_threshold numeric not null default 0,
  last_restocked_at timestamptz
);

alter table medication_stock enable row level security;

create policy medication_stock_select on medication_stock for select to authenticated
  using (
    exists (
      select 1 from elder_medications m
      where m.id = medication_stock.medication_id
        and (
          is_elder_self(m.elder_id)
          or has_consent(m.elder_id, auth.uid(), 'medication_list')
          or is_admin()
          or exists (
            select 1 from bookings b join caregivers c on c.id = b.caregiver_id
            where b.elder_id = m.elder_id and c.user_id = auth.uid() and b.status = 'in_progress'
          )
        )
    )
  );

-- Write includes a caregiver with an in-progress booking (per the PRD:
-- "Caregiver: Can flag low stock observed during a visit — booking-scoped
-- write"), in addition to the elder/family/admin shape used everywhere
-- else in this batch.
create policy medication_stock_write on medication_stock for all to authenticated
  using (
    exists (
      select 1 from elder_medications m
      where m.id = medication_stock.medication_id
        and (
          is_elder_self(m.elder_id)
          or has_consent(m.elder_id, auth.uid(), 'medication_list')
          or is_admin()
          or exists (
            select 1 from bookings b join caregivers c on c.id = b.caregiver_id
            where b.elder_id = m.elder_id and c.user_id = auth.uid() and b.status = 'in_progress'
          )
        )
    )
  )
  with check (
    exists (
      select 1 from elder_medications m
      where m.id = medication_stock.medication_id
        and (
          is_elder_self(m.elder_id)
          or has_consent(m.elder_id, auth.uid(), 'medication_list')
          or is_admin()
          or exists (
            select 1 from bookings b join caregivers c on c.id = b.caregiver_id
            where b.elder_id = m.elder_id and c.user_id = auth.uid() and b.status = 'in_progress'
          )
        )
    )
  );

-- Auto-decrement on every dose marked taken, regardless of which of the
-- three marking paths (elder/family/caregiver) did it — the PRD's own
-- reasoning for making this a trigger rather than three copies of
-- decrement logic in application code.
--
-- Simplification: the schema has no structured "units per dose" field
-- (elder_medications.dosage is free text), so this decrements by a flat
-- 1 unit per dose and floors at 0. Matches the batch's own non-functional
-- requirement that stock math should degrade toward an early-but-harmless
-- alert, never a false "you're fine" — flagged here, not solved with an
-- unspecified new dosage-quantity field.
create or replace function decrement_medication_stock_on_dose_taken()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'taken' and (tg_op = 'INSERT' or old.status is distinct from 'taken') then
    update medication_stock
    set quantity_on_hand = greatest(quantity_on_hand - 1, 0)
    where medication_id = new.medication_id;
  end if;
  return new;
end;
$$;

create trigger trg_decrement_medication_stock
  after insert or update on medication_doses
  for each row execute function decrement_medication_stock_on_dose_taken();

-- ---------------------------------------------------------------------
-- Module 7: Appointment Management
-- ---------------------------------------------------------------------

create type appointment_status as enum ('scheduled', 'completed', 'cancelled');

create table appointments (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  title text not null,
  location text,
  scheduled_at timestamptz not null,
  recurrence_rule text,               -- simple fixed-cadence descriptor, not full RRULE (MVP constraint, see PRD)
  related_booking_id uuid references bookings (id),
  outcome_note text,
  created_by uuid not null references profiles (id),
  status appointment_status not null default 'scheduled',
  created_at timestamptz not null default now()
);

alter table appointments enable row level security;

-- Same hybrid shape as bookings_select: the family member who created
-- this appointment sees it without needing a separate self-granted
-- consent (they created it), a *different* linked family member needs
-- visit_history consent, matching the PRD's "RLS reuses visit_history."
create policy appointments_select on appointments for select to authenticated
  using (
    is_elder_self(elder_id)
    or created_by = auth.uid()
    or (is_linked_family(elder_id) and has_consent(elder_id, auth.uid(), 'visit_history'))
    or is_admin()
    or (
      related_booking_id is not null
      and exists (
        select 1 from bookings b join caregivers c on c.id = b.caregiver_id
        where b.id = appointments.related_booking_id and c.user_id = auth.uid()
      )
    )
  );

create policy appointments_insert on appointments for insert to authenticated
  with check (created_by = auth.uid() and (is_elder_self(elder_id) or is_linked_family(elder_id)));

-- Update (including cancel-via-status, and the post-visit outcome note)
-- is kept to the elder, the creator, or admin — tighter than select,
-- so one family member can't silently edit another's tracked
-- appointment. No delete policy: cancellation is a status change, same
-- soft-delete convention used elsewhere in this schema.
create policy appointments_update on appointments for update to authenticated
  using (is_elder_self(elder_id) or created_by = auth.uid() or is_admin())
  with check (is_elder_self(elder_id) or created_by = auth.uid() or is_admin());

create index idx_appointments_elder_time on appointments (elder_id, scheduled_at);

-- The linked booking getting cancelled must never auto-cancel the
-- appointment itself (PRD §13: "the doctor visit still exists even if
-- the companion booking fell through") — enforced simply by never having
-- written a trigger that would do that, not by a rule to remember.

-- ---------------------------------------------------------------------
-- Module 8: Smart Reminder System
-- ---------------------------------------------------------------------

create type reminder_status as enum ('pending', 'sent', 'snoozed', 'dismissed', 'cancelled');

create table reminders (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  -- Deliberately not a hard FK — a real FK would require this table to
  -- know about every future module's schema at migration time, which
  -- defeats the point of a shared engine (PRD §07).
  source_type text not null,
  source_id uuid not null,
  remind_at timestamptz not null,
  recipient_scope text not null check (recipient_scope in ('elder', 'family', 'both')),
  status reminder_status not null default 'pending',
  snoozed_until timestamptz,
  created_at timestamptz not null default now()
);

-- Maps a reminder's source to the consent category it inherits — a
-- medication-dose reminder is exactly as sensitive as the medication
-- itself, an appointment reminder inherits visit_history. Returns null
-- for an unrecognized source_type, and the RLS policy below treats null
-- as "deny," not "allow" — fail-closed, consistent with the guardrail
-- philosophy used everywhere else in this platform.
create or replace function required_consent_for_source(source_type text)
returns consent_category
language sql immutable as $$
  select case source_type
    when 'medication_dose' then 'medication_list'::consent_category
    when 'medication_stock' then 'medication_list'::consent_category
    when 'appointment' then 'visit_history'::consent_category
    else null
  end;
$$;

alter table reminders enable row level security;

-- No insert policy for `authenticated` — every row is written by a
-- source module's own Edge Function via the service-role client, same
-- as elder_timeline_events and checkin_escalations.
create policy reminders_select on reminders for select to authenticated
  using (
    is_elder_self(elder_id)
    or is_admin()
    or (
      recipient_scope in ('family', 'both')
      and required_consent_for_source(source_type) is not null
      and has_consent(elder_id, auth.uid(), required_consent_for_source(source_type))
    )
  );

-- Snooze/dismiss only. Application contract, not a column-level DB
-- restriction: clients are expected to update only status/snoozed_until,
-- the same looser convention already used for checkin_escalations_update.
create policy reminders_update on reminders for update to authenticated
  using (
    is_elder_self(elder_id)
    or is_admin()
    or (
      recipient_scope in ('family', 'both')
      and required_consent_for_source(source_type) is not null
      and has_consent(elder_id, auth.uid(), required_consent_for_source(source_type))
    )
  )
  with check (
    is_elder_self(elder_id)
    or is_admin()
    or (
      recipient_scope in ('family', 'both')
      and required_consent_for_source(source_type) is not null
      and has_consent(elder_id, auth.uid(), required_consent_for_source(source_type))
    )
  );

-- Critical for sweep performance as adoption grows across modules (PRD §17).
create index idx_reminders_status_remind_at on reminders (status, remind_at);
