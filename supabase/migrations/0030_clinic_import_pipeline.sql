-- ============================================================================
-- Clinic import pipeline: staged, reviewed, consented
-- ----------------------------------------------------------------------------
-- Getting listings into the directory without publishing anything that is
-- wrong, stale, or someone else's to publish.
--
-- Two rules the schema enforces rather than trusts:
--
--  1. Nothing imported goes live automatically. Everything lands in
--     clinic_imports and a human promotes it. An import that publishes
--     straight to families is one bad row away from sending an 80-year-old
--     across town to a clinic that closed last year.
--
--  2. A doctor is only listed once they know they are listed. doctors.
--     consent_status starts at 'not_contacted' and the directory query
--     filters on 'consented'. Facilities (hospitals, clinics) are public
--     businesses and need no such consent; named individual practitioners
--     do.
-- ============================================================================

do $$ begin
  create type listing_consent as enum
    ('not_contacted', 'contacted', 'consented', 'declined');
exception when duplicate_object then null; end $$;

alter table doctors
  add column if not exists consent_status listing_consent
    not null default 'not_contacted',
  add column if not exists consent_note text,
  -- Where this record came from: 'manual', 'google_places', 'referral'.
  -- Kept so a bad source can be traced and pulled in one query.
  add column if not exists source text not null default 'manual',
  add column if not exists source_ref text,
  add column if not exists last_verified_at timestamptz;

comment on column doctors.consent_status is
  'A named practitioner is only shown to families at ''consented''. Listing a
   real doctor who never agreed is both a legal risk and, if the details are
   wrong, a safety one.';
comment on column doctors.last_verified_at is
  'When a human last confirmed this listing is still accurate. Clinics move,
   doctors retire; a listing nobody has checked in a year should be treated
   as stale and re-confirmed before a family is sent there.';

-- Staging area. Rows land here from an import and never reach families until
-- someone promotes them.
create table if not exists clinic_imports (
  id uuid primary key default gen_random_uuid(),
  region_id uuid references regions (id),
  source text not null,                  -- 'google_places' | 'manual' | ...
  source_ref text,                       -- e.g. the Places place_id
  name text not null,
  address text,
  phone text,
  lat double precision,
  lng double precision,
  raw jsonb not null default '{}'::jsonb,
  status text not null default 'pending'
    check (status in ('pending', 'promoted', 'rejected')),
  reviewed_by uuid references profiles (id),
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now(),
  unique (source, source_ref)            -- re-running an import updates, not duplicates
);

alter table clinic_imports enable row level security;

-- Staging is back-office only. Families never read it, and it is written by
-- the import function under the service role.
-- Uses the same has_admin_scope() helper every other admin policy uses,
-- rather than reaching into admin_scopes directly — one definition of what
-- "is a verification agent" means.
create policy clinic_imports_admin_read on clinic_imports for select
  using (has_admin_scope('verification_agent') or has_admin_scope('super_admin'));

create policy clinic_imports_admin_write on clinic_imports for update
  using (has_admin_scope('verification_agent') or has_admin_scope('super_admin'));

create index if not exists clinic_imports_pending_idx
  on clinic_imports (status, created_at desc);

create index if not exists doctors_consent_idx
  on doctors (consent_status, active);
