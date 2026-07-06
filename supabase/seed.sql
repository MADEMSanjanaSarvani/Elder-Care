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
