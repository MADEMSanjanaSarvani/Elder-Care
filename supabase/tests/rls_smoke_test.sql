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

-- ===================================================================
-- Batch 2 (docs/prd/05-prd-part5-care-logistics.html): Medicine
-- Management, Medicine Refill Management, Appointment Management,
-- Smart Reminder System.
-- ===================================================================

insert into elder_medications (id, elder_id, name, dosage, schedule, added_by) values
  ('eeeeeeee-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Metformin', '500mg', '{}'::jsonb, '11111111-1111-1111-1111-111111111111');

insert into medication_stock (medication_id, quantity_on_hand, unit, refill_threshold) values
  ('eeeeeeee-1111-1111-1111-111111111111', 30, 'tablets', 5);

-- A second, clinical caregiver with an in-progress booking, to exercise
-- the marked_via = 'caregiver_clinical' write path.
insert into auth.users (id, email) values
  ('77777777-7777-7777-7777-777777777777', 'nurse@test.com');
insert into profiles (id, role, phone, display_name) values
  ('77777777-7777-7777-7777-777777777777', 'caregiver', '+917', 'Nurse Priya');
insert into caregivers (id, region_id, user_id, caregiver_type, sub_role, trust_tier, bgv_status, police_verification_status, professional_council_reg_no)
select '88888888-8888-8888-8888-888888888888', id, '77777777-7777-7777-7777-777777777777', 'clinical', 'nurse', 'clinical_verified', 'cleared', 'cleared', 'TN-NUR-12345'
from regions where code = 'vizag-ap-in';
insert into bookings (id, region_id, elder_id, requested_by, caregiver_id, service_id, required_trust_tier, status, scheduled_at)
select '99999999-9999-9999-9999-999999999999', r.id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       '22222222-2222-2222-2222-222222222222', '88888888-8888-8888-8888-888888888888',
       sc.id, 'clinical_verified', 'in_progress', now()
from regions r join service_catalog sc on sc.region_id = r.id and sc.code = 'home_nursing'
where r.code = 'vizag-ap-in';

\echo '=== TEST 39: elder marks their own dose taken — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into medication_doses (id, medication_id, scheduled_at, taken_at, status, marked_by, marked_via)
values ('eeeeeeee-2222-2222-2222-222222222222', 'eeeeeeee-1111-1111-1111-111111111111', now(), now(), 'taken', '11111111-1111-1111-1111-111111111111', 'elder_self');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 40: the trigger decremented stock from 30 to 29 — expect 29 ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select quantity_on_hand from medication_stock where medication_id = 'eeeeeeee-1111-1111-1111-111111111111';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 41: a stranger cannot see the dose — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_doses from medication_doses where id = 'eeeeeeee-2222-2222-2222-222222222222';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 42: daughter without medication_list consent cannot see the dose — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_doses from medication_doses where id = 'eeeeeeee-2222-2222-2222-222222222222';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 43: elder grants medication_list consent, daughter can now see the dose — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into consent_grants (elder_id, family_user_id, category, granted, granted_via, granted_at)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'medication_list', true, 'elder_app', now());
reset role;
reset request.jwt.claim.sub;
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_doses from medication_doses where id = 'eeeeeeee-2222-2222-2222-222222222222';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 44: daughter (has medication_list consent, but is not the assigned caregiver) cannot mark a dose caregiver_clinical even against a real in-progress clinical booking — expect an RLS ERROR ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into medication_doses (medication_id, scheduled_at, status, marked_by, marked_via, related_booking_id)
values ('eeeeeeee-1111-1111-1111-111111111111', now(), 'taken', '22222222-2222-2222-2222-222222222222', 'caregiver_clinical', '99999999-9999-9999-9999-999999999999');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 45: the actual assigned clinical caregiver CAN mark the dose administered — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
insert into medication_doses (id, medication_id, scheduled_at, status, marked_by, marked_via, related_booking_id, administered_note)
values ('eeeeeeee-3333-3333-3333-333333333333', 'eeeeeeee-1111-1111-1111-111111111111', now(), 'taken', '77777777-7777-7777-7777-777777777777', 'caregiver_clinical', '99999999-9999-9999-9999-999999999999', 'Administered with breakfast.');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 46: a non-clinical caregiver on a merely "matched" (not in-progress) non-clinical booking cannot claim caregiver_clinical — expect an RLS ERROR ==='
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
insert into medication_doses (medication_id, scheduled_at, status, marked_by, marked_via, related_booking_id)
values ('eeeeeeee-1111-1111-1111-111111111111', now(), 'taken', '44444444-4444-4444-4444-444444444444', 'caregiver_clinical', 'cccccccc-cccc-cccc-cccc-cccccccccccc');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 47: daughter creates an appointment for the elder — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into appointments (id, elder_id, title, location, scheduled_at, created_by)
values ('eeeeeeee-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Cardiology follow-up', 'Apollo Hospital, Vizag', now() + interval '3 days', '22222222-2222-2222-2222-222222222222');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 48: second sibling (linked family, no visit_history consent) cannot see it — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
select count(*) as visible_appointments from appointments where id = 'eeeeeeee-4444-4444-4444-444444444444';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 49: elder grants second sibling visit_history consent — now visible — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into consent_grants (elder_id, family_user_id, category, granted, granted_via, granted_at)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '66666666-6666-6666-6666-666666666666', 'visit_history', true, 'elder_app', now());
reset role;
reset request.jwt.claim.sub;
set role authenticated;
set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
select count(*) as visible_appointments from appointments where id = 'eeeeeeee-4444-4444-4444-444444444444';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 50: an appointment linked to a booking is visible to that booking''s assigned caregiver — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into appointments (id, elder_id, title, related_booking_id, scheduled_at, created_by)
values ('eeeeeeee-5555-5555-5555-555555555555', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Physio session, companion booked', 'cccccccc-cccc-cccc-cccc-cccccccccccc', now() + interval '5 days', '11111111-1111-1111-1111-111111111111');
reset role;
reset request.jwt.claim.sub;
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select count(*) as visible_appointments from appointments where id = 'eeeeeeee-5555-5555-5555-555555555555';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 50b: a stranger still cannot see that same appointment — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_appointments from appointments where id = 'eeeeeeee-5555-5555-5555-555555555555';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 51: no client insert policy on reminders — a family member attempting to write one directly gets an RLS ERROR ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into reminders (elder_id, source_type, source_id, remind_at, recipient_scope)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'medication_dose', 'eeeeeeee-2222-2222-2222-222222222222', now() + interval '1 hour', 'both');
reset role;
reset request.jwt.claim.sub;

