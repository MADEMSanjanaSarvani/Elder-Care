-- ============================================================================
-- SETU Memories — a warm, human daily summary of an elder's day
-- ----------------------------------------------------------------------------
-- The emotional heart of the family experience: "Your mother took all her
-- medicines, checked in feeling happy, and had a companion visit." Generated
-- from the day's real data (doses, check-ins, visits) by the
-- setu-memories-generate function. Consent-gated the same way as wellbeing
-- check-ins, so a family member only sees it with the elder's consent.
-- ============================================================================

create table setu_memories (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references elder_profiles (id) on delete cascade,
  memory_date date not null,
  summary text not null,
  highlights jsonb not null default '[]'::jsonb,  -- [{icon, text}]
  mood text,
  generated_at timestamptz not null default now(),
  unique (elder_id, memory_date)
);

create index setu_memories_elder_idx on setu_memories (elder_id, memory_date desc);

alter table setu_memories enable row level security;

create policy setu_memories_select on setu_memories for select to authenticated
  using (
    is_elder_self(elder_id)
    or has_consent(elder_id, auth.uid(), 'wellbeing_checkins')
    or is_admin()
  );
-- Written only by the generator (service role); no direct client writes.
create policy setu_memories_admin_write on setu_memories for all to authenticated
  using (is_admin()) with check (is_admin());
