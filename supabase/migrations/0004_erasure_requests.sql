-- DPDP erasure right (PRD Part 2 §12/§13). A request is tracked here and
-- reviewed by an admin rather than triggering an automatic hard delete —
-- payment records, audit trails, and SOS events often have independent
-- legal retention requirements (tax law, safety-incident review) that a
-- blanket "delete everything" would violate. This table is the queue that
-- makes that human judgment call auditable, not a rubber stamp.

create type erasure_request_status as enum ('pending', 'in_review', 'completed', 'denied');

create table erasure_requests (
  id uuid primary key default gen_random_uuid(),
  requested_by uuid not null references profiles (id),
  reason text,
  status erasure_request_status not null default 'pending',
  admin_notes text,
  reviewed_by uuid references profiles (id),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

alter table erasure_requests enable row level security;

create policy erasure_requests_select on erasure_requests for select to authenticated
  using (requested_by = auth.uid() or has_admin_scope('super_admin'));

create policy erasure_requests_insert on erasure_requests for insert to authenticated
  with check (requested_by = auth.uid());

create policy erasure_requests_update_admin on erasure_requests for update to authenticated
  using (has_admin_scope('super_admin')) with check (has_admin_scope('super_admin'));

create index idx_erasure_requests_status on erasure_requests (status);
