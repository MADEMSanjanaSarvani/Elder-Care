-- Project Setu — Row Level Security
-- Reference: docs/prd/02-prd-part2-architecture.html (Section 13).
--
-- RLS is the actual enforcement layer here, not the Flutter client's
-- judgement. Every policy below is written so that revoking a consent
-- grant, or removing a family_link, takes effect on the next query — not
-- on the next app release.

-- ---------------------------------------------------------------------
-- Helper functions (security definer: they read tables the calling role
-- may not otherwise be allowed to see, purely to answer "am I allowed").
-- ---------------------------------------------------------------------

create or replace function current_profile_role()
returns user_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid();
$$;

create or replace function is_admin()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function has_admin_scope(required_scope admin_scope)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from admin_scopes
    where profile_id = auth.uid()
      and (scope = required_scope or scope = 'super_admin')
  );
$$;

create or replace function is_elder_self(target_elder_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from elder_profiles
    where id = target_elder_id and auth_user_id = auth.uid()
  );
$$;

create or replace function is_linked_family(target_elder_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from family_links
    where elder_id = target_elder_id
      and family_user_id = auth.uid()
      and status = 'active'
  );
$$;

-- The function every sensitive query joins against (PRD Part 1 §04, Part 2 §11/§13).
create or replace function has_consent(target_elder_id uuid, requesting_user uuid, target_category consent_category)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from consent_grants
    where elder_id = target_elder_id
      and family_user_id = requesting_user
      and category = target_category
      and granted = true
      and revoked_at is null
  );
$$;

create or replace function is_assigned_caregiver(target_booking_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from bookings b
    join caregivers c on c.id = b.caregiver_id
    where b.id = target_booking_id and c.user_id = auth.uid()
  );
$$;

create or replace function caregiver_id_for(auth_uid uuid)
returns uuid
language sql stable security definer set search_path = public as $$
  select id from caregivers where user_id = auth_uid limit 1;
$$;

-- ---------------------------------------------------------------------
-- Consent audit trigger — logs every grant/revoke, independent of the
-- client's own good behavior (PRD Part 2 §13).
-- ---------------------------------------------------------------------

create or replace function log_consent_change()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT' and new.granted) or (tg_op = 'UPDATE' and new.granted and not old.granted) then
    insert into consent_audit_log (elder_id, actor_user_id, action, category, metadata)
    values (new.elder_id, auth.uid(), 'grant', new.category, jsonb_build_object('granted_via', new.granted_via));
  elsif tg_op = 'UPDATE' and old.granted and not new.granted then
    insert into consent_audit_log (elder_id, actor_user_id, action, category, metadata)
    values (new.elder_id, auth.uid(), 'revoke', new.category, '{}'::jsonb);
  end if;
  return new;
end;
$$;

create trigger trg_log_consent_change
  after insert or update on consent_grants
  for each row execute function log_consent_change();

-- ---------------------------------------------------------------------
-- Enable RLS everywhere. Tables with no policy at all default-deny for
-- every role except the service_role key used by Edge Functions.
-- ---------------------------------------------------------------------

alter table regions enable row level security;
alter table profiles enable row level security;
alter table admin_scopes enable row level security;
alter table elder_profiles enable row level security;
alter table family_links enable row level security;
alter table consent_grants enable row level security;
alter table consent_audit_log enable row level security;
alter table elder_health_notes enable row level security;
alter table elder_medications enable row level security;
alter table elder_locations enable row level security;
alter table caregivers enable row level security;
alter table caregiver_documents enable row level security;
alter table service_catalog enable row level security;
alter table bookings enable row level security;
alter table booking_events enable row level security;
alter table payments enable row level security;
alter table caregiver_payouts enable row level security;
alter table sos_events enable row level security;
alter table ai_interactions enable row level security;
alter table audit_log enable row level security;
alter table notifications enable row level security;

-- ---------------------------------------------------------------------
-- regions — read-only config, no PII
-- ---------------------------------------------------------------------

create policy regions_select on regions for select to authenticated using (true);
create policy regions_write_admin on regions for all to authenticated
  using (has_admin_scope('super_admin')) with check (has_admin_scope('super_admin'));

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------

create policy profiles_select_self_or_admin on profiles for select to authenticated
  using (id = auth.uid() or is_admin());
create policy profiles_update_self on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_insert_self on profiles for insert to authenticated
  with check (id = auth.uid());

-- ---------------------------------------------------------------------
-- admin_scopes
-- ---------------------------------------------------------------------

create policy admin_scopes_select on admin_scopes for select to authenticated
  using (profile_id = auth.uid() or has_admin_scope('super_admin'));
create policy admin_scopes_manage on admin_scopes for all to authenticated
  using (has_admin_scope('super_admin')) with check (has_admin_scope('super_admin'));

