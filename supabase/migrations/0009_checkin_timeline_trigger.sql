-- Batch 1 follow-up, found while building the Timeline screen: a
-- successful daily check-in never reached elder_timeline_events, since
-- that table has no insert policy for `authenticated` (writes are
-- service-role only, by design — see 0008's comment on
-- elder_timeline_events_select). Only the missed-check-in escalation
-- ever appeared, which reads as "the timeline only shows bad news."
--
-- Fixed the same way stock decrement and the coordinator-change guard
-- were: a security-definer trigger on the new table itself, not a policy
-- change and not a new Edge Function. daily_checkins is part of this same
-- batch, not one of the protected existing modules.

create or replace function log_checkin_to_timeline()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into elder_timeline_events (elder_id, event_type, category, summary, metadata, occurred_at)
  values (
    new.elder_id,
    'checkin_completed',
    'wellbeing_checkins',
    'Checked in',
    jsonb_build_object('mood', new.mood, 'source', new.source),
    new.checked_in_at
  );
  return new;
end;
$$;

create trigger trg_log_checkin_to_timeline
  after insert on daily_checkins
  for each row execute function log_checkin_to_timeline();
