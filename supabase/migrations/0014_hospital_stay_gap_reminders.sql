-- Batch 3 follow-up: Hospital Companion Services' coverage-gap alerts.
-- The PRD (Part 6, Module 11 §04/§12) requires gap detection to feed the
-- shared Smart Reminder System as a new source_type rather than a bespoke
-- alert mechanism — but 0013 only built the tables. Two pieces of shared
-- infrastructure need to learn the new source type, both fail-closed
-- until they do: required_consent_for_source() returns null for unknown
-- types (so no family member could see a gap reminder), and
-- reminders-dispatch-sweep cancels reminders whose source_type it doesn't
-- recognize (so none would ever send). Same catch-it-by-building-on-it
-- pattern as 0011/0012.

-- A coverage gap is part of the stay's care logistics — exactly as
-- sensitive as the stay itself, which is visit_history-gated.
create or replace function required_consent_for_source(source_type text)
returns consent_category
language sql immutable as $$
  select case source_type
    when 'medication_dose' then 'medication_list'::consent_category
    when 'medication_stock' then 'medication_list'::consent_category
    when 'appointment' then 'visit_history'::consent_category
    when 'hospital_stay_gap' then 'visit_history'::consent_category
    else null
  end;
$$;

-- reminders-dispatch-sweep writes notifications as `reminder_${source_type}`;
-- the Family Notification Center's config table needs to know the type.
insert into notification_types (type, can_disable, default_channel, description) values
  ('reminder_hospital_stay_gap', true, 'push', 'A hospital stay has an upcoming coverage gap');
