-- ============================================================================
-- Cancelling an SOS
-- ----------------------------------------------------------------------------
-- The emergency button had no undo.
--
-- A pocket-press, a grandchild playing with the phone, a shaky hand on the
-- wrong tile — and the alert fans out to every family member and the on-call
-- operator, with no way to say "sorry, I'm fine". People then drive across
-- Visakhapatnam in the dark for nothing, and the next time an alert arrives
-- they trust it a little less. An emergency system that cries wolf and cannot
-- retract is worse than one that is slightly harder to trigger.
--
-- 'cancelled' is its own status rather than reusing 'resolved' because the two
-- mean opposite things to whoever reads the SOS monitor next: 'resolved' says
-- something happened and it was dealt with, 'cancelled' says nothing happened
-- at all. Collapsing them would quietly inflate every incident statistic SETU
-- ever reports, and would leave an operator unable to tell a real call from a
-- pocket.
-- ============================================================================

alter type sos_status add value if not exists 'cancelled';

comment on type sos_status is
  'triggered → family_notified → responder_dispatched → resolved is the live
   path. cancelled is a terminal state off to the side, meaning the alert was
   raised in error — kept distinct from resolved so incident counts and the
   operator queue never confuse a false alarm with a real call.';
