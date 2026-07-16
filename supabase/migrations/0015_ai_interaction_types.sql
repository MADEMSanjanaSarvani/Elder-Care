-- Batch 4 (docs/prd/07-prd-part7-ai-layer.html), enum-only migration.
--
-- Three additive values on the existing ai_interaction_type enum, the
-- only touch to an already-implemented table in this whole batch (PRD's
-- cross-cutting section). Split into its own file, committed before
-- 0016 references any of them, for the same reason 0007 was split from
-- 0008: `alter type ... add value` cannot be used in the same
-- transaction that later references the new value.
--
-- The existing four values (visit_summary, translation, reminder,
-- scheduling_assist) don't describe these three new interaction shapes
-- precisely enough for meaningful audit/QA — conflating them would blur
-- exactly what happened in a given AI interaction, defeating the point
-- of logging it at all.

alter type ai_interaction_type add value 'care_assistant_chat';
alter type ai_interaction_type add value 'periodic_report';
alter type ai_interaction_type add value 'suggestion_phrasing';
