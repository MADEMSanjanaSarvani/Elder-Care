-- ============================================================================
-- Is there anybody real to send?
-- ----------------------------------------------------------------------------
-- Care plans cost ₹1,999 to ₹6,999 a month and the Choose-plan button opens a
-- live Razorpay checkout. What a plan buys is caregiver visits — so in a region
-- with no real caregiver recruited yet, it buys nothing, and the family is
-- charged every month regardless.
--
-- 0041 made the sample caregivers visible for what they are on the marketplace
-- screen. This is the same fact one step earlier in the funnel, where it costs
-- money rather than a wasted afternoon.
--
-- Security definer because the answer must not depend on what the caller can
-- see: caregivers_select is scoped to a caregiver's own row and to caregivers
-- attached to the family's bookings, so a family with no bookings yet — exactly
-- the family about to subscribe — would count zero either way and never learn
-- the difference between "none exist" and "none visible to you".
-- ============================================================================

create or replace function region_real_caregiver_count(p_elder_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
    from caregivers c
    join elder_profiles e on e.id = p_elder_id
   where c.region_id = e.region_id
     and c.active
     and c.bgv_status = 'cleared'
     and not c.demo
     -- Only answer for someone entitled to ask about this elder at all.
     and (is_elder_self(p_elder_id) or is_linked_family(p_elder_id) or is_admin());
$$;

revoke all on function region_real_caregiver_count(uuid) from public;
grant execute on function region_real_caregiver_count(uuid) to authenticated;

comment on function region_real_caregiver_count(uuid) is
  'How many real (non-demo, active, background-cleared) caregivers serve this
   elder''s region. Zero means a care plan cannot currently be delivered there,
   which the app says before anyone is asked to pay.';
