-- Batch 4 database layer: AI Visit Reports, AI Recommendation Engine
-- (docs/prd/07-prd-part7-ai-layer.html). AI Care Assistant (Module 13)
-- and Voice Assistant (Module 16) add no tables — the first is a
-- conversational front end over existing RLS-scoped queries, the second
-- a pure modality converter. Both are Edge-Function / client work only.
--
-- Fully additive beyond the three enum values already added in 0015: two
-- new tables, one helper function, no existing table or policy touched,
-- no new consent category (both tables reuse existing categories).

-- ---------------------------------------------------------------------
-- Module 14: AI Visit Reports
--
-- A periodic (e.g. weekly) plain-language digest of what already happened
-- and already passed the guardrail once — never raw clinical text. Stored
-- once when generated, not regenerated on every view. Same
-- self/consent/admin visibility shape as ai_interactions.
-- ---------------------------------------------------------------------

create table ai_visit_reports (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  period_start date not null,
  period_end date not null,
  report_text text not null,
  -- Same guardrail bookkeeping as ai_interactions: a flagged report is
  -- held for admin review, never shown to family until human_reviewed.
  flagged boolean not null default false,
  human_reviewed boolean not null default false,
  generated_at timestamptz not null default now()
);

alter table ai_visit_reports enable row level security;

-- Mirrors ai_interactions_select's health_notes-gated family visibility,
-- plus a flagged-hold rule that is deliberately stricter than raw-data
-- access: a flagged, not-yet-reviewed report is admin-only — withheld
-- even from the elder themselves, not just family. This is intentional
-- and worth stating: a flagged AI report is a machine-generated draft
-- that failed the guardrail (it may contain exactly the hallucinated
-- diagnosis the guardrail exists to catch), so "never delivered until
-- reviewed" has to mean to *any* end user, not only family — otherwise
-- the elder becomes the one person who can be shown unsafe AI output. It
-- is unlike raw elder data (health notes, medications), which the elder
-- always sees, precisely because that data is real, not a possibly-unsafe
-- generation. Matches how ai-visit-summary already holds flagged output
-- out of delivery until the admin AI review queue clears it.
create policy ai_visit_reports_select on ai_visit_reports for select to authenticated
  using (
    (
      (is_elder_self(elder_id) or (is_linked_family(elder_id) and has_consent(elder_id, auth.uid(), 'health_notes')))
      and (flagged = false or human_reviewed = true)
    )
    or is_admin()
  );
-- No insert/update policy for `authenticated` — every row is written and
-- cleared-for-delivery by an Edge Function via the service-role client,
-- same as ai_interactions.

create index idx_ai_visit_reports_elder_period on ai_visit_reports (elder_id, period_end desc);

-- ---------------------------------------------------------------------
-- Module 15: AI Recommendation Engine
--
-- A rules engine, not a language model deciding outcomes (PRD §10). Every
-- suggestion is a closed, enumerated type fired by a deterministic
-- condition over structured data; the trigger_metric records exactly
-- which data point fired it, for auditability. Any natural-language
-- phrasing is an optional LLM step wording an already-decided, already-
-- safe suggestion — and even that passes the same guardrail.
-- ---------------------------------------------------------------------

create type care_suggestion_status as enum ('pending', 'dismissed', 'acted_on');

create table care_suggestions (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  -- Closed, enumerated set — enforced by the check constraint below and
  -- by required_consent_for_suggestion() knowing every value. Adding a
  -- new suggestion type is a deliberate two-place change (here + the
  -- helper), never a freeform string, exactly so a type can never exist
  -- without a defined consent mapping (which would fail closed anyway).
  suggestion_type text not null check (suggestion_type in (
    'no_recent_visit',
    'medication_adherence_low',
    'refill_due_soon',
    'checkin_streak_broken',
    'appointment_without_companion'
  )),
  -- The specific data point(s) that fired the rule — mandatory, so every
  -- suggestion is explainable after the fact, never an opaque AI hunch.
  trigger_metric jsonb not null default '{}'::jsonb,
  suggestion_text text not null,
  status care_suggestion_status not null default 'pending',
  created_at timestamptz not null default now()
);

-- Maps a suggestion type to the consent category it implies — the same
-- consent-mapping-by-source approach as reminders' required_consent_for_source
-- (Batch 2). Returns null for an unrecognized type, and the RLS policy
-- treats null as deny (fail-closed), so a suggestion type can never be
-- visible to family without a deliberate mapping entry here.
create or replace function required_consent_for_suggestion(suggestion_type text)
returns consent_category
language sql immutable as $$
  select case suggestion_type
    when 'no_recent_visit' then 'visit_history'::consent_category
    when 'appointment_without_companion' then 'visit_history'::consent_category
    when 'medication_adherence_low' then 'medication_list'::consent_category
    when 'refill_due_soon' then 'medication_list'::consent_category
    when 'checkin_streak_broken' then 'wellbeing_checkins'::consent_category
    else null
  end;
$$;

alter table care_suggestions enable row level security;

-- No insert policy for `authenticated` — written by the (service-role)
-- recommendation sweep. Family visibility is consent-mapped per type.
create policy care_suggestions_select on care_suggestions for select to authenticated
  using (
    is_elder_self(elder_id)
    or is_admin()
    or (
      required_consent_for_suggestion(suggestion_type) is not null
      and has_consent(elder_id, auth.uid(), required_consent_for_suggestion(suggestion_type))
    )
  );
-- Dismiss / mark acted-on only. Same self/consent/admin set as select;
-- the app updates status only, the same looser convention already used
-- for reminders and checkin_escalations.
create policy care_suggestions_update on care_suggestions for update to authenticated
  using (
    is_elder_self(elder_id)
    or is_admin()
    or (
      required_consent_for_suggestion(suggestion_type) is not null
      and has_consent(elder_id, auth.uid(), required_consent_for_suggestion(suggestion_type))
    )
  )
  with check (
    is_elder_self(elder_id)
    or is_admin()
    or (
      required_consent_for_suggestion(suggestion_type) is not null
      and has_consent(elder_id, auth.uid(), required_consent_for_suggestion(suggestion_type))
    )
  );

create index idx_care_suggestions_elder_status on care_suggestions (elder_id, status);
