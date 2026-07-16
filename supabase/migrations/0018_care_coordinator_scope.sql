-- Batch 6 (docs/prd/09-prd-part9-business-layer.html), enum-only migration.
--
-- One additive admin_scope value for the Managed Elder Care coordinator
-- role (Module 22). Split into its own file, committed before 0019
-- references it, for the same reason 0007/0015 were split: `alter type
-- ... add value` can't be used in the same transaction that references
-- the new value. The existing five scopes don't describe this role.
alter type admin_scope add value 'care_coordinator';