-- Simulates what medications-generate-doses would do server-side
-- (service role). Note: TEST 47 and TEST 50 above already each triggered
-- a real 'appointment'-sourced reminder via trg_enqueue_appointment_reminder
-- (0011) — those are exercised for real below rather than duplicated with
-- a synthetic insert.
insert into reminders (id, elder_id, source_type, source_id, remind_at, recipient_scope) values
  ('eeeeeeee-6666-6666-6666-666666666666', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'medication_dose', 'eeeeeeee-2222-2222-2222-222222222222', now() + interval '1 hour', 'both');

\echo '=== TEST 52: the elder sees every reminder regardless of source type — expect 3 (the seeded medication_dose one, plus the two real appointment ones auto-enqueued by TEST 47 and TEST 50) ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select count(*) as visible_reminders from reminders where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 53: daughter (medication_list consent only, no visit_history) sees exactly the medication-sourced reminder — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_reminders from reminders where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 54: elder snoozes a reminder — expect success, status now snoozed ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update reminders set status = 'snoozed', snoozed_until = now() + interval '1 day'
where id = 'eeeeeeee-6666-6666-6666-666666666666';
select status from reminders where id = 'eeeeeeee-6666-6666-6666-666666666666';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 55: a stranger cannot see any of this elder''s reminders, and an attempt to dismiss all of them is a silent no-op (0 rows), not a bypass — expect 0 visible, 0 rows updated, 0 actually dismissed ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_reminders from reminders where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
update reminders set status = 'dismissed' where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;
select count(*) as dismissed_count from reminders where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and status = 'dismissed';

-- ===================================================================
-- 0011_appointment_reminder_trigger.sql: the appointment -> reminder
-- enqueue trigger itself, found while wiring Smart Reminder System —
-- the Batch 2 PRD's own appointments schema never defined a
-- reminder_lead_time column despite the functional requirements
-- mentioning one, so nothing could enqueue an appointment reminder at all
-- without this migration.
-- ===================================================================

\echo '=== TEST 56: rescheduling TEST 47''s appointment cancels its old pending reminder and creates exactly one new one — expect 1 pending, 1 cancelled ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
update appointments set scheduled_at = now() + interval '10 days' where id = 'eeeeeeee-4444-4444-4444-444444444444';
reset role;
reset request.jwt.claim.sub;
select
  count(*) filter (where status = 'pending') as pending_count,
  count(*) filter (where status = 'cancelled') as cancelled_count
from reminders where source_type = 'appointment' and source_id = 'eeeeeeee-4444-4444-4444-444444444444';

\echo '=== TEST 57: cancelling the appointment cancels its pending reminder too — expect 0 pending, 2 cancelled ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
update appointments set status = 'cancelled' where id = 'eeeeeeee-4444-4444-4444-444444444444';
reset role;
reset request.jwt.claim.sub;
select
  count(*) filter (where status = 'pending') as pending_count,
  count(*) filter (where status = 'cancelled') as cancelled_count
