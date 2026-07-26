-- ============================================================================
-- Who is waiting, and where
-- ----------------------------------------------------------------------------
-- The region picker tells a family in a region SETU hasn't reached: "we'll let
-- you know the moment we arrive." Nothing recorded that, so it was a promise
-- the app had no way to keep — and worse, the single most valuable signal in
-- the product was being thrown away every time it appeared.
--
-- Which city to open next is otherwise a guess. This turns it into a count:
-- twelve families waiting in Hyderabad and one in Ladakh is an answer, and it
-- comes from people who went to the trouble of adding their parent rather than
-- from a survey.
--
-- Deliberately minimal. No contact details are copied here — the profile
-- already has them, and duplicating an email into a second table means two
-- places to honour a DPDP erasure request instead of one. The cascade from
-- profiles does the deletion.
-- ============================================================================

create table if not exists region_interest (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  -- Which person they were adding when they hit the wall. Nullable because
  -- interest can also be registered without an elder (e.g. from a settings
  -- change), and null must not be a reason to lose the signal.
  elder_id uuid references elder_profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  -- Set when the family has actually been told the region went live, so a
  -- second launch announcement can't spam the same person twice.
  notified_at timestamptz,
  -- One row per person per region. Adding a second parent in the same city is
  -- not a second vote, and counting it as one would overstate demand exactly
  -- where the decision is most expensive.
  unique (region_id, profile_id)
);

create index if not exists region_interest_region_idx
  on region_interest (region_id) where notified_at is null;

alter table region_interest enable row level security;

-- A family can register and see their own interest, and nothing else. The
-- aggregate view of "how many people are waiting in Kerala" is an ops
-- question, answered through the admin dashboard's service role, not
-- something one user should be able to read about another.
drop policy if exists region_interest_select_own on region_interest;
create policy region_interest_select_own on region_interest
  for select to authenticated
  using (profile_id = auth.uid() or is_admin());

drop policy if exists region_interest_insert_own on region_interest;
create policy region_interest_insert_own on region_interest
  for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists region_interest_delete_own on region_interest;
create policy region_interest_delete_own on region_interest
  for delete to authenticated
  using (profile_id = auth.uid() or is_admin());

comment on table region_interest is
  'Families waiting for SETU to reach their region. The picker promises to
   tell them when it does; this is what makes that promise keepable, and
   doubles as the demand signal for which city to open next.';

-- ---------------------------------------------------------------------------
-- Register interest, ignoring regions that are already live.
--
-- The check belongs here rather than in the app: a client that forgets it
-- would quietly build a waiting list for a city SETU already serves, and the
-- expansion numbers would be wrong in the direction that costs the most.
-- ---------------------------------------------------------------------------
create or replace function register_region_interest(
  p_region_id uuid,
  p_elder_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  select status::text into v_status from regions where id = p_region_id;
  if v_status is null then
    raise exception 'No region with id %', p_region_id;
  end if;
  if v_status = 'active' then
    return;  -- Already served; nothing to wait for.
  end if;

  insert into region_interest (region_id, profile_id, elder_id)
  values (p_region_id, auth.uid(), p_elder_id)
  on conflict (region_id, profile_id) do nothing;
end $$;

revoke all on function register_region_interest(uuid, uuid) from public;
grant execute on function register_region_interest(uuid, uuid) to authenticated;

comment on function register_region_interest(uuid, uuid) is
  'Adds the caller to the waiting list for a region, silently doing nothing
   when the region is already active. The active check lives here so a client
   that forgets it cannot inflate the expansion numbers.';
