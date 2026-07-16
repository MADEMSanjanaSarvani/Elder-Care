-- Batch 5 database layer: Caregiver Management, Caregiver Performance &
-- Rating, Accessibility (docs/prd/08-prd-part8-caregiver-and-platform-ux.html).
-- Multi-language Support (Module 20) needs no schema — it uses the
-- existing preferred_language/primary_language fields and is Flutter-only.
--
-- Two deliberate non-touches this batch names explicitly: bookings-match
-- is NOT modified. Both signals that could have been wired into matching
-- here — caregiver availability and service-quality rating — are kept
-- informational/tracked-only for MVP, deferred rather than decided
-- unilaterally. The one existing-code touch (the admin deactivation
-- action gaining a reason parameter + a status-history insert) is
-- application code, handled in the admin dashboard, not this migration.

-- ---------------------------------------------------------------------
-- Module 17: Caregiver Management System
-- ---------------------------------------------------------------------

create table caregiver_profile_details (
  caregiver_id uuid primary key references caregivers (id) on delete cascade,
  bio text,
  photo_storage_path text,          -- points into the new caregiver-profile-photos bucket below
  service_radius_km numeric
);

alter table caregiver_profile_details enable row level security;

-- Shown to the caregiver themselves, admins, and any family connected to
-- this caregiver through a booking (a profile photo/bio is shown to
-- matched families — deliberately less sensitive than verification docs).
create policy caregiver_profile_details_select on caregiver_profile_details for select to authenticated
  using (
    caregiver_id = caregiver_id_for(auth.uid())
    or is_admin()
    or exists (
      select 1 from bookings b
      where b.caregiver_id = caregiver_profile_details.caregiver_id
        and (is_elder_self(b.elder_id) or is_linked_family(b.elder_id) or b.requested_by = auth.uid())
    )
  );
create policy caregiver_profile_details_write on caregiver_profile_details for all to authenticated
  using (caregiver_id = caregiver_id_for(auth.uid()) or is_admin())
  with check (caregiver_id = caregiver_id_for(auth.uid()) or is_admin());

create table caregiver_availability (
  id uuid primary key default gen_random_uuid(),
  caregiver_id uuid not null references caregivers (id) on delete cascade,
  day_of_week int not null check (day_of_week between 0 and 6),  -- 0 = Sunday
  start_time time not null,
  end_time time not null
);

alter table caregiver_availability enable row level security;

-- Informational for MVP — NOT read by bookings-match (named deferral).
create policy caregiver_availability_select on caregiver_availability for select to authenticated
  using (
    caregiver_id = caregiver_id_for(auth.uid())
    or is_admin()
    or exists (
      select 1 from bookings b
      where b.caregiver_id = caregiver_availability.caregiver_id
        and (is_elder_self(b.elder_id) or is_linked_family(b.elder_id) or b.requested_by = auth.uid())
    )
  );
create policy caregiver_availability_write on caregiver_availability for all to authenticated
  using (caregiver_id = caregiver_id_for(auth.uid()) or is_admin())
  with check (caregiver_id = caregiver_id_for(auth.uid()) or is_admin());

create table caregiver_onboarding_checklist (
  id uuid primary key default gen_random_uuid(),
  caregiver_id uuid not null references caregivers (id) on delete cascade,
  item text not null,               -- 'platform_orientation' | 'safety_training' | 'app_walkthrough' | ...
  completed boolean not null default false,
  completed_by uuid references profiles (id),
  completed_at timestamptz,
  unique (caregiver_id, item)
);

alter table caregiver_onboarding_checklist enable row level security;

-- Admin-tracked completion; the caregiver can see their own checklist.
-- Tracked, not enforced: does NOT gate trust_tier or matching (named
-- deferral, same reasoning as availability above).
create policy caregiver_onboarding_checklist_select on caregiver_onboarding_checklist for select to authenticated
  using (caregiver_id = caregiver_id_for(auth.uid()) or is_admin());
