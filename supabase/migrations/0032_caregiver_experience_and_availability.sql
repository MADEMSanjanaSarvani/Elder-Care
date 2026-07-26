-- ============================================================================
-- What a family actually wants to know before letting someone into the house
-- ----------------------------------------------------------------------------
-- The caregiver card could show a name, a role, a trust tier, a rating and a
-- bio. It could not show how long they have been doing this, what they are
-- qualified in, or which days they work — the three things people ask about
-- a stranger who will be alone with their mother.
--
-- All three go on caregiver_profile_details rather than caregivers, because
-- they are profile content the caregiver maintains, not verification state
-- the platform asserts. The distinction matters: trust_tier and bgv_status
-- are claims SETU stands behind, and these are claims the caregiver makes
-- about themselves. Keeping them in different tables keeps that line visible.
-- ============================================================================

alter table caregiver_profile_details
  add column if not exists years_experience smallint
    check (years_experience is null or years_experience between 0 and 70),
  -- Free text, e.g. 'GNM Nursing', 'Elder care certificate'. Deliberately
  -- unvalidated: a certificate SETU has actually seen is recorded through the
  -- verification queue and reflected in trust_tier. This list is what the
  -- caregiver says about themselves, and the UI must present it that way.
  add column if not exists certifications text[] not null default '{}',
  add column if not exists languages text[] not null default '{}',
  -- ISO weekdays (1 = Monday ... 7 = Sunday). Empty means "not stated",
  -- shown as "ask when booking" rather than as "never available".
  add column if not exists available_days smallint[] not null default '{}',
  add column if not exists available_from time,
  add column if not exists available_to time;

comment on column caregiver_profile_details.certifications is
  'Self-declared. Anything SETU has actually verified shows up in trust_tier
   instead — the UI must not present these as platform-checked.';
comment on column caregiver_profile_details.available_days is
  'ISO weekdays the caregiver normally works. Empty means not stated, which
   the UI shows as "ask when booking" — never as unavailable, or a caregiver
   who simply skipped the field would silently stop being bookable.';
