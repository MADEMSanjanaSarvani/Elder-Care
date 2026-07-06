-- Project Setu — core schema
-- Reference: docs/prd/02-prd-part2-architecture.html (Section 11) and
-- docs/prd/03-prd-part3-execution.html (Section 22, global scalability).
--
-- Every table that would otherwise hardcode "India"/"INR" carries a
-- region_id instead, so Phase 2-6 city/country expansion (see PRD Part 3
-- Section 19) is new `regions` rows, not schema changes.

create extension if not exists pgcrypto;
create extension if not exists postgis;

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------

create type user_role as enum ('elder', 'family_member', 'caregiver', 'admin');

create type region_status as enum ('planned', 'active', 'paused');

create type family_link_status as enum ('pending', 'active', 'revoked');

create type consent_category as enum (
  'location_live',
  'location_history',
  'health_notes',
  'medication_list',
  'visit_history',
  'billing'
);

create type consent_grant_source as enum ('elder_app', 'documented_guardian_process');

create type caregiver_type as enum ('clinical', 'non_clinical');

create type caregiver_sub_role as enum (
  'nurse',
  'physiotherapist',
  'hospital_attendant',
  'companion',
  'home_service_maid',
  'home_service_electrician',
  'home_service_plumber',
  'home_service_general'
);

create type bgv_status as enum ('not_started', 'submitted', 'in_progress', 'cleared', 'failed');

create type police_verification_status as enum ('not_started', 'submitted', 'in_progress', 'cleared', 'flagged');

create type trust_tier as enum ('probationary', 'standard', 'clinical_verified');

create type service_category as enum ('clinical', 'non_clinical');

create type booking_status as enum (
  'requested', 'matched', 'confirmed', 'in_progress', 'completed', 'cancelled', 'disputed'
);

create type payment_status as enum ('created', 'authorized', 'captured', 'failed', 'refunded');

create type payout_status as enum ('scheduled', 'processing', 'paid', 'failed');

create type sos_status as enum ('triggered', 'family_notified', 'responder_dispatched', 'resolved');

create type ai_interaction_type as enum ('visit_summary', 'translation', 'reminder', 'scheduling_assist');

-- ---------------------------------------------------------------------
-- Regions — the global-scalability seam (PRD Part 2 §11, Part 3 §22)
-- ---------------------------------------------------------------------

create table regions (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,                 -- e.g. 'vizag-ap-in'
  display_name text not null,
  country_code text not null,                -- ISO 3166-1 alpha-2
  currency text not null,                     -- ISO 4217
  tax_profile jsonb not null default '{}'::jsonb,
  payment_provider text not null,             -- e.g. 'razorpay'
  bgv_provider text not null,                 -- e.g. 'idfy'
  compliance_profile text not null,           -- e.g. 'dpdp_in'
  status region_status not null default 'planned',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role user_role not null,
  phone text unique,
  preferred_language text not null default 'en',
  display_name text,
  created_at timestamptz not null default now()
);

-- Fine-grained admin roles (PRD Part 2 §16) layered on top of profiles.role = 'admin'
create type admin_scope as enum ('verification_agent', 'sos_operator', 'ops_admin', 'finance_ops', 'super_admin');

create table admin_scopes (
  profile_id uuid not null references profiles (id) on delete cascade,
  scope admin_scope not null,
  primary key (profile_id, scope)
);

-- ---------------------------------------------------------------------
-- Elder & family
-- ---------------------------------------------------------------------

