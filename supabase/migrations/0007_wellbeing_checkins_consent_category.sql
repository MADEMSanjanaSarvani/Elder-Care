-- Adds the wellbeing_checkins consent category, needed by Daily Check-ins
-- System (docs/prd/04-prd-part4-family-experience.html, Module 3). Kept as
-- its own migration, separate from anything that references the new value
-- (0008_family_experience.sql) — Postgres cannot use a newly added enum
-- value in the same transaction that added it, and this repo's migration
-- runner may wrap each file in one transaction. Splitting the ALTER TYPE
-- into its own file guarantees it's committed before anything uses it,
-- regardless of how the runner behaves.
--
-- Distinct from visit_history on purpose: an elder might reasonably share
-- daily wellbeing broadly while keeping detailed visit/health history more
-- restricted, or the reverse — this is a genuinely separate data category,
-- not sprawl for its own sake (see the PRD doc for the full reasoning).

alter type consent_category add value 'wellbeing_checkins';
