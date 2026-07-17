-- ============================================================================
-- CareHive — sample caregivers for the pilot marketplace (Visakhapatnam)
-- ----------------------------------------------------------------------------
-- Run ONCE in the Supabase SQL Editor (Dashboard -> SQL Editor -> New query ->
-- paste -> Run). It is idempotent: running it again changes nothing.
--
-- Creates six demo caregivers — auth user + profile + caregiver record +
-- public profile (bio) + rating summary — so families can browse and CHOOSE a
-- caregiver when booking. These are DEMO records for testing the experience;
-- replace them with real, verified caregivers before going live.
-- ============================================================================

do $$
declare
  v_region uuid;
  v_uid    uuid;
  rec      record;
begin
  select id into v_region from regions where code = 'vizag-ap-in' limit 1;
  if v_region is null then
    raise exception 'Region vizag-ap-in not found. Run the main seed (seed.sql) first.';
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

    -- 4. public profile (bio) + rating summary shown to families
    insert into caregiver_profile_details (caregiver_id, bio, service_radius_km)
      select id, rec.bio, 12 from caregivers where user_id = v_uid
      on conflict (caregiver_id) do update set bio = excluded.bio;

    insert into caregiver_rating_summary (caregiver_id, average_stars, rating_count)
      select id, rec.stars, rec.cnt from caregivers where user_id = v_uid
      on conflict (caregiver_id) do update
        set average_stars = excluded.average_stars,
            rating_count  = excluded.rating_count;
  end loop;

  raise notice 'Sample caregivers ready.';
end $$;
