-- ============================================================================
-- Mark the demo caregivers as demo
-- ----------------------------------------------------------------------------
-- Six caregivers were seeded so the booking flow could be exercised before any
-- real one had been recruited: Priya Sharma, Aarti Rao, Lakshmi Devi, Suresh
-- Kumar, Ramesh Naidu, Venkat Rao. They are invented people, their star ratings
-- and review counts are typed-in numbers, and "Clinically verified" on their
-- cards is a hardcoded trust_tier rather than the outcome of any background
-- check.
--
-- Nothing in the app said so. A family in Visakhapatnam could open the
-- marketplace, read "Clinically verified · 5.0 (41)", tap "Request Priya", and
-- get a real booking row against a person who does not exist. Nobody would
-- arrive. On a platform whose entire proposition is that a stranger can be
-- trusted inside your parent's home, that is the most damaging thing the app
-- could do.
--
-- The flag is on the caregiver rather than inferred from the .demo@ email
-- address in the UI, because a display decision this important should not
-- depend on parsing a string that anybody could later change.
-- ============================================================================

alter table caregivers
  add column if not exists demo boolean not null default false;

comment on column caregivers.demo is
  'True for seeded sample caregivers who are not real people. The app labels
   these unmistakably and refuses to let a booking reach them. Set by 0041 from
   the seeded .demo@ accounts; must stay false for every real caregiver.';

-- Flag exactly the seeded accounts, by the address they were created with.
update caregivers c
   set demo = true
  from auth.users u
 where u.id = c.user_id
   and u.email like '%.demo@carehive.in';

create index if not exists caregivers_demo_idx on caregivers (demo)
  where demo;