create table elder_profiles (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions (id),
  auth_user_id uuid references profiles (id),  -- null until the elder onboards their own login
  created_by uuid not null references profiles (id),
  display_name text not null,
  dob date,
  address jsonb not null default '{}'::jsonb,
  primary_language text not null default 'en',
  emergency_contacts jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table family_links (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  family_user_id uuid not null references profiles (id) on delete cascade,
  relationship text,
  status family_link_status not null default 'pending',
  invited_by uuid not null references profiles (id),
  created_at timestamptz not null default now(),
  unique (elder_id, family_user_id)
);

-- The consent graph every sensitive query joins against (PRD Part 1 §04, Part 2 §11/§13)
create table consent_grants (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  family_user_id uuid not null references profiles (id) on delete cascade,
  category consent_category not null,
  granted boolean not null default false,
  granted_via consent_grant_source not null default 'elder_app',
  granted_at timestamptz,
  revoked_at timestamptz,
  guardian_process_ref text,  -- required when granted_via = documented_guardian_process; see admin review workflow
  created_at timestamptz not null default now(),
  unique (elder_id, family_user_id, category)
);

create table consent_audit_log (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  actor_user_id uuid not null references profiles (id),
  action text not null,          -- 'grant' | 'revoke' | 'guardian_override_approved'
  category consent_category not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Sensitive, category-gated elder data lives in its own tables rather than as
-- columns on elder_profiles, so RLS can gate exactly one join per category.

create table elder_health_notes (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  booking_id uuid,  -- fk added after bookings table exists
  note text not null,
  source text not null,          -- 'ai_summary' | 'manual'
  created_by uuid not null references profiles (id),
  created_at timestamptz not null default now()
);

create table elder_medications (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  name text not null,
  dosage text not null,
  schedule jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  added_by uuid not null references profiles (id),
  created_at timestamptz not null default now()
);

create table elder_locations (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  location geography(point, 4326) not null,
  source text not null,           -- 'elder_app' | 'caregiver_visit'
  recorded_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Caregivers & verification
-- ---------------------------------------------------------------------

create table caregivers (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions (id),
  user_id uuid not null references profiles (id),
  caregiver_type caregiver_type not null,
  sub_role caregiver_sub_role not null,
  bgv_status bgv_status not null default 'not_started',
  bgv_provider_ref text,
  police_verification_status police_verification_status not null default 'not_started',
  police_verification_ref text,
  professional_council_reg_no text,   -- clinical roles only
  credential_verified_at timestamptz,
  insurance_on_file boolean not null default false,
  trust_tier trust_tier not null default 'probationary',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint clinical_requires_council_reg check (
    caregiver_type <> 'clinical' or professional_council_reg_no is not null
  )
);

create table caregiver_documents (
  id uuid primary key default gen_random_uuid(),
  caregiver_id uuid not null references caregivers (id) on delete cascade,
  doc_type text not null,          -- 'gov_id' | 'police_verification' | 'council_certificate' | 'insurance'
  storage_path text not null,      -- Supabase Storage object path
  verified boolean not null default false,
  verified_by uuid references profiles (id),
  uploaded_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Service catalog — per-region (PRD Part 2 §11 addendum)
-- ---------------------------------------------------------------------

create table service_catalog (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions (id),
  code text not null,
  name text not null,
  category service_category not null,
  base_price numeric(12, 2) not null,
  currency text not null,
  commission_pct numeric(5, 2) not null,
  tax_rule_ref text,
  requires_trust_tier trust_tier not null default 'standard',
  active boolean not null default true,
  unique (region_id, code)
);

-- ---------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------

create table bookings (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions (id),
  elder_id uuid not null references elder_profiles (id),
  requested_by uuid not null references profiles (id),
  caregiver_id uuid references caregivers (id),
  service_id uuid not null references service_catalog (id),
  required_trust_tier trust_tier not null,
  status booking_status not null default 'requested',
  scheduled_at timestamptz not null,
  otp_start text,
  otp_start_verified_at timestamptz,
  otp_end text,
  otp_end_verified_at timestamptz,
  created_at timestamptz not null default now()
);

alter table elder_health_notes
  add constraint elder_health_notes_booking_id_fkey
  foreign key (booking_id) references bookings (id) on delete set null;

create table booking_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings (id) on delete cascade,
  event_type text not null,
  actor_user_id uuid references profiles (id),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Payments — merchant-of-record ledger (PRD Part 1 decision, Part 2 §11/§15)
-- ---------------------------------------------------------------------

create table payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings (id),
  family_user_id uuid not null references profiles (id),
  amount numeric(12, 2) not null,
  currency text not null,
  commission_amount numeric(12, 2) not null,
  provider text not null,          -- regions.payment_provider at time of payment
  provider_ref text,               -- e.g. Razorpay payment id
  status payment_status not null default 'created',
  captured_at timestamptz,
  created_at timestamptz not null default now()
);

create table caregiver_payouts (
  id uuid primary key default gen_random_uuid(),
  caregiver_id uuid not null references caregivers (id),
  booking_id uuid not null references bookings (id),
  amount numeric(12, 2) not null,
  currency text not null,
  provider text not null,          -- e.g. 'razorpayx'
  provider_ref text,
  status payout_status not null default 'scheduled',
  scheduled_for timestamptz not null,
  paid_at timestamptz
);

-- ---------------------------------------------------------------------
-- Emergency SOS (PRD Part 1 §04, Part 2 §11)
-- ---------------------------------------------------------------------

create table sos_events (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id),
  triggered_by uuid not null references profiles (id),
  location geography(point, 4326),
  status sos_status not null default 'triggered',
  ack_108_shown_at timestamptz,     -- liability-boundary evidence: the 108-first screen was actually shown
  responder_caregiver_id uuid references caregivers (id),
  family_notified_at timestamptz,
  resolved_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- AI interactions (PRD Part 2 §14) — every AI touch, logged
-- ---------------------------------------------------------------------

create table ai_interactions (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id),
  booking_id uuid references bookings (id),
  initiated_by uuid not null references profiles (id),
  interaction_type ai_interaction_type not null,
  input_ref text,
  output_text text not null,
  flagged boolean not null default false,
  human_reviewed boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Audit log — DPDP-grade access trail (PRD Part 2 §13)
-- ---------------------------------------------------------------------

create table audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references profiles (id),
  action text not null,             -- 'read' | 'write' | 'consent_check_denied' | ...
  resource_type text not null,
  resource_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  type text not null,
  payload jsonb not null default '{}'::jsonb,
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------

create index idx_elder_profiles_region on elder_profiles (region_id);
create index idx_family_links_elder on family_links (elder_id);
create index idx_family_links_family_user on family_links (family_user_id);
create index idx_consent_grants_elder_family on consent_grants (elder_id, family_user_id);
create index idx_caregivers_region_tier on caregivers (region_id, trust_tier) where active;
create index idx_bookings_elder on bookings (elder_id);
create index idx_bookings_caregiver on bookings (caregiver_id);
create index idx_bookings_status on bookings (status);
create index idx_sos_events_elder on sos_events (elder_id);
create index idx_elder_locations_elder_time on elder_locations (elder_id, recorded_at desc);
create index idx_audit_log_actor on audit_log (actor_user_id, created_at desc);
