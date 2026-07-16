-- Batch 7 database layer (FINAL): Consent & Privacy Management, Enhanced
-- Emergency Services (docs/prd/10-prd-part10-trust-and-safety.html).
--
-- Neither module rebuilds what exists. Consent & Privacy adds a request
-- queue and a presentation layer in front of the ALREADY-permitted
-- consent_grants grant path — consent_grants, has_consent(), and every
-- policy depending on them are untouched, full stop. Enhanced Emergency
-- keeps drills in a table completely separate from real sos_events, and
-- makes exactly one behavioral touch to sos-trigger (payload enrichment),
-- handled in that function.

-- ---------------------------------------------------------------------
-- Module 24: Consent & Privacy Management
-- ---------------------------------------------------------------------

create type guardian_request_status as enum ('pending', 'approved', 'denied');

create table guardian_consent_requests (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  requested_by uuid not null references profiles (id),
  category consent_category not null,           -- reuses the existing enum, no new value
  basis_description text not null,              -- the documented basis PRD Part 2 §13 requires
  basis_document_storage_path text,             -- optional supporting doc (medical cert, POA) in the bucket below
  status guardian_request_status not null default 'pending',
  reviewed_by uuid references profiles (id),
  reviewed_at timestamptz,
  admin_notes text,
  created_at timestamptz not null default now()
);

alter table guardian_consent_requests enable row level security;

-- The elder or a linked family member may file and read their own elder's
-- requests; only an admin may change status. Approval is NOT modeled here —
-- an approving admin performs the actual grant through the existing,
-- already-permitted consent_grants_write path (granted_via =
-- 'documented_guardian_process' and is_admin()), which needs no change.
create policy guardian_consent_requests_select on guardian_consent_requests for select to authenticated
  using (is_elder_self(elder_id) or is_linked_family(elder_id) or is_admin());
create policy guardian_consent_requests_insert on guardian_consent_requests for insert to authenticated
  with check (requested_by = auth.uid() and (is_elder_self(elder_id) or is_linked_family(elder_id)));
create policy guardian_consent_requests_update on guardian_consent_requests for update to authenticated
  using (is_admin()) with check (is_admin());

-- Private bucket for the optional basis document — admin-only plus the
-- submitter, same private-bucket-plus-signed-URL pattern as 0006. Object
-- path convention: `<elder_id>/<uuid>.<ext>`.
insert into storage.buckets (id, name, public)
values ('guardian-consent-documents', 'guardian-consent-documents', false)
on conflict (id) do nothing;

create policy guardian_docs_storage_select on storage.objects for select to authenticated
  using (
    bucket_id = 'guardian-consent-documents'
    and (
      is_admin()
      or exists (
        select 1 from guardian_consent_requests r
        where r.basis_document_storage_path = storage.objects.name and r.requested_by = auth.uid()
      )
    )
  );
create policy guardian_docs_storage_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'guardian-consent-documents'
    and exists (
      select 1 from elder_profiles ep
      where storage.objects.name like ep.id::text || '/%'
        and (is_elder_self(ep.id) or is_linked_family(ep.id))
    )
  );

-- ---------------------------------------------------------------------
-- Module 25: Enhanced Emergency Services
-- ---------------------------------------------------------------------

create table sos_incident_reports (
  id uuid primary key default gen_random_uuid(),
  sos_event_id uuid not null unique references sos_events (id) on delete cascade,
  emergency_services_engaged boolean not null default false,  -- was 108/local EMS actually contacted
  outcome_summary text not null,
  lessons_notes text,
  filed_by uuid not null references profiles (id),
  filed_at timestamptz not null default now()
);

alter table sos_incident_reports enable row level security;

-- Post-resolution QA layer: sos_operator admins file and read. The elder
-- and their family may also read the report for their own event
-- (transparency about what happened), but never file it.
create policy sos_incident_reports_select on sos_incident_reports for select to authenticated
  using (
    is_admin()
    or exists (
      select 1 from sos_events s
      where s.id = sos_incident_reports.sos_event_id
        and (is_elder_self(s.elder_id) or is_linked_family(s.elder_id))
    )
  );
create policy sos_incident_reports_write on sos_incident_reports for all to authenticated
  using (has_admin_scope('sos_operator')) with check (has_admin_scope('sos_operator') and filed_by = auth.uid());

-- The module's central safety decision: drills are a COMPLETELY SEPARATE
-- table from sos_events, not an is_drill flag on it. Co-mingling would
-- create a standing risk that any future query, report, or admin view
-- that forgets to filter treats a drill as real (or a real event as
-- practice) — unacceptable for a life-safety system. A drill never touches
-- real notification infrastructure (see sos-drill-trigger).
create table sos_drills (
  id uuid primary key default gen_random_uuid(),
  triggered_by uuid not null references profiles (id),
  elder_id uuid references elder_profiles (id),
  feedback text,                                -- guidance shown back to the practicing user
  created_at timestamptz not null default now()
);

alter table sos_drills enable row level security;

-- A drill is visible only to the person who practiced it (and admins for
-- aggregate drill-completion tracking). No insert policy for
-- `authenticated` — written by sos-drill-trigger via the service-role
-- client, keeping the drill path and the real path fully separate.
create policy sos_drills_select on sos_drills for select to authenticated
  using (triggered_by = auth.uid() or is_admin());
