-- ============================================================================
-- Caregiver self-registration (professional onboarding)
-- ----------------------------------------------------------------------------
-- Until now caregiver rows were created by ops. This adds the applicant-facing
-- path: a caregiver signs up, fills a professional application, and lands in
-- the admin verification queue. The caregivers row is created inactive
-- (active = false, bgv 'not_started') by the caregiver-register Edge Function;
-- an admin activates it after verification. The richer application fields live
-- here, separate from the operational caregivers row.
-- ============================================================================

create table if not exists caregiver_application_details (
  caregiver_id uuid primary key references caregivers (id) on delete cascade,
  date_of_birth date,
  gender text,
  address jsonb not null default '{}'::jsonb,
  -- Government ID (e.g. Aadhaar) is collected for verification. It is
  -- read-restricted to the caregiver themselves and admins. In production this
  -- should be routed to the KYC/BGV provider and stored only as a reference /
  -- masked value rather than in the clear — tracked as a hardening task.
  government_id text,
  qualification text,
  experience_years numeric,
  certifications text,
  languages text[] not null default '{}',
  skills text[] not null default '{}',
  preferred_hours text,
  expected_charge numeric,
  emergency_contact_name text,
  emergency_contact_phone text,
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table caregiver_application_details enable row level security;

-- Only the caregiver themselves and admins can read/write these details
-- (they include a government ID). Written via the caregiver-register function
-- (service role) or the caregiver editing their own application.
create policy caregiver_application_details_select
  on caregiver_application_details for select to authenticated
  using (caregiver_id = caregiver_id_for(auth.uid()) or is_admin());
create policy caregiver_application_details_write
  on caregiver_application_details for all to authenticated
  using (caregiver_id = caregiver_id_for(auth.uid()) or is_admin())
  with check (caregiver_id = caregiver_id_for(auth.uid()) or is_admin());
