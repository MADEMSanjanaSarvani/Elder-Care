-- Batch 2 follow-up, found while wiring up Smart Reminder System: the
-- PRD's Appointment Management functional requirements (§03) mention a
-- "reminder lead time" field, but the Database Design schema card for
-- `appointments` in 0010 never actually defined a column for it — and
-- without one, nothing could ever enqueue an appointment reminder, since
-- §08 states enqueueing "is always a side effect of the source module's
-- own write path," not a separate endpoint.
--
-- Fixed the same way the Batch 1 check-in timeline gap was: add the
-- missing piece properly rather than leave a silently-unreachable table.

alter table appointments add column reminder_lead_time interval not null default '1 day';

-- Enqueues (and re-enqueues, on reschedule) a single reminder per
-- appointment. Deliberately does not attempt to expand recurrence_rule
-- into multiple future reminders — the PRD's own §13 edge case leaves
-- per-instance handling of a recurring appointment as "flagged... not
-- solved by MVP," and generating reminders for occurrences that don't
-- exist as concrete rows would be building past that same boundary.
-- Recurring appointments get a reminder for their next scheduled_at only;
-- extending this to walk recurrence_rule forward is real, named future
-- work, not silently missing.
create or replace function enqueue_appointment_reminder()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    update reminders set status = 'cancelled'
    where source_type = 'appointment' and source_id = new.id and status = 'pending';
  end if;

  if new.status = 'scheduled' then
    insert into reminders (elder_id, source_type, source_id, remind_at, recipient_scope)
    values (new.elder_id, 'appointment', new.id, new.scheduled_at - new.reminder_lead_time, 'both');
  end if;

  return new;
end;
$$;

create trigger trg_enqueue_appointment_reminder
  after insert or update of scheduled_at, status on appointments
  for each row execute function enqueue_appointment_reminder();
