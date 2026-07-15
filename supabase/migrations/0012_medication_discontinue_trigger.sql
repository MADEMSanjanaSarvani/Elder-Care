-- Batch 2 follow-up, found while building the medications screen: the
-- PRD's functional requirements for Medicine Management (§03) state that
-- discontinuing a medication should write an elder_timeline_events row
-- and cancel any pending future doses — but 0010 only built the tables,
-- not this side effect, since it wasn't part of the Database Design
-- schema cards. Same pattern as the two prior Batch 2 follow-ups
-- (0011's appointment reminder trigger): caught by actually building the
-- screen that calls this action, fixed properly rather than left half-done.

create or replace function on_medication_discontinued()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.active = false and old.active = true then
    update medication_doses
    set status = 'cancelled'
    where medication_id = new.id and status = 'pending';

    insert into elder_timeline_events (elder_id, event_type, category, summary, metadata)
    values (new.elder_id, 'medication_stopped', 'medication_list', new.name || ' discontinued', jsonb_build_object('medication_id', new.id));
  end if;
  return new;
end;
$$;

create trigger trg_on_medication_discontinued
  after update of active on elder_medications
  for each row execute function on_medication_discontinued();
