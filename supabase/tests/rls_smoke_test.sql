-- Functional RLS smoke test — simulates an elder, an un-consented family
-- member, a consented family member, a total stranger, and an assigned
-- vs. unassigned caregiver, and checks each sees exactly what PRD Part 1
-- §04 / Part 2 §13 say they should. This is the single most important
-- thing in the whole schema to have actually verified, since the consent
-- model is the platform's core trust claim, not incidental plumbing.
--
-- Run against a fresh database that already has local_auth_stub.sql,
-- 0001_schema.sql, 0002_rls.sql, 0003_realtime.sql, and seed.sql applied
-- (see this directory's README for the exact commands). Deliberately run
-- WITHOUT -v ON_ERROR_STOP=1: TEST 8 is *supposed* to fail (RLS should
-- reject the insert), so the script needs to keep going past it.
--
-- Every numbered test below was run for real against Postgres 16 +
-- PostGIS and produced the row counts noted in each comment — this is a
-- regression test, not aspirational documentation, but every developer
-- environment can differ; if a row count doesn't match the comment,
-- that's a real regression to chase, not a flaky test to retry.

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'elder@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'daughter@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'stranger@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'caregiver@test.com');

insert into profiles (id, role, phone, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'elder', '+911', 'Raghunath'),
  ('22222222-2222-2222-2222-222222222222', 'family_member', '+912', 'Ananya'),
  ('33333333-3333-3333-3333-333333333333', 'family_member', '+913', 'Stranger'),
  ('44444444-4444-4444-4444-444444444444', 'caregiver', '+914', 'Meena');

insert into elder_profiles (id, region_id, auth_user_id, created_by, display_name, primary_language)
select 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', id, '11111111-1111-1111-1111-111111111111',
       '11111111-1111-1111-1111-111111111111', 'Raghunath', 'te'
from regions where code = 'vizag-ap-in';

insert into family_links (elder_id, family_user_id, relationship, status, invited_by) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'daughter', 'active', '11111111-1111-1111-1111-111111111111');

insert into elder_health_notes (elder_id, note, source, created_by) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Blood pressure checked, normal.', 'manual', '11111111-1111-1111-1111-111111111111');

\echo '=== TEST 1: un-consented family member reads elder_health_notes — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_notes from elder_health_notes where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 2: elder grants health_notes consent to daughter — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into consent_grants (elder_id, family_user_id, category, granted, granted_via, granted_at)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'health_notes', true, 'elder_app', now());
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 3: daughter reads elder_health_notes AFTER consent — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_notes from elder_health_notes where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 4: elder revokes consent — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update consent_grants set granted = false, revoked_at = now()
where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and family_user_id = '22222222-2222-2222-2222-222222222222' and category = 'health_notes';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 5: daughter reads elder_health_notes AFTER revocation — expect 0 (takes effect immediately, no re-login needed) ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_notes from elder_health_notes where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 6: consent_audit_log recorded both the grant and the revoke — expect 2 rows (grant, revoke) ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select action, category from consent_audit_log where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' order by created_at;
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 7: total stranger cannot see the elder profile at all — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_elders from elder_profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 8: stranger cannot self-grant consent for a category — expect an RLS ERROR below, not a silent success ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
insert into consent_grants (elder_id, family_user_id, category, granted, granted_via, granted_at)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'billing', true, 'elder_app', now());
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 9: elder always sees their own health notes regardless of consent_grants — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select count(*) as visible_notes from elder_health_notes where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 10: caregiver with no booking cannot see elder profile — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select count(*) as visible_elders from elder_profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

insert into caregivers (id, region_id, user_id, caregiver_type, sub_role, trust_tier, bgv_status, police_verification_status)
select 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', id, '44444444-4444-4444-4444-444444444444', 'non_clinical', 'companion', 'standard', 'cleared', 'cleared'
from regions where code = 'vizag-ap-in';

-- Simulates what bookings-match would do server-side (service role).
insert into bookings (id, region_id, elder_id, requested_by, caregiver_id, service_id, required_trust_tier, status, scheduled_at)
select 'cccccccc-cccc-cccc-cccc-cccccccccccc', r.id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
       sc.id, 'standard', 'matched', now()
from regions r join service_catalog sc on sc.region_id = r.id and sc.code = 'companionship_visit'
where r.code = 'vizag-ap-in';

