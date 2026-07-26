-- ============================================================================
-- Give the demo caregivers the details the booking screen now asks for
-- ----------------------------------------------------------------------------
-- 0032 added years_experience, certifications, languages and working days, and
-- the caregiver selection screen now shows them under an "IN THEIR OWN WORDS"
-- heading. Every existing caregiver row predates those columns, so the section
-- renders empty for all six of them and the screen looks broken rather than
-- honest — "no experience listed, no languages, ask when booking" on a nurse
-- whose bio says eight years in geriatric care.
--
-- These values are read off the bios already in seed.sql, not invented: Aarti's
-- bio says 8 years and three languages, Lakshmi's says licensed
-- physiotherapist, and so on. They stay demo data, and they stay in the
-- self-declared half of the schema — nothing here touches trust_tier or
-- bgv_status, which are the claims SETU stands behind.
--
-- Only fills rows that are still empty. A caregiver who has since written
-- their own profile must never have it overwritten by a migration.
-- ============================================================================

update caregiver_profile_details d
set
  years_experience = coalesce(d.years_experience, v.years),
  certifications =
    case when d.certifications = '{}' then v.certs else d.certifications end,
  languages =
    case when d.languages = '{}' then v.langs else d.languages end,
  available_days =
    case when d.available_days = '{}' then v.days else d.available_days end,
  available_from = coalesce(d.available_from, v.from_at),
  available_to = coalesce(d.available_to, v.to_at)
from (values
  ('aarti.demo@carehive.in',   8::smallint,
     array['GNM Nursing', 'Geriatric care certificate'],
     array['Telugu', 'Hindi', 'English'],
     array[1,2,3,4,5,6]::smallint[], '08:00'::time, '18:00'::time),
  ('priya.demo@carehive.in',   6::smallint,
     array['B.Sc Nursing', 'Wound care training'],
     array['Hindi', 'English'],
     array[1,2,3,4,5]::smallint[],   '09:00'::time, '19:00'::time),
  ('lakshmi.demo@carehive.in', 10::smallint,
     array['BPT (Physiotherapy)', 'Post-surgical rehabilitation'],
     array['Telugu', 'English'],
     array[1,3,5,6]::smallint[],     '07:00'::time, '15:00'::time),
  ('suresh.demo@carehive.in',  5::smallint,
     array['Elder companion training', 'First aid'],
     array['Telugu', 'Hindi'],
     array[1,2,3,4,5,6,7]::smallint[], '08:00'::time, '20:00'::time),
  ('ramesh.demo@carehive.in',  7::smallint,
     array['Hospital attendant training', 'First aid'],
     array['Telugu', 'Hindi', 'English'],
     array[1,2,3,4,5,6]::smallint[], '06:00'::time, '22:00'::time),
  ('venkat.demo@carehive.in',  3::smallint,
     array['Elder companion training'],
     array['Telugu'],
     array[2,3,4,5,6]::smallint[],   '09:00'::time, '17:00'::time)
) as v(email, years, certs, langs, days, from_at, to_at)
where d.caregiver_id in (
  select c.id
    from caregivers c
    join auth.users u on u.id = c.user_id
   where u.email = v.email
);