-- ---------------------------------------------------------------------
-- elder_profiles — basic identity fields; sensitive data lives elsewhere
-- ---------------------------------------------------------------------

create policy elder_profiles_select on elder_profiles for select to authenticated
  using (
    auth_user_id = auth.uid()
    or is_linked_family(id)
    or is_admin()
  );
create policy elder_profiles_insert on elder_profiles for insert to authenticated
  with check (created_by = auth.uid());
create policy elder_profiles_update on elder_profiles for update to authenticated
  using (auth_user_id = auth.uid() or is_linked_family(id) or is_admin())
  with check (auth_user_id = auth.uid() or is_linked_family(id) or is_admin());

-- ---------------------------------------------------------------------
-- family_links
-- ---------------------------------------------------------------------

create policy family_links_select on family_links for select to authenticated
  using (family_user_id = auth.uid() or is_elder_self(elder_id) or is_admin());
create policy family_links_insert on family_links for insert to authenticated
  with check (invited_by = auth.uid() and (is_elder_self(elder_id) or is_linked_family(elder_id)));
create policy family_links_update on family_links for update to authenticated
  using (family_user_id = auth.uid() or is_elder_self(elder_id) or is_admin())
  with check (family_user_id = auth.uid() or is_elder_self(elder_id) or is_admin());

-- ---------------------------------------------------------------------
-- consent_grants — only the elder (or an admin-reviewed guardian process)
-- may grant or revoke; family members may only read their own grants.
-- ---------------------------------------------------------------------

create policy consent_grants_select on consent_grants for select to authenticated
  using (family_user_id = auth.uid() or is_elder_self(elder_id) or is_admin());
create policy consent_grants_write on consent_grants for all to authenticated
  using (
    is_elder_self(elder_id)
    or (granted_via = 'documented_guardian_process' and is_admin())
  )
  with check (
    is_elder_self(elder_id)
    or (granted_via = 'documented_guardian_process' and is_admin())
  );

-- consent_audit_log: read-only to clients, written only by the trigger above.
create policy consent_audit_log_select on consent_audit_log for select to authenticated
  using (is_elder_self(elder_id) or is_admin());

-- ---------------------------------------------------------------------
-- Category-gated elder data
-- ---------------------------------------------------------------------

create policy elder_health_notes_select on elder_health_notes for select to authenticated
  using (
    is_elder_self(elder_id)
    or has_consent(elder_id, auth.uid(), 'health_notes')
    or is_admin()
    or exists (
      select 1 from bookings b join caregivers c on c.id = b.caregiver_id
      where b.elder_id = elder_health_notes.elder_id
        and c.user_id = auth.uid()
        and b.status in ('confirmed', 'in_progress', 'completed')
    )
  );
create policy elder_health_notes_insert on elder_health_notes for insert to authenticated
  with check (
    created_by = auth.uid()
    and (
      is_admin()
      or exists (
        select 1 from bookings b join caregivers c on c.id = b.caregiver_id
        where b.elder_id = elder_health_notes.elder_id
          and c.user_id = auth.uid()
          and b.status in ('confirmed', 'in_progress')
      )
    )
  );

create policy elder_medications_select on elder_medications for select to authenticated
  using (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'medication_list') or is_admin());
create policy elder_medications_write on elder_medications for all to authenticated
  using (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'medication_list') or is_admin())
  with check (added_by = auth.uid() and (is_elder_self(elder_id) or has_consent(elder_id, auth.uid(), 'medication_list') or is_admin()));

create policy elder_locations_select on elder_locations for select to authenticated
  using (
    is_elder_self(elder_id)
    or (source = 'elder_app' and has_consent(elder_id, auth.uid(), 'location_live'))
    or (source != 'elder_app' and has_consent(elder_id, auth.uid(), 'location_history'))
    or is_admin()
  );
create policy elder_locations_insert on elder_locations for insert to authenticated
  with check (
    (source = 'elder_app' and is_elder_self(elder_id))
    or (source = 'caregiver_visit' and exists (
      select 1 from bookings b join caregivers c on c.id = b.caregiver_id
      where b.elder_id = elder_locations.elder_id and c.user_id = auth.uid() and b.status = 'in_progress'
    ))
  );

-- ---------------------------------------------------------------------
-- caregivers — own record, plus limited visibility for a matched family
-- ---------------------------------------------------------------------

create policy caregivers_select on caregivers for select to authenticated
  using (
    user_id = auth.uid()
    or is_admin()
    or exists (
      select 1 from bookings b
      where b.caregiver_id = caregivers.id and (
        is_elder_self(b.elder_id) or is_linked_family(b.elder_id) or b.requested_by = auth.uid()
      )
    )
  );