\echo '=== TEST 11: caregiver assigned to a booking CAN see the elder profile — expect 1 (this is the fix: elder_profiles_select originally omitted the assigned-caregiver clause entirely) ==='
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select count(*) as visible_elders from elder_profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 12: family member sees a booking they requested without needing visit_history consent — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_bookings from bookings where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 13: stranger cannot see the booking at all — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_bookings from bookings where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 14: elder files an erasure_requests row for themself — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into erasure_requests (id, requested_by, reason)
values ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'closing my account');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 15: a different family member cannot read someone else''s erasure_requests row — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_requests from erasure_requests where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 16: a non-admin cannot resolve someone else''s erasure_requests row — expect an RLS no-op (0 rows updated), not a silent bypass ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
update erasure_requests set status = 'denied' where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 17: caregiver submits their own payout bank details — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
insert into caregiver_payout_accounts (id, caregiver_id, account_holder_name, bank_account_number, ifsc)
values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Meena', '000123456789', 'HDFC0000001');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 18: a stranger cannot read another caregiver''s bank details — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_payout_accounts from caregiver_payout_accounts where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 19: caregiver uploads their own document into the caregiver-documents bucket — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
insert into storage.objects (bucket_id, name, owner)
values ('caregiver-documents', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/gov_id-1.jpg', '44444444-4444-4444-4444-444444444444');
reset role;
reset request.jwt.claim.sub;

insert into caregiver_documents (caregiver_id, doc_type, storage_path)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'gov_id', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/gov_id-1.jpg');

insert into auth.users (id, email) values
  ('55555555-5555-5555-5555-555555555555', 'verification-agent@test.com');
insert into profiles (id, role, phone, display_name) values
  ('55555555-5555-5555-5555-555555555555', 'admin', '+915', 'Verification Agent');
insert into admin_scopes (profile_id, scope) values
  ('55555555-5555-5555-5555-555555555555', 'verification_agent');

\echo '=== TEST 20: that same caregiver can read their own uploaded document — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select count(*) as visible_objects from storage.objects where name = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/gov_id-1.jpg';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 21: a stranger cannot read that document — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_objects from storage.objects where name = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/gov_id-1.jpg';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 22: a verification_agent admin can read any caregiver''s document — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
select count(*) as visible_objects from storage.objects where name = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/gov_id-1.jpg';
reset role;
reset request.jwt.claim.sub;

-- ===================================================================
-- Batch 1 (docs/prd/04-prd-part4-family-experience.html): Elder Care
-- Timeline, Daily Check-ins System, Family Member Management.
-- ===================================================================

\echo '=== TEST 23: elder self-checks-in — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into daily_checkins (id, elder_id, mood, source)
values ('ffffffff-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'okay', 'elder_app');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 24: a family member cannot check in on the elder''s behalf — expect an RLS ERROR, not a silent success ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into daily_checkins (elder_id, mood, source)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'okay', 'elder_app');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 25: daughter without wellbeing_checkins consent cannot see the check-in — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_checkins from daily_checkins where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 26: elder grants wellbeing_checkins consent, daughter can now see it — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into consent_grants (elder_id, family_user_id, category, granted, granted_via, granted_at)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'wellbeing_checkins', true, 'elder_app', now());
reset role;
reset request.jwt.claim.sub;
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_checkins from daily_checkins where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 27: daughter (linked family) can configure the check-in schedule — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into checkin_schedules (elder_id, expected_by_time, timezone)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '19:00', 'Asia/Kolkata');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 28: a stranger cannot see the check-in schedule — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_schedules from checkin_schedules where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 29: daughter marks a missed-checkin escalation handled — expect success ==='
insert into checkin_escalations (id, elder_id, date)
values ('ffffffff-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date);
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
update checkin_escalations set handled_by = '22222222-2222-2222-2222-222222222222', handled_at = now()
where id = 'ffffffff-0000-0000-0000-000000000002';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 30: a booking-linked timeline event is visible to the assigned caregiver — expect 1 ==='
insert into elder_timeline_events (id, elder_id, event_type, category, related_booking_id, summary)
values ('ffffffff-0000-0000-0000-000000000003', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'visit_completed', 'visit_history', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Visit completed');
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select count(*) as visible_events from elder_timeline_events where id = 'ffffffff-0000-0000-0000-000000000003';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 31: a stranger cannot see that timeline event — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_events from elder_timeline_events where id = 'ffffffff-0000-0000-0000-000000000003';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 32: elder makes daughter the family coordinator — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update family_links set coordinator = true
where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and family_user_id = '22222222-2222-2222-2222-222222222222';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 33: a family member cannot revoke their own coordinator status — expect an RLS/trigger ERROR, not a silent success ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
update family_links set coordinator = false
where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and family_user_id = '22222222-2222-2222-2222-222222222222';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 33b: confirm it truly did not change — expect true ==='
select coordinator from family_links
where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and family_user_id = '22222222-2222-2222-2222-222222222222';

\echo '=== TEST 34: share_family_list defaults off — a second family member cannot see the daughter''s family_links row — expect 0 ==='
insert into auth.users (id, email) values
  ('66666666-6666-6666-6666-666666666666', 'second-sibling@test.com');
insert into profiles (id, role, phone, display_name) values
  ('66666666-6666-6666-6666-666666666666', 'family_member', '+916', 'Second Sibling');
insert into family_links (elder_id, family_user_id, relationship, status, invited_by) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '66666666-6666-6666-6666-666666666666', 'son', 'active', '11111111-1111-1111-1111-111111111111');
set role authenticated;
set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
select count(*) as visible_links from family_links where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and family_user_id = '22222222-2222-2222-2222-222222222222';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 35: elder opts in to share_family_list — second family member can now see all links — expect 2 ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update elder_profiles set share_family_list = true where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;
set role authenticated;
set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
select count(*) as visible_links from family_links where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

-- ===================================================================
-- 0009_checkin_timeline_trigger.sql: TEST 23's check-in should have
-- produced a matching elder_timeline_events row automatically, since
-- daily_checkins has no client-insert path into that table (see 0009's
-- comment) — found while building the Timeline screen on top of this.
-- ===================================================================

\echo '=== TEST 36: TEST 23''s check-in produced a checkin_completed timeline row, visible to the elder — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select count(*) as visible_events from elder_timeline_events
where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and event_type = 'checkin_completed';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 37: daughter, already granted wellbeing_checkins consent in TEST 26, can see it too — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_events from elder_timeline_events
where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and event_type = 'checkin_completed';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 38: a stranger still cannot see it — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_events from elder_timeline_events
where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and event_type = 'checkin_completed';
reset role;
reset request.jwt.claim.sub;
