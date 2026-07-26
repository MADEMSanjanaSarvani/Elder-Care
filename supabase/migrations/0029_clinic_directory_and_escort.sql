-- ============================================================================
-- Turn `doctors` into a clinic directory you can browse and book against
-- ----------------------------------------------------------------------------
-- The doctors table was built for video consultations: a doctor SETU employs
-- or partners with, who dials in. The actual product is the opposite way
-- round — the elder goes TO a clinic, and a SETU caregiver escorts them.
-- That needs three things the table did not have: where the clinic is, when
-- the doctor actually sits there, and whether we can escort someone to it.
--
-- "Availability" here means published consulting hours, not live per-slot
-- booking. No Indian clinic exposes a slot API, and pretending otherwise
-- would mean showing a family a slot that does not exist. Hours plus a phone
-- number is what a real clinic can honestly offer, and it is exactly what
-- Zomato and Swiggy started with — a hand-curated directory and a phone call.
-- ============================================================================

alter table doctors
  add column if not exists clinic_name text,
  add column if not exists address text,
  add column if not exists phone text,
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  -- ISO weekday numbers: 1 = Monday … 7 = Sunday. An empty array means the
  -- consulting days are unknown, which the UI must show as "call to confirm"
  -- rather than as "closed".
  add column if not exists consult_days smallint[] not null default '{}',
  add column if not exists consult_start time,
  add column if not exists consult_end time,
  add column if not exists slot_minutes smallint not null default 30
    check (slot_minutes between 5 and 120),
  -- Whether a SETU caregiver can accompany the elder to this clinic. False
  -- for anywhere outside the service area or without step-free access.
  add column if not exists escort_available boolean not null default true,
  -- The doctor's medical-council registration, and when a human checked it
  -- against the NMC register. Null verified_at means "not checked yet", and
  -- the UI must not show a verified badge for those.
  add column if not exists registration_no text,
  add column if not exists registration_verified_at timestamptz;

comment on column doctors.consult_days is
  'ISO weekdays the doctor consults at this clinic (1=Mon..7=Sun). Empty =
   unknown, which is shown as "call to confirm", never as closed.';
comment on column doctors.escort_available is
  'Whether a SETU caregiver can take the elder to this clinic.';
comment on column doctors.registration_verified_at is
  'Set only when a human has checked registration_no against the NMC
   register. The verified badge keys off this, not off registration_no being
   non-empty — an unchecked number must never look verified.';

-- Ties an appointment to the doctor it was made with, so the caregiver
-- escorting the elder knows exactly where they are going and to whom, and
-- so the visit note lands against the right clinician.
alter table appointments
  add column if not exists doctor_id uuid references doctors (id);

create index if not exists appointments_doctor_idx
  on appointments (doctor_id, scheduled_at desc);

create index if not exists doctors_directory_idx
  on doctors (active, region_id, specialty);

-- ---------------------------------------------------------------------------
-- Consulting hours for a given day, as a set of bookable start times.
-- Returns nothing when the doctor does not sit on that weekday, and nothing
-- when the hours are unknown — the caller shows "call to confirm" in that
-- case rather than inventing a schedule.
-- ---------------------------------------------------------------------------
create or replace function doctor_slots(p_doctor_id uuid, p_day date)
returns table (slot_at timestamptz)
language plpgsql
stable
as $$
declare
  d          record;
  v_weekday  smallint := extract(isodow from p_day);
  v_cursor   timestamp;
  v_end      timestamp;
begin
  select consult_days, consult_start, consult_end, slot_minutes, active
    into d
    from doctors
   where id = p_doctor_id;

  if not found or not d.active then return; end if;
  if d.consult_start is null or d.consult_end is null then return; end if;
  if not (v_weekday = any (d.consult_days)) then return; end if;

  v_cursor := p_day + d.consult_start;
  v_end    := p_day + d.consult_end;

  while v_cursor < v_end loop
    -- Never offer a time that has already passed today.
    if v_cursor > now() then
      slot_at := v_cursor;
      return next;
    end if;
    v_cursor := v_cursor + make_interval(mins => d.slot_minutes);
  end loop;
end $$;

comment on function doctor_slots(uuid, date) is
  'Published consulting slots for a doctor on a day. These are the clinic''s
   stated hours, not live availability — no Indian clinic exposes a slot API,
   so the family still confirms by phone or SETU confirms on their behalf.';