from reminders where source_type = 'appointment' and source_id = 'eeeeeeee-4444-4444-4444-444444444444';

-- ===================================================================
-- 0012_medication_discontinue_trigger.sql: found while building the
-- medications screen — the PRD's functional requirements for
-- discontinuing a medication (cancel pending doses, log a timeline
-- event) were never wired up as a side effect anywhere in 0010.
-- ===================================================================

insert into medication_doses (id, medication_id, scheduled_at, status)
values ('eeeeeeee-8888-8888-8888-888888888888', 'eeeeeeee-1111-1111-1111-111111111111', now() + interval '1 day', 'pending');

\echo '=== TEST 58: elder discontinues the medication — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update elder_medications set active = false where id = 'eeeeeeee-1111-1111-1111-111111111111';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 59: the pending future dose was cancelled, not left dangling — expect cancelled ==='
select status from medication_doses where id = 'eeeeeeee-8888-8888-8888-888888888888';

\echo '=== TEST 60: a medication_stopped timeline event was written — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select count(*) as stopped_events from elder_timeline_events
where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and event_type = 'medication_stopped';
reset role;
reset request.jwt.claim.sub;

-- ===================================================================
-- Batch 3 (docs/prd/06-prd-part6-visits-and-records.html): Family
-- Notification Center, Companion Visits, Hospital Companion Services,
-- Health Records Management.
-- ===================================================================

\echo '=== TEST 61: daughter cannot disable a must-deliver notification type — expect an RLS/trigger ERROR ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into notification_preferences (user_id, type, channel, enabled)
values ('22222222-2222-2222-2222-222222222222', 'sos_triggered', 'push', false);
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 62: daughter CAN disable an ordinary notification type — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into notification_preferences (user_id, type, channel, enabled)
values ('22222222-2222-2222-2222-222222222222', 'family_invite_sent', 'in_app', false);
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 63: a stranger cannot see daughter''s notification preferences — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_prefs from notification_preferences where user_id = '22222222-2222-2222-2222-222222222222';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 64: elder sets a companion visit preference — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into companion_visit_preferences (elder_id, preferred_caregiver_id, interests)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '["walking", "cards"]'::jsonb);
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 65: a stranger cannot see the elder''s companion visit preference — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_prefs from companion_visit_preferences where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

insert into bookings (id, region_id, elder_id, requested_by, caregiver_id, service_id, required_trust_tier, status, scheduled_at)
select 'cccccccc-1111-1111-1111-111111111111', r.id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
       sc.id, 'standard', 'in_progress', now()
from regions r join service_catalog sc on sc.region_id = r.id and sc.code = 'companionship_visit'
where r.code = 'vizag-ap-in';

insert into bookings (id, region_id, elder_id, requested_by, caregiver_id, service_id, required_trust_tier, status, scheduled_at)
select 'cccccccc-2222-2222-2222-222222222222', r.id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
       '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
       sc.id, 'standard', 'in_progress', now()
from regions r join service_catalog sc on sc.region_id = r.id and sc.code = 'hospital_companion'
where r.code = 'vizag-ap-in';

\echo '=== TEST 66: the caregiver assigned to an in-progress companion visit can log its activity — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
insert into visit_activity_logs (booking_id, activities, caregiver_observed_mood)
values ('cccccccc-1111-1111-1111-111111111111', '["walked", "read_together"]'::jsonb, 'content');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 67: a caregiver NOT assigned to that booking cannot log its activity — expect an RLS ERROR ==='
set role authenticated;
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
insert into visit_activity_logs (booking_id, activities)
values ('cccccccc-2222-2222-2222-222222222222', '["played_cards"]'::jsonb);
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 68: daughter, without visit_history consent yet, cannot see the activity log even though she requested the booking — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_logs from visit_activity_logs where booking_id = 'cccccccc-1111-1111-1111-111111111111';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 69: elder grants daughter visit_history consent — she can now see it — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into consent_grants (elder_id, family_user_id, category, granted, granted_via, granted_at)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'visit_history', true, 'elder_app', now());
reset role;
reset request.jwt.claim.sub;
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_logs from visit_activity_logs where booking_id = 'cccccccc-1111-1111-1111-111111111111';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 70: daughter creates a hospital stay for the elder — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into hospital_stays (id, elder_id, hospital_name, admission_at, created_by)
values ('11112222-1111-2222-1111-222211112222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Apollo Hospital', now(), '22222222-2222-2222-2222-222222222222');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 71: both shifts are linked to the stay — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into hospital_stay_bookings (hospital_stay_id, booking_id, shift_note) values
  ('11112222-1111-2222-1111-222211112222', '99999999-9999-9999-9999-999999999999', null),
  ('11112222-1111-2222-1111-222211112222', 'cccccccc-2222-2222-2222-222222222222', 'Patient resting, vitals stable.');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 72: the clinical caregiver (on a DIFFERENT shift in the same stay) can read the other shift''s handoff note — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
