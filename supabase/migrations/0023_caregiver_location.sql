-- ============================================================================
-- Caregiver base location for distance-based search
-- ----------------------------------------------------------------------------
-- caregivers carried a region but no point location, so families couldn't see
-- or sort by "how near is this caregiver". Add a simple lat/lng to the public
-- profile details (used by caregivers-for-service to compute distance from the
-- family's current location). Kept as plain numerics — the browse path does a
-- lightweight haversine in the Edge Function rather than round-tripping PostGIS.
-- ============================================================================

alter table caregiver_profile_details
  add column if not exists latitude numeric,
  add column if not exists longitude numeric;
