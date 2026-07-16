-- Project Setu — MVP seed data
-- One active region (Visakhapatnam, per PRD Part 1 pilot-city decision) and
-- the MVP service catalog (PRD Part 1 Section 09). Commission percentages
-- and the GST profile below are illustrative placeholders — confirm actual
-- rates with finance/a CA before this leaves staging.

insert into regions (code, display_name, country_code, currency, tax_profile, payment_provider, bgv_provider, compliance_profile, status)
values (
  'vizag-ap-in',
  'Visakhapatnam, Andhra Pradesh',
  'IN',
  'INR',
  '{"gst_rate": 18, "note": "confirm applicable GST rate and SAC/HSN classification with a CA before launch"}'::jsonb,
  'razorpay',
  'idfy',
  'dpdp_in',
  'active'
);

insert into service_catalog (region_id, code, name, category, base_price, currency, commission_pct, requires_trust_tier)
select id, v.code, v.name, v.category::service_category, v.base_price, 'INR', v.commission_pct, v.requires_trust_tier::trust_tier
from regions, (values
  ('hospital_companion',   'Hospital Companion',       'non_clinical', 799.00,  20.00, 'standard'),
  ('home_nursing',         'Home Nursing Visit',       'clinical',     1199.00, 15.00, 'clinical_verified'),
  ('physiotherapy',        'Physiotherapy Session',    'clinical',     999.00,  15.00, 'clinical_verified'),
  ('medicine_pickup',      'Medicine Pickup',          'non_clinical', 149.00,  20.00, 'probationary'),
  ('grocery_assistance',   'Grocery Assistance',       'non_clinical', 199.00,  20.00, 'probationary'),
  ('companionship_visit',  'Companionship Visit',      'non_clinical', 499.00,  20.00, 'standard')
) as v(code, name, category, base_price, commission_pct, requires_trust_tier)
where regions.code = 'vizag-ap-in';

-- Care plan catalog (PRD Part 9, Batch 6, Module 21): a three-tier ladder,
-- each tier a strict superset of the one below it.
--   Basic    — the essentials (companionship + medicine pickup).
--   Standard — Basic's coverage increased, plus grocery help + physio.
--   Premium  — everything in Standard, plus two features Standard doesn't
--              have at all: in-home nursing and hospital companion cover.
insert into care_plans (region_id, code, name, description, monthly_price, currency)
select id, v.code, v.name, v.description, v.monthly_price, 'INR'
from regions, (values
  ('basic',    'Basic Care',    'Regular companionship and medicine pickups — the essentials for staying connected.',           1999.00),
  ('standard', 'Standard Care', 'Everything in Basic, with more visits plus grocery help and a monthly physiotherapy session.', 3999.00),
  ('premium',  'Premium Care',  'Everything in Standard, plus in-home nursing and hospital companion cover for higher-needs care.', 6999.00)
) as v(code, name, description, monthly_price)
where regions.code = 'vizag-ap-in';

-- Allocations: (plan, service) -> N visits per period. Superset structure
-- is visible here — Standard's rows cover every service Basic has (at
-- higher counts) plus two more; Premium covers every service Standard has
-- plus home_nursing and hospital_companion.
insert into care_plan_allocations (care_plan_id, service_id, visits_per_period, period)
select cp.id, sc.id, a.visits, 'month'
from regions r
join care_plans cp on cp.region_id = r.id
join service_catalog sc on sc.region_id = r.id
join (values
  -- Basic
  ('basic',    'companionship_visit', 4),
  ('basic',    'medicine_pickup',     2),
  -- Standard (superset of Basic + grocery + physio)
  ('standard', 'companionship_visit', 8),
  ('standard', 'medicine_pickup',     4),
  ('standard', 'grocery_assistance',  2),
  ('standard', 'physiotherapy',       1),
  -- Premium (superset of Standard + home nursing + hospital companion)
  ('premium',  'companionship_visit', 12),
  ('premium',  'medicine_pickup',     4),
  ('premium',  'grocery_assistance',  4),
  ('premium',  'physiotherapy',       2),
  ('premium',  'home_nursing',        2),
  ('premium',  'hospital_companion',  2)
) as a(plan_code, service_code, visits) on cp.code = a.plan_code and sc.code = a.service_code
where r.code = 'vizag-ap-in';
