-- ============================================================================
-- Medical documents — lab reports, prescriptions, scans, discharge summaries
-- ----------------------------------------------------------------------------
-- Families can upload an elder's medical files (PDF/JPG/PNG). Access is gated
-- by the same health_notes consent as the rest of the health record: the elder
-- themselves, a family member with health_notes consent, or an admin. Files
-- live in a PRIVATE storage bucket; viewing requires a short-lived signed URL,
-- and who can mint one is governed by the storage RLS below.
-- ============================================================================

create table medical_documents (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  uploaded_by uuid not null references profiles (id),
  category text not null default 'other',
    -- 'lab_report' | 'prescription' | 'scan' | 'discharge_summary'
    -- | 'vaccination' | 'insurance' | 'other'
  title text not null,
  storage_path text not null,   -- '<elder_id>/<uuid>.<ext>' in medical-documents
  mime_type text,
  uploaded_at timestamptz not null default now()
);

create index medical_documents_elder_idx on medical_documents (elder_id, uploaded_at desc);

alter table medical_documents enable row level security;

create policy medical_documents_select on medical_documents for select to authenticated
  using (
    is_elder_self(elder_id)
    or has_consent(elder_id, auth.uid(), 'health_notes')
    or is_admin()
  );
create policy medical_documents_insert on medical_documents for insert to authenticated
  with check (
    uploaded_by = auth.uid()
    and (is_elder_self(elder_id)
      or has_consent(elder_id, auth.uid(), 'health_notes')
      or is_admin())
  );
create policy medical_documents_delete on medical_documents for delete to authenticated
  using (
    is_elder_self(elder_id)
    or has_consent(elder_id, auth.uid(), 'health_notes')
    or is_admin()
  );

-- Private bucket for the actual files.
insert into storage.buckets (id, name, public)
values ('medical-documents', 'medical-documents', false)
on conflict (id) do nothing;

-- Object paths are '<elder_id>/<uuid>.<ext>'. The first path segment is the
-- elder; access is checked against that, consistent with the table policy.
create policy medical_documents_storage_select on storage.objects for select to authenticated
  using (
    bucket_id = 'medical-documents'
    and (
      is_elder_self((split_part(name, '/', 1))::uuid)
      or has_consent((split_part(name, '/', 1))::uuid, auth.uid(), 'health_notes')
      or is_admin()
    )
  );
create policy medical_documents_storage_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'medical-documents'
    and (
      is_elder_self((split_part(name, '/', 1))::uuid)
      or has_consent((split_part(name, '/', 1))::uuid, auth.uid(), 'health_notes')
      or is_admin()
    )
  );
create policy medical_documents_storage_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'medical-documents'
    and (
      is_elder_self((split_part(name, '/', 1))::uuid)
      or has_consent((split_part(name, '/', 1))::uuid, auth.uid(), 'health_notes')
      or is_admin()
    )
  );
