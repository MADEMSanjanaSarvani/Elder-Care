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


-- ============================================================================
-- Demo caregivers for the pilot marketplace
-- ----------------------------------------------------------------------------
-- Folded in from sample_caregivers.sql, which used to be a manual "run this
-- yourself" script. Nothing ran it, so every `supabase db reset --linked`
-- produced a database with zero caregivers — and the booking flow's caregiver
-- list came back empty with no hint as to why. Seeding here means the
-- marketplace always has something to show.
--
-- These are DEMO records. Replace them with real, background-verified
-- caregivers before taking a rupee from anyone.
-- ============================================================================

do $$
declare
  v_region uuid;
  v_uid    uuid;
  rec      record;
begin
  select id into v_region from regions where code = 'vizag-ap-in' limit 1;
  if v_region is null then
    raise exception 'Region vizag-ap-in not found — the region seed above must run first.';
  end if;

  for rec in
    select * from (values
      ('aarti.demo@carehive.in',   'Aarti Rao',    'clinical',     'nurse',              'clinical_verified', 4.9, 128,
        'Senior home-care nurse, 8 years in geriatric care. Gentle and patient; fluent in Telugu, Hindi and English.'),
      ('priya.demo@carehive.in',   'Priya Sharma', 'clinical',     'nurse',              'clinical_verified', 5.0,  41,
        'Home-nursing specialist for medication, wound care and vitals. Meticulous, calm and kind.'),
      ('lakshmi.demo@carehive.in', 'Lakshmi Devi', 'clinical',     'physiotherapist',    'clinical_verified', 4.8,  64,
        'Licensed physiotherapist focused on mobility and post-surgery recovery for seniors.'),
      ('suresh.demo@carehive.in',  'Suresh Kumar', 'non_clinical', 'companion',          'standard',          4.7,  86,
        'Warm companion for daily visits, conversation and light help. Known for showing up on time, every time.'),
      ('ramesh.demo@carehive.in',  'Ramesh Naidu', 'non_clinical', 'hospital_attendant', 'standard',          4.6,  52,
        'Experienced hospital attendant for appointments and admissions. Steady and reassuring under pressure.'),
      ('venkat.demo@carehive.in',  'Venkat Rao',   'non_clinical', 'companion',          'standard',          4.5,  33,
        'Friendly companion and errands helper. Cheerful, punctual and wonderful with elders.')
    ) as t(email, name, cgtype, subrole, tier, stars, cnt, bio)
  loop
    -- 1. auth user (create only if the email is new)
    select id into v_uid from auth.users where email = rec.email;
    if v_uid is null then
      v_uid := gen_random_uuid();
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data, is_super_admin
      ) values (
        '00000000-0000-0000-0000-000000000000', v_uid,
        'authenticated', 'authenticated', rec.email,
        crypt('CareHiveDemo#2026', gen_salt('bf')),
        now(), now(), now(),
        '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, false
      );
    end if;

    -- 2. profile (caregiver role)
    insert into profiles (id, role, display_name, preferred_language)
      values (v_uid, 'caregiver', rec.name, 'en')
      on conflict (id) do update
        set display_name = excluded.display_name, role = 'caregiver';

    -- 3. caregiver record (verified + active). clinical roles need a council reg.
    if not exists (select 1 from caregivers where user_id = v_uid) then
      insert into caregivers (
        region_id, user_id, caregiver_type, sub_role,
        bgv_status, trust_tier, active, insurance_on_file,
        professional_council_reg_no
      ) values (
        v_region, v_uid, rec.cgtype::caregiver_type, rec.subrole::caregiver_sub_role,
        'cleared', rec.tier::trust_tier, true, true,
        case when rec.cgtype = 'clinical'
             then 'AP-REG-' || upper(substr(v_uid::text, 1, 6)) else null end
      );
    end if;

    -- 4. public profile (bio, location) + rating summary shown to families.
    -- Locations are scattered a few km around central Visakhapatnam so the
    -- "distance away" sort has something to work with.
    insert into caregiver_profile_details
      (caregiver_id, bio, service_radius_km, latitude, longitude)
      select id, rec.bio, 12,
             17.7042 + (random() - 0.5) * 0.08,
             83.3005 + (random() - 0.5) * 0.08
      from caregivers where user_id = v_uid
      on conflict (caregiver_id) do update
        set bio = excluded.bio,
            latitude = excluded.latitude,
            longitude = excluded.longitude;

    insert into caregiver_rating_summary (caregiver_id, average_stars, rating_count)
      select id, rec.stars, rec.cnt from caregivers where user_id = v_uid
      on conflict (caregiver_id) do update
        set average_stars = excluded.average_stars,
            rating_count  = excluded.rating_count;
  end loop;

  raise notice 'Sample caregivers ready.';
end $$;