create policy caregivers_update_self on caregivers for update to authenticated
  using (user_id = auth.uid() or has_admin_scope('verification_agent'))
  with check (user_id = auth.uid() or has_admin_scope('verification_agent'));

create policy caregiver_documents_select on caregiver_documents for select to authenticated
  using (
    exists (select 1 from caregivers c where c.id = caregiver_id and c.user_id = auth.uid())
    or has_admin_scope('verification_agent')
  );
create policy caregiver_documents_insert on caregiver_documents for insert to authenticated
  with check (exists (select 1 from caregivers c where c.id = caregiver_id and c.user_id = auth.uid()));

-- ---------------------------------------------------------------------
-- service_catalog — browsable by anyone signed in
-- ---------------------------------------------------------------------

create policy service_catalog_select on service_catalog for select to authenticated using (true);
create policy service_catalog_write on service_catalog for all to authenticated
  using (has_admin_scope('ops_admin')) with check (has_admin_scope('ops_admin'));

-- ---------------------------------------------------------------------
-- bookings — status transitions are mostly owned by Edge Functions using
-- the service role key (which bypasses RLS by design); these policies
-- cover direct client reads and the narrow set of client-initiated writes.
-- ---------------------------------------------------------------------

create policy bookings_select on bookings for select to authenticated
  using (
    requested_by = auth.uid()
    or is_elder_self(elder_id)
    or (caregiver_id is not null and caregiver_id = caregiver_id_for(auth.uid()))
    or (is_linked_family(elder_id) and has_consent(elder_id, auth.uid(), 'visit_history'))
    or is_admin()
  );
create policy bookings_insert on bookings for insert to authenticated
  with check (requested_by = auth.uid() and (is_elder_self(elder_id) or is_linked_family(elder_id)));
create policy bookings_update_cancel on bookings for update to authenticated
  using (requested_by = auth.uid() and status = 'requested')
  with check (status = 'cancelled');

create policy booking_events_select on booking_events for select to authenticated
  using (exists (
    select 1 from bookings b where b.id = booking_id and (
      b.requested_by = auth.uid() or is_elder_self(b.elder_id)
      or b.caregiver_id = caregiver_id_for(auth.uid())
      or is_admin()
    )
  ));

-- ---------------------------------------------------------------------
-- payments / payouts — written only by Edge Functions (service role)
-- ---------------------------------------------------------------------

create policy payments_select on payments for select to authenticated
  using (
    family_user_id = auth.uid()
    or has_admin_scope('finance_ops')
    or exists (
      select 1 from bookings b
      where b.id = booking_id and is_linked_family(b.elder_id) and has_consent(b.elder_id, auth.uid(), 'billing')
    )
  );

create policy caregiver_payouts_select on caregiver_payouts for select to authenticated
  using (caregiver_id = caregiver_id_for(auth.uid()) or has_admin_scope('finance_ops'));

-- ---------------------------------------------------------------------
-- sos_events — life-safety visibility overrides granular consent
-- ---------------------------------------------------------------------

create policy sos_events_select on sos_events for select to authenticated
  using (
    is_elder_self(elder_id)
    or is_linked_family(elder_id)
    or responder_caregiver_id = caregiver_id_for(auth.uid())
    or has_admin_scope('sos_operator')
  );
create policy sos_events_insert on sos_events for insert to authenticated
  with check (triggered_by = auth.uid() and (is_elder_self(elder_id) or is_linked_family(elder_id)));
create policy sos_events_update on sos_events for update to authenticated
  using (
    triggered_by = auth.uid()
    or is_elder_self(elder_id)
    or is_linked_family(elder_id)
    or has_admin_scope('sos_operator')
  )
  with check (true);

-- ---------------------------------------------------------------------
-- ai_interactions — read-only to clients; written by Edge Functions
-- ---------------------------------------------------------------------

create policy ai_interactions_select on ai_interactions for select to authenticated
  using (
    is_elder_self(elder_id)
    or (is_linked_family(elder_id) and has_consent(elder_id, auth.uid(), 'health_notes'))
    or is_admin()
  );

-- ---------------------------------------------------------------------
-- audit_log — super_admin only via direct query; a self-service "who
-- accessed my data" view for elders is a Part 3/4 product feature built
-- on top of this table through a dedicated Edge Function, not raw RLS,
-- since correlating resource_type/resource_id back to an elder_id
-- generically isn't expressible as a single policy.
-- ---------------------------------------------------------------------

create policy audit_log_select_admin on audit_log for select to authenticated
  using (has_admin_scope('super_admin'));

-- ---------------------------------------------------------------------
-- notifications
-- ---------------------------------------------------------------------

create policy notifications_select on notifications for select to authenticated
  using (user_id = auth.uid());
create policy notifications_update_read on notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
