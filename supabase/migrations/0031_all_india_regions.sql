-- ============================================================================
-- All 28 states and 8 union territories of India
-- ----------------------------------------------------------------------------
-- Every one is inserted as 'planned', not 'active', and that is the whole
-- point of this migration.
--
-- A region is not a dropdown entry — it is a promise that SETU can send a
-- verified caregiver to someone's parent there. Marking Kerala 'active' with
-- no caregivers, no doctors and nobody on the ground means a daughter signs
-- up, books a visit for her mother, and nothing happens. That is worse than
-- telling her honestly that SETU isn't in her city yet.
--
-- So: the list is complete so families can find their state and say "I want
-- this here", and the status is honest about where SETU actually operates.
-- Activating a state is a deliberate act — see activate_region() below —
-- taken once there are caregivers on the ground, not once the row exists.
--
-- Codes follow ISO 3166-2:IN, so 'ka-in' is Karnataka. The existing pilot
-- row 'vizag-ap-in' is city-level and stays exactly as it is: it is the one
-- market that genuinely is live.
-- ============================================================================

insert into regions (
  code, display_name, country_code, currency, tax_profile,
  payment_provider, bgv_provider, compliance_profile, status
)
select
  v.code,
  v.display_name,
  'IN',
  'INR',
  '{"gst_rate": 18, "note": "confirm applicable GST rate and SAC/HSN classification with a CA before launch"}'::jsonb,
  'razorpay',
  'idfy',
  'dpdp_in',
  'planned'
from (values
  -- States
  ('ap-in', 'Andhra Pradesh'),
  ('ar-in', 'Arunachal Pradesh'),
  ('as-in', 'Assam'),
  ('br-in', 'Bihar'),
  ('ct-in', 'Chhattisgarh'),
  ('ga-in', 'Goa'),
  ('gj-in', 'Gujarat'),
  ('hr-in', 'Haryana'),
  ('hp-in', 'Himachal Pradesh'),
  ('jh-in', 'Jharkhand'),
  ('ka-in', 'Karnataka'),
  ('kl-in', 'Kerala'),
  ('mp-in', 'Madhya Pradesh'),
  ('mh-in', 'Maharashtra'),
  ('mn-in', 'Manipur'),
  ('ml-in', 'Meghalaya'),
  ('mz-in', 'Mizoram'),
  ('nl-in', 'Nagaland'),
  ('or-in', 'Odisha'),
  ('pb-in', 'Punjab'),
  ('rj-in', 'Rajasthan'),
  ('sk-in', 'Sikkim'),
  ('tn-in', 'Tamil Nadu'),
  ('tg-in', 'Telangana'),
  ('tr-in', 'Tripura'),
  ('up-in', 'Uttar Pradesh'),
  ('ut-in', 'Uttarakhand'),
  ('wb-in', 'West Bengal'),
  -- Union territories
  ('an-in', 'Andaman and Nicobar Islands'),
  ('ch-in', 'Chandigarh'),
  ('dh-in', 'Dadra and Nagar Haveli and Daman and Diu'),
  ('dl-in', 'Delhi'),
  ('jk-in', 'Jammu and Kashmir'),
  ('la-in', 'Ladakh'),
  ('ld-in', 'Lakshadweep'),
  ('py-in', 'Puducherry')
) as v(code, display_name)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- Turn a region on.
--
-- Copies the service catalogue from an already-live region (the pilot, by
-- default) and flips the status. Prices come across unchanged and are meant
-- to be adjusted afterwards — a home-nursing visit does not cost the same in
-- Vizag as in Mumbai.
--
-- Deliberately refuses to activate a region with no caregivers. The check is
-- here rather than in a runbook because the failure it prevents is a family
-- booking a visit nobody can attend, and a step that only exists in a
-- document is a step that eventually gets skipped.
-- ---------------------------------------------------------------------------
create or replace function activate_region(
  p_code text,
  p_copy_services_from text default 'vizag-ap-in',
  p_force boolean default false
)
returns void
language plpgsql
as $$
declare
  v_region uuid;
  v_source uuid;
  v_caregivers int;
begin
  select id into v_region from regions where code = p_code;
  if v_region is null then
    raise exception 'No region with code %', p_code;
  end if;

  select count(*) into v_caregivers
    from caregivers
   where region_id = v_region and active and bgv_status = 'cleared';

  if v_caregivers = 0 and not p_force then
    raise exception
      'Region % has no verified caregivers. Families there would be able to '
      'book visits nobody can attend. Onboard caregivers first, or pass '
      'p_force => true if you know what you are doing.', p_code;
  end if;

  select id into v_source from regions where code = p_copy_services_from;
  if v_source is null then
    raise exception 'No source region with code %', p_copy_services_from;
  end if;

  insert into service_catalog (
    region_id, code, name, category, base_price, currency,
    commission_pct, tax_rule_ref, requires_trust_tier, active
  )
  select
    v_region, s.code, s.name, s.category, s.base_price, s.currency,
    s.commission_pct, s.tax_rule_ref, s.requires_trust_tier, s.active
  from service_catalog s
  where s.region_id = v_source
  on conflict (region_id, code) do nothing;

  update regions set status = 'active' where id = v_region;

  raise notice 'Region % is now active with % verified caregiver(s).',
    p_code, v_caregivers;
end $$;

comment on function activate_region(text, text, boolean) is
  'Copy the service catalogue into a region and mark it active. Refuses when
   the region has no verified caregivers, because an active region with no
   supply lets families book visits nobody can attend.';
