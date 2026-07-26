-- ============================================================================
-- Fix Family Access: the screen could never show the family
-- ----------------------------------------------------------------------------
-- Reported as "blank". It is, and there are three separate reasons stacked on
-- top of each other. Each one alone would empty the screen.
--
-- 1. family_links_select allows `family_user_id = auth.uid()` — you can read
--    your own link and nobody else's. So a daughter looking at the care circle
--    sees exactly one person: herself.
--
-- 2. family_links_select_shared was meant to fix that, but it requires
--    elder_profiles.share_family_list = true, which defaults to false and has
--    no UI anywhere in the app. In the normal SETU flow the elder never logs
--    in at all — the daughter creates the profile — so there is literally no
--    one who can turn it on. The policy can never fire.
--
-- 3. Even with the links visible, the screen embeds profiles(display_name,
--    phone), and profiles_select_self_or_admin allows `id = auth.uid()`.
--    PostgREST returns an RLS-blocked embedded row as null rather than an
--    error, and the screen renders a null name as "Pending invite" — so the
--    list would have shown a column of grey "Pending invite" rows even if the
--    links had come through.
--
-- The obvious fix — loosening profiles RLS — is the wrong one: it would make
-- every user's display name and phone number readable by every other user of
-- SETU, which is a far worse bug than the one being fixed. So the circle is
-- read through this function instead, which is the only thing that widens, and
-- widens by exactly one relationship: people caring for the same elder.
--
-- On share_family_list: it still governs elders who have their own account,
-- because an elder with a login can make that call for themselves. When the
-- elder profile was created by a family member and has no account, there is
-- nobody to set it and the flag would only keep the screen broken forever, so
-- the circle is visible to its own active members. Coordinating care with
-- people you cannot see is not a thing anyone can do.
-- ============================================================================

create or replace function family_circle(p_elder_id uuid)
returns table (
  id uuid,
  relationship text,
  status text,
  coordinator boolean,
  display_name text,
  phone text,
  email text,
  is_self boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    fl.id,
    fl.relationship,
    fl.status::text,
    fl.coordinator,
    p.display_name,
    p.phone,
    u.email::text,
    fl.family_user_id = auth.uid() as is_self
  from family_links fl
  left join profiles p on p.id = fl.family_user_id
  left join auth.users u on u.id = fl.family_user_id
  where fl.elder_id = p_elder_id
    and (
      is_admin()
      or is_elder_self(p_elder_id)
      -- An active member of this circle, and either the elder has opted in or
      -- the elder has no account and so cannot opt in either way.
      or (
        is_linked_family(p_elder_id)
        and exists (
          select 1 from elder_profiles ep
          where ep.id = p_elder_id
            and (ep.share_family_list or ep.auth_user_id is null)
        )
      )
    )
  order by fl.coordinator desc, fl.created_at;
$$;

comment on function family_circle(uuid) is
  'The care circle for one elder, readable by its own active members. Exists
   because the screen previously embedded profiles(), which RLS blocks for
   everyone but yourself — and loosening profiles RLS would expose every
   SETU user''s name and phone to every other user. Widens visibility by
   exactly one relationship: caring for the same person.';

revoke all on function family_circle(uuid) from public;
grant execute on function family_circle(uuid) to authenticated;
