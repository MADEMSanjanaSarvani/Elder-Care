-- ============================================================================
-- Where to take her
-- ----------------------------------------------------------------------------
-- The emergency medical profile shows blood group, allergies, conditions,
-- medicines and who to call. It does not say which hospital, and that is the
-- second question every paramedic and every arriving caregiver asks after
-- "what happened".
--
-- It was left out for a good reason at the time: the design showed a
-- "Preferred Hospital" card and SETU had nowhere to put one, so inventing it
-- would have meant fabricating a hospital. That reason expired when 0029 and
-- 0030 built the clinic directory. There is now a real table of real
-- facilities to point at.
--
-- Two columns rather than one. A family whose parent is registered at a
-- hospital SETU has imported gets a proper reference; a family whose hospital
-- is not in the directory yet can still type it in, because "we don't have
-- that clinic in our database" is SETU's problem and must never become a
-- reason an ambulance goes to the wrong place.
--
-- These live on elder_health_profile rather than the administrative one on
-- purpose: the split is emergency-relevant vs. never-caregiver-visible, and
-- this is the definition of emergency-relevant. It is disclosed with the rest
-- of the medical ID when an SOS fires.
-- ============================================================================

alter table elder_health_profile
  add column if not exists preferred_hospital_id uuid
    references doctors (id) on delete set null,
  -- Free text, used when the hospital isn't in the directory. Also holds the
  -- ward or department when that matters ("KIMS, cardiology — Dr Rao's team").
  add column if not exists preferred_hospital_note text;

comment on column elder_health_profile.preferred_hospital_id is
  'A facility from the clinic directory, when SETU has it. Nullable and
   paired with preferred_hospital_note so a family whose hospital has not
   been imported yet can still record one — a gap in our directory must
   never be a reason an ambulance goes to the wrong place.';
comment on column elder_health_profile.preferred_hospital_note is
  'Free text hospital, ward or department. Shown alongside the linked
   facility rather than instead of it, because "KIMS, cardiology" is more
   useful to a paramedic than either half alone.';
