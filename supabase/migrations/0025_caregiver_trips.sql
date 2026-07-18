-- ============================================================================
-- Live caregiver trips — "your caregiver is on the way", Uber-style.
-- ----------------------------------------------------------------------------
-- One trip per booking, created when the caregiver sets off. The caregiver's
-- app updates current_lat/lng + status; the family subscribes over Realtime
-- and watches the visit go en_route → arrived → completed. Location is only
-- ever shared for the window of an active visit the family themselves booked —
-- the row is deleted/cancelled at completion, never a standing location feed.
-- ============================================================================

create type trip_status as enum ('en_route', 'arrived', 'completed', 'cancelled');

create table caregiver_trips (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references bookings (id) on delete cascade,
  caregiver_id uuid not null references caregivers (id),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  status trip_status not null default 'en_route',
  current_lat numeric,
  current_lng numeric,
  destination_lat numeric,
  destination_lng numeric,
  eta_minutes int,
  started_at timestamptz not null default now(),
  arrived_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

create index caregiver_trips_booking_idx on caregiver_trips (booking_id);
create index caregiver_trips_caregiver_idx on caregiver_trips (caregiver_id);

alter table caregiver_trips enable row level security;

-- The assigned caregiver owns their trip: they create it and stream updates.
create policy caregiver_trips_caregiver_write on caregiver_trips for all to authenticated
  using (is_assigned_caregiver(booking_id))
  with check (is_assigned_caregiver(booking_id));

-- The elder and their linked family (who booked the visit) can watch it, as
-- can the assigned caregiver and admins. This is operational visibility for a
-- visit they arranged — not gated on a consent category.
create policy caregiver_trips_select on caregiver_trips for select to authenticated
  using (
    is_elder_self(elder_id)
    or is_linked_family(elder_id)
    or is_assigned_caregiver(booking_id)
    or is_admin()
  );

-- Keep updated_at honest on every write.
create or replace function set_caregiver_trip_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger caregiver_trips_touch
  before update on caregiver_trips
  for each row execute function set_caregiver_trip_updated_at();

-- Realtime delivery for the family's live view.
alter publication supabase_realtime add table caregiver_trips;

-- Latest known lat/lng for an elder, decoded from the PostGIS point, so the
-- trip-start Edge Function can seed a destination without the client ever
-- touching geography types. Service-role only (called from the function).
create or replace function latest_elder_location(p_elder_id uuid)
returns table (lat double precision, lng double precision)
language sql stable security definer set search_path = public as $$
  select st_y(location::geometry), st_x(location::geometry)
  from elder_locations
  where elder_id = p_elder_id
  order by recorded_at desc
  limit 1;
$$;

revoke all on function latest_elder_location(uuid) from public, authenticated, anon;