create policy caregiver_onboarding_checklist_write on caregiver_onboarding_checklist for all to authenticated
  using (is_admin())
  with check (is_admin());

create table caregiver_status_history (
  id uuid primary key default gen_random_uuid(),
  caregiver_id uuid not null references caregivers (id) on delete cascade,
  previous_active boolean not null,
  new_active boolean not null,
  reason text not null,             -- required — accountable deactivation history (see PRD cross-cutting)
  changed_by uuid not null references profiles (id),
  changed_at timestamptz not null default now()
);

alter table caregiver_status_history enable row level security;

-- Append-only history: the caregiver sees their own, admins see all.
-- Written only by the admin deactivation action (admin auth).
create policy caregiver_status_history_select on caregiver_status_history for select to authenticated
  using (caregiver_id = caregiver_id_for(auth.uid()) or is_admin());
create policy caregiver_status_history_insert on caregiver_status_history for insert to authenticated
  with check (is_admin() and changed_by = auth.uid());

-- Profile photos get their OWN bucket, separate from verification
-- documents (PRD §Security): a photo is shown to matched families, an ID
-- is admin-only; sharing one bucket would risk one RLS mistake exposing
-- the more sensitive class. Same private-bucket-plus-signed-URL pattern
-- as 0006's caregiver-documents bucket.
insert into storage.buckets (id, name, public)
values ('caregiver-profile-photos', 'caregiver-profile-photos', false)
on conflict (id) do nothing;

create policy caregiver_photos_storage_select on storage.objects for select to authenticated
  using (
    bucket_id = 'caregiver-profile-photos'
    and (
      is_admin()
      -- Any authenticated user connected to this caregiver via a booking
      -- may view the photo; the object path is `<caregiver_id>/...`.
      or exists (
        select 1 from caregivers c
        where storage.objects.name like c.id::text || '/%'
          and (
            c.user_id = auth.uid()
            or exists (
              select 1 from bookings b
              where b.caregiver_id = c.id
                and (is_elder_self(b.elder_id) or is_linked_family(b.elder_id) or b.requested_by = auth.uid())
            )
          )
      )
    )
  );
create policy caregiver_photos_storage_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'caregiver-profile-photos'
    and exists (
      select 1 from caregivers c
      where c.user_id = auth.uid() and storage.objects.name like c.id::text || '/%'
    )
  );

-- ---------------------------------------------------------------------
-- Module 18: Caregiver Performance & Rating System
--
-- Deliberately NOT the elder-consent (has_consent) model — a rating is
-- the CAREGIVER's data, gated by who may rate (the family member on a
-- completed booking) and who may see what (admin fully; caregiver
-- anonymized). A conceptually different actor and access model, named so
-- the two aren't confused.
-- ---------------------------------------------------------------------

create table caregiver_ratings (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references bookings (id) on delete cascade,
  caregiver_id uuid not null references caregivers (id) on delete cascade,
  rated_by uuid not null references profiles (id),
  stars int not null check (stars between 1 and 5),
  review_text text,
  flagged_for_review boolean not null default false,  -- auto-set true for stars <= 2 by the trigger below
  admin_reviewed boolean not null default false,
  created_at timestamptz not null default now()
);

alter table caregiver_ratings enable row level security;

-- SELECT on the base table is NOT granted to the caregiver — that would
-- expose rated_by. The caregiver reads through caregiver_ratings_anonymized
-- (below) instead. The base table is visible only to the rater
-- (their own rating) and admins.
create policy caregiver_ratings_select on caregiver_ratings for select to authenticated
  using (rated_by = auth.uid() or is_admin());
-- One rating per booking, by someone entitled to rate it, only once the
-- booking is completed.
create policy caregiver_ratings_insert on caregiver_ratings for insert to authenticated
  with check (
    rated_by = auth.uid()
    and exists (
      select 1 from bookings b
      where b.id = caregiver_ratings.booking_id
        and b.caregiver_id = caregiver_ratings.caregiver_id
        and b.status = 'completed'
        and (b.requested_by = auth.uid() or is_elder_self(b.elder_id) or is_linked_family(b.elder_id))
    )
  );