select count(*) as visible_notes from hospital_stay_bookings
where hospital_stay_id = '11112222-1111-2222-1111-222211112222' and booking_id = 'cccccccc-2222-2222-2222-222222222222';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 73: that same caregiver CAN write a handoff note for their own shift — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
update hospital_stay_bookings set shift_note = 'Nurse handoff: medication given at 14:00.'
where hospital_stay_id = '11112222-1111-2222-1111-222211112222' and booking_id = '99999999-9999-9999-9999-999999999999';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 74: but CANNOT write a handoff note for the other caregiver''s shift — expect an RLS no-op, 0 rows updated ==='
set role authenticated;
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
update hospital_stay_bookings set shift_note = 'overwritten'
where hospital_stay_id = '11112222-1111-2222-1111-222211112222' and booking_id = 'cccccccc-2222-2222-2222-222222222222';
reset role;
reset request.jwt.claim.sub;
select shift_note from hospital_stay_bookings
where hospital_stay_id = '11112222-1111-2222-1111-222211112222' and booking_id = 'cccccccc-2222-2222-2222-222222222222';

\echo '=== TEST 75: a stranger cannot see any shift note in the stay — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_notes from hospital_stay_bookings where hospital_stay_id = '11112222-1111-2222-1111-222211112222';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 76: second sibling (visit_history consent from TEST 49) can see the hospital stay itself — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
select count(*) as visible_stays from hospital_stays where id = '11112222-1111-2222-1111-222211112222';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 77: elder sets their own health profile — expect success ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into elder_health_profile (elder_id, blood_type, allergies, emergency_medical_notes, updated_by)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'O+', '["penicillin"]'::jsonb, 'No DNR on file.', '11111111-1111-1111-1111-111111111111');
insert into elder_administrative_profile (elder_id, primary_physician_name, insurance_policy_number, updated_by)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Dr. Rao', 'POLICY-12345', '11111111-1111-1111-1111-111111111111');
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 78: the caregiver on an in-progress booking can read the health profile without any consent grant — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
select count(*) as visible_profiles from elder_health_profile where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

insert into auth.users (id, email) values ('dddddddd-1111-1111-1111-111111111111', 'uninvolved-caregiver@test.com');
insert into profiles (id, role, phone, display_name) values ('dddddddd-1111-1111-1111-111111111111', 'caregiver', '+918', 'Uninvolved Caregiver');
insert into caregivers (id, region_id, user_id, caregiver_type, sub_role, trust_tier, bgv_status, police_verification_status)
select 'dddddddd-2222-2222-2222-222222222222', id, 'dddddddd-1111-1111-1111-111111111111', 'non_clinical', 'companion', 'standard', 'cleared', 'cleared'
from regions where code = 'vizag-ap-in';

\echo '=== TEST 79: a totally uninvolved caregiver (no booking, no SOS response) cannot read the health profile — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = 'dddddddd-1111-1111-1111-111111111111';
select count(*) as visible_profiles from elder_health_profile where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 80: even the in-progress-booking caregiver can NEVER read the administrative profile — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
select count(*) as visible_admin_profiles from elder_administrative_profile where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

insert into sos_events (id, elder_id, triggered_by, status, responder_caregiver_id)
values ('11119999-1111-9999-1111-999911119999', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'responder_dispatched', 'dddddddd-2222-2222-2222-222222222222');

\echo '=== TEST 81: the dispatched SOS responder can now read the health profile too, with no booking at all — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = 'dddddddd-1111-1111-1111-111111111111';
select count(*) as visible_profiles from elder_health_profile where elder_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
reset request.jwt.claim.sub;

-- ===================================================================
-- 0014_hospital_stay_gap_reminders.sql: the hospital_stay_gap source
-- type registered with the shared reminder engine's consent mapping —
-- without it, required_consent_for_source() returns null (fail-closed)
-- and no family member could ever see a coverage-gap reminder.
-- ===================================================================

-- Simulates what hospital-stays-gap-sweep would do server-side.
insert into reminders (id, elder_id, source_type, source_id, remind_at, recipient_scope) values
  ('11113333-1111-3333-1111-333311113333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'hospital_stay_gap', '11112222-1111-2222-1111-222211112222', now(), 'family');

\echo '=== TEST 82: daughter (visit_history consent from TEST 69) can see the coverage-gap reminder — expect 1 ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) as visible_gap_reminders from reminders where id = '11113333-1111-3333-1111-333311113333';
reset role;
reset request.jwt.claim.sub;

\echo '=== TEST 83: a stranger cannot — expect 0 ==='
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select count(*) as visible_gap_reminders from reminders where id = '11113333-1111-3333-1111-333311113333';
reset role;
reset request.jwt.claim.sub;
