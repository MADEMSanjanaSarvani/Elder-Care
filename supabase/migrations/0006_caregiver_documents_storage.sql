-- Storage bucket + RLS for caregiver ID/certificate uploads
-- (`caregiver_documents.storage_path`). Nothing declared this bucket
-- before now — `caregiver_documents` has stored a path string since
-- 0001_schema.sql, but there was nowhere for that path to actually point,
-- which is why the Admin Dashboard's verification queue could only ever
-- show verification *status*, never the uploaded image itself.
--
-- Private bucket: a signed URL is required to view anything in it, and
-- who can even request one is governed by RLS on storage.objects below —
-- the same "RLS is the enforcement layer" approach as every other table
-- in this schema, not a service-role bypass.

insert into storage.buckets (id, name, public)
values ('caregiver-documents', 'caregiver-documents', false)
on conflict (id) do nothing;

-- Object paths are expected in the form `<caregiver_id>/<doc_type>-<uuid>.<ext>`
-- so both policies below can check ownership by matching
-- caregiver_documents.storage_path — which the uploader controls — against
-- the object actually being requested, without trusting the object's own
-- `owner` column (that's set by whoever uploaded it, not verified against
-- our caregivers table).

create policy caregiver_documents_storage_select on storage.objects for select to authenticated
  using (
    bucket_id = 'caregiver-documents'
    and (
      has_admin_scope('verification_agent')
      or exists (
        select 1 from caregiver_documents cd
        join caregivers c on c.id = cd.caregiver_id
        where cd.storage_path = storage.objects.name and c.user_id = auth.uid()
      )
    )
  );

create policy caregiver_documents_storage_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'caregiver-documents'
    and exists (
      select 1 from caregivers c
      where c.user_id = auth.uid()
        and storage.objects.name like c.id::text || '/%'
    )
  );
