-- ============================================================================
-- Memory Lane
-- ----------------------------------------------------------------------------
-- "Would you like to see some photos from your 1985 Shimla trip?"
--
-- Not a third photo screen. SETU Memories already holds the material and the
-- Timeline already shows recent days; Memory Lane is the act of reaching back
-- into that and *offering* something, in a sentence, unprompted. Reminiscence
-- prompting is established practice in dementia and low-mood care, and the
-- difference between it and a photo gallery is entirely that somebody asks.
--
-- The only thing this needs that does not already exist is a record of what
-- was declined, and that is the whole point of this migration.
--
-- An elder must be able to say "not now" and have it stick. The memories in
-- here are not neutral content — a spouse who has died, a house that was sold,
-- a child who no longer visits. A prompt that keeps returning because the
-- algorithm noticed it got a reaction is the cruellest thing this app could
-- do, and "engagement" is exactly the metric that would justify it.
-- ============================================================================

create table if not exists memory_dismissals (
  id uuid primary key default gen_random_uuid(),
  memory_id uuid not null references setu_memories (id) on delete cascade,
  -- Who dismissed it. An elder saying "not now" and a family member skipping
  -- past on their own dashboard are different acts, and only the elder's
  -- should silence it for the elder.
  profile_id uuid not null references profiles (id) on delete cascade,
  -- 'later' comes back after a while; 'never' does not come back at all.
  -- Two levels rather than one because "not just now" and "never show me this
  -- again" are genuinely different, and collapsing them into a single Dismiss
  -- button forces people to either over- or under-state what they meant.
  scope text not null default 'later' check (scope in ('later', 'never')),
  dismissed_at timestamptz not null default now(),
  unique (memory_id, profile_id)
);

create index if not exists memory_dismissals_profile_idx
  on memory_dismissals (profile_id, memory_id);

alter table memory_dismissals enable row level security;

drop policy if exists memory_dismissals_own on memory_dismissals;
create policy memory_dismissals_own on memory_dismissals
  for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

comment on table memory_dismissals is
  'What a person asked not to be shown again. Exists so "not now" means
   something: these memories are not neutral content, and a prompt that keeps
   returning because it got a reaction is the cruellest thing this app could
   do.';

-- ---------------------------------------------------------------------------
-- One memory worth offering, or nothing.
--
-- Returns at most one row, deliberately. Memory Lane is a question, not a
-- feed — the moment it becomes a scrollable list it is the Memories screen
-- again, and the thing that made it worth building is gone.
--
-- Only reaches back beyond a month. A photo from last Tuesday is not
-- reminiscence, it is the Timeline.
-- ---------------------------------------------------------------------------
create or replace function memory_lane_pick(p_elder_id uuid)
returns table (
  id uuid,
  memory_date date,
  summary text,
  highlights jsonb,
  mood text
)
language sql
stable
security definer
set search_path = public
as $$
  select m.id, m.memory_date, m.summary, m.highlights, m.mood
    from setu_memories m
   where m.elder_id = p_elder_id
     and (is_elder_self(p_elder_id) or is_linked_family(p_elder_id) or is_admin())
     and m.memory_date < current_date - interval '30 days'
     and not exists (
       select 1 from memory_dismissals d
        where d.memory_id = m.id
          and d.profile_id = auth.uid()
          and (d.scope = 'never'
               or d.dismissed_at > now() - interval '60 days')
     )
   -- Oldest first, with a little randomness so the same memory is not the
   -- answer every single day. Not weighted by anything resembling engagement:
   -- see the table comment.
   order by m.memory_date asc, random()
   limit 1;
$$;

revoke all on function memory_lane_pick(uuid) from public;
grant execute on function memory_lane_pick(uuid) to authenticated;

comment on function memory_lane_pick(uuid) is
  'At most one memory older than a month that the caller has not dismissed.
   One row on purpose — Memory Lane is a question, not a feed.';
