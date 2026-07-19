-- ============================================================================
-- Doctor consultations — teleconsults with SETU-empanelled doctors.
-- ----------------------------------------------------------------------------
-- A family books a video/audio/in-person consult for their elder with a
-- listed doctor; the doctor issues a prescription afterwards. Video runs on
-- Agora (channel name stored here; the RTC token is minted per-join by the
-- agora-rtc-token function so the App Certificate never reaches the client).
-- Reads follow the same consent model as the rest of the health surface.
-- ============================================================================

create type consult_mode as enum ('video', 'audio', 'in_person');
create type consult_status as enum (
  'requested', 'confirmed', 'in_progress', 'completed', 'cancelled'
);

-- The public doctor directory. Rows are curated by ops (admin-written); a
-- doctor may optionally have a login (user_id) to run their own consults.
create table doctors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles (id),
  region_id uuid references regions (id),
  display_name text not null,
  specialty text not null,
  qualification text,
  languages text[] not null default '{}',
  years_experience int,
  consult_fee numeric not null default 0,
  photo_url text,
  bio text,
  rating numeric,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index doctors_active_idx on doctors (active, specialty);

create table doctor_consultations (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  doctor_id uuid not null references doctors (id),
  requested_by uuid not null references profiles (id),
  mode consult_mode not null default 'video',
  status consult_status not null default 'requested',
  scheduled_at timestamptz not null,
  reason text,
  agora_channel text,           -- set when a video consult is booked
  fee numeric not null default 0,
  payment_status payment_status not null default 'created',
  doctor_note text,
  created_at timestamptz not null default now()
);

create index doctor_consultations_elder_idx
  on doctor_consultations (elder_id, scheduled_at desc);
create index doctor_consultations_doctor_idx
  on doctor_consultations (doctor_id, scheduled_at desc);

create table consultation_prescriptions (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid not null references doctor_consultations (id) on delete cascade,
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  doctor_id uuid not null references doctors (id),
  medicines jsonb not null default '[]'::jsonb,  -- [{name,dosage,frequency,duration,notes}]
  advice text,
  follow_up_date date,
  issued_at timestamptz not null default now()
);

create index consultation_prescriptions_elder_idx
  on consultation_prescriptions (elder_id, issued_at desc);

-- --------------------------------------------------------------------------
-- RLS
-- --------------------------------------------------------------------------
alter table doctors enable row level security;
alter table doctor_consultations enable row level security;
alter table consultation_prescriptions enable row level security;

-- The directory is public to any signed-in user; only admins curate it.
create policy doctors_select on doctors for select to authenticated using (true);
create policy doctors_admin_write on doctors for all to authenticated
  using (is_admin()) with check (is_admin());

-- A consult is visible to the elder, their linked family, the doctor running
-- it (if they have a login) and admins. Family/elder can book; writes beyond
-- that (confirming, notes) come from Edge Functions via the service role.
create policy doctor_consultations_select on doctor_consultations for select to authenticated
  using (
    is_elder_self(elder_id)
    or is_linked_family(elder_id)
    or exists (
      select 1 from doctors d
      where d.id = doctor_consultations.doctor_id and d.user_id = auth.uid()
    )
    or is_admin()
  );
create policy doctor_consultations_insert on doctor_consultations for insert to authenticated
  with check (
    requested_by = auth.uid()
    and (is_elder_self(elder_id) or is_linked_family(elder_id))
  );

-- Prescriptions are health data: gated on health_notes consent for family.
create policy consultation_prescriptions_select on consultation_prescriptions for select to authenticated
  using (
    is_elder_self(elder_id)
    or has_consent(elder_id, auth.uid(), 'health_notes')
    or exists (
      select 1 from doctors d
      where d.id = consultation_prescriptions.doctor_id and d.user_id = auth.uid()
    )
    or is_admin()
  );
-- Doctors with a login write prescriptions for their own consults; otherwise
-- the service role (Edge Function) does.
create policy consultation_prescriptions_doctor_write on consultation_prescriptions for all to authenticated
  using (
    exists (select 1 from doctors d
      where d.id = consultation_prescriptions.doctor_id and d.user_id = auth.uid())
  )
  with check (
    exists (select 1 from doctors d
      where d.id = consultation_prescriptions.doctor_id and d.user_id = auth.uid())
  );

-- --------------------------------------------------------------------------
-- Seed a small starter panel of doctors for the pilot, attached to the
-- active region (so the directory isn't empty on first launch). Ops can
-- edit/replace these from the admin dashboard.
-- --------------------------------------------------------------------------
insert into doctors (region_id, display_name, specialty, qualification, languages, years_experience, consult_fee, bio, rating, active)
select r.id, d.display_name, d.specialty, d.qualification, d.languages, d.years_experience, d.consult_fee, d.bio, d.rating, true
from (values
  ('Dr. Anjali Rao',    'General Physician', 'MBBS, MD (General Medicine)', array['Telugu','English','Hindi'], 14, 400, 'Family medicine and chronic-condition care for seniors.', 4.8),
  ('Dr. Venkata Subramanyam', 'Cardiologist', 'MBBS, DM (Cardiology)', array['Telugu','English'], 20, 700, 'Heart health, blood pressure and post-cardiac follow-up.', 4.9),
  ('Dr. Priya Menon',   'Geriatrician',      'MBBS, MD, Fellowship in Geriatrics', array['English','Malayalam','Hindi'], 11, 600, 'Whole-person elder care, mobility and memory concerns.', 4.7),
  ('Dr. Suresh Kumar',  'Orthopaedician',    'MBBS, MS (Orthopaedics)', array['Telugu','English','Hindi'], 16, 550, 'Joint pain, fractures and physiotherapy guidance.', 4.6)
) as d(display_name, specialty, qualification, languages, years_experience, consult_fee, bio, rating)
cross join lateral (select id from regions order by created_at limit 1) r;