-- Admin marks a flagged rating reviewed.
create policy caregiver_ratings_update on caregiver_ratings for update to authenticated
  using (is_admin()) with check (is_admin());

create table caregiver_rating_summary (
  caregiver_id uuid primary key references caregivers (id) on delete cascade,
  average_stars numeric not null default 0,
  rating_count int not null default 0,
  updated_at timestamptz not null default now()
);

alter table caregiver_rating_summary enable row level security;

-- The aggregate is non-identifying and is shown to families choosing a
-- caregiver, so it's readable by any authenticated user. Written only by
-- the trigger (service-definer), never directly.
create policy caregiver_rating_summary_select on caregiver_rating_summary for select to authenticated
  using (true);

-- Anonymity toward the caregiver is enforced by a VIEW, not client-side
-- omission (PRD §Database): RLS grants row access but does not hide
-- individual columns from an otherwise-visible row. This view runs with
-- the definer's rights (default security_invoker = false), bypassing the
-- base table's RLS, and is scoped to the calling caregiver while omitting
-- rated_by entirely — so a caregiver can read their own reviews but can
-- never learn who wrote any given one.
create view caregiver_ratings_anonymized as
  select id, caregiver_id, booking_id, stars, review_text, flagged_for_review, created_at
  from caregiver_ratings
  where caregiver_id = caregiver_id_for(auth.uid());

-- Recomputes the summary and auto-flags low ratings. Security definer so
-- it can upsert the summary regardless of that table's policies — same
-- cross-cutting-invariant-in-a-trigger pattern as the Batch 2 stock
-- decrement and the Batch 3 must-deliver trigger.
create or replace function refresh_caregiver_rating_summary()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.stars <= 2 then
    new.flagged_for_review := true;
  end if;
  return new;
end;
$$;

create trigger trg_flag_low_rating
  before insert on caregiver_ratings
  for each row execute function refresh_caregiver_rating_summary();

create or replace function recompute_caregiver_rating_summary()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into caregiver_rating_summary (caregiver_id, average_stars, rating_count, updated_at)
  select new.caregiver_id, avg(stars)::numeric(3,2), count(*), now()
  from caregiver_ratings where caregiver_id = new.caregiver_id
  on conflict (caregiver_id) do update
    set average_stars = excluded.average_stars,
        rating_count = excluded.rating_count,
        updated_at = excluded.updated_at;
  return new;
end;
$$;

create trigger trg_recompute_rating_summary
  after insert on caregiver_ratings
  for each row execute function recompute_caregiver_rating_summary();

-- ---------------------------------------------------------------------
-- Module 19: Accessibility
-- ---------------------------------------------------------------------

create table accessibility_preferences (
  user_id uuid primary key references profiles (id) on delete cascade,
  text_scale text not null default 'default' check (text_scale in ('default', 'large', 'extra_large')),
  high_contrast boolean not null default false,
  simple_mode boolean not null default false
);

alter table accessibility_preferences enable row level security;

-- A user manages their own preferences; a linked family member may also
-- manage them when the target user is an elder (many elders never open a
-- settings screen). Reuses is_linked_family — no new access primitive.
-- The elder-role default (simple_mode + large text) is applied by the
-- client on first run, not a DB default, since it's role-dependent.
create policy accessibility_preferences_select on accessibility_preferences for select to authenticated
  using (
    user_id = auth.uid()
    or is_admin()
    or exists (
      select 1 from elder_profiles ep
      where ep.auth_user_id = accessibility_preferences.user_id and is_linked_family(ep.id)
    )
  );
create policy accessibility_preferences_write on accessibility_preferences for all to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from elder_profiles ep
      where ep.auth_user_id = accessibility_preferences.user_id and is_linked_family(ep.id)
    )
  )
  with check (
    user_id = auth.uid()
    or exists (
      select 1 from elder_profiles ep
      where ep.auth_user_id = accessibility_preferences.user_id and is_linked_family(ep.id)
    )
  );
