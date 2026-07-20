-- Fix: adding an elder failed with
--   "null value in column actor_user_id of relation consent_audit_log
--    violates not-null constraint".
--
-- Cause: family-add-elder inserts consent_grants using the SERVICE ROLE, so
-- auth.uid() is NULL inside the log_consent_change() trigger. actor_user_id is
-- NOT NULL, so the insert (and the whole add-elder call) aborted.
--
-- Fix: fall back to the granting family member (consent_grants.family_user_id),
-- which is always a valid profiles(id) and is the correct actor anyway. Normal
-- authenticated client operations still record auth.uid() as before.
create or replace function log_consent_change()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT' and new.granted) or (tg_op = 'UPDATE' and new.granted and not old.granted) then
    insert into consent_audit_log (elder_id, actor_user_id, action, category, metadata)
    values (
      new.elder_id,
      coalesce(auth.uid(), new.family_user_id),
      'grant',
      new.category,
      jsonb_build_object('granted_via', new.granted_via)
    );
  elsif tg_op = 'UPDATE' and old.granted and not new.granted then
    insert into consent_audit_log (elder_id, actor_user_id, action, category, metadata)
    values (
      new.elder_id,
      coalesce(auth.uid(), new.family_user_id),
      'revoke',
      new.category,
      '{}'::jsonb
    );
  end if;
  return new;
end;
$$;
