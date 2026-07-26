-- ============================================================================
-- Real stories, instead of a picture of a story
-- ----------------------------------------------------------------------------
-- The wellness screen showed "The Golden River · 15 min" with a play triangle.
-- There was no Golden River. Nothing happened when you tapped it. An elder
-- pressing play on a story that does not exist learns, quickly, that this app
-- is decoration — and that lesson carries to the buttons that do matter.
--
-- On licensing: these are original retellings of tales that have been in the
-- public domain for roughly two thousand years — Panchatantra and Jataka. The
-- underlying stories are free to use, and the words here are ours, so there is
-- no translation copyright to argue about either. That is the whole reason to
-- retell rather than reproduce a specific published translation: a 1925 Ryder
-- translation is very probably fine, and "very probably fine" is not a
-- sentence worth building a catalogue on.
--
-- On audio: there is none yet, and this ships as text on purpose rather than
-- waiting. A large-type story an elder can read tonight beats a play button
-- that works after somebody records a narrator. audio_url is here for when
-- that recording happens; nothing in the app pretends it already has.
-- ============================================================================

create table if not exists stories (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  -- ISO 639-1, matching profiles.preferred_language, so the list can lead with
  -- stories in the language the elder actually reads.
  language text not null default 'en',
  -- 'panchatantra', 'jataka', ... Kept as text rather than an enum: new
  -- traditions are content, and content should not need a migration.
  tradition text,
  -- Roughly how long it takes to read aloud, in minutes. Shown so someone can
  -- pick something that fits before a nap, not as a promise.
  minutes smallint check (minutes is null or minutes between 1 and 120),
  summary text,
  body text not null,
  -- Where the tale comes from and why we may use it. Displayed, not hidden in
  -- a comment — an elder-care app that quietly appropriates folk tales is not
  -- the kind of thing SETU should be.
  attribution text not null default
    'Original retelling of a traditional public-domain tale.',
  audio_url text,
  active boolean not null default true,
  sort_order smallint not null default 100,
  created_at timestamptz not null default now()
);

create index if not exists stories_language_idx
  on stories (language, sort_order) where active;

alter table stories enable row level security;

-- Read-only reference content. No PII, nothing consent-gated — every signed-in
-- user sees the same catalogue.
drop policy if exists stories_select on stories;
create policy stories_select on stories for select to authenticated
  using (active or is_admin());

drop policy if exists stories_write_admin on stories;
create policy stories_write_admin on stories for all to authenticated
  using (is_admin()) with check (is_admin());

comment on table stories is
  'Read-aloud folk tales for the wellness screen. Original retellings of
   public-domain traditions, so there is no licence to renew and no
   translation copyright to argue about. audio_url is null until a narrator
   is actually recorded — the UI must not show a play button before then.';

-- ---------------------------------------------------------------------------
-- The starting catalogue.
--
-- Five tales, deliberately short. An elder with a shorter attention span than
-- they used to have should be able to finish one, and finishing is the point.
-- ---------------------------------------------------------------------------
insert into stories (title, language, tradition, minutes, summary, body, sort_order)
select * from (values
(
  'The Lion and the Clever Hare', 'en', 'panchatantra', 4,
  'A small hare outwits a lion who thought his strength settled everything.',
  E'In a forest at the foot of a hill there lived a lion who killed far more than he could eat. Every day the ground was littered with what he had left behind, and the animals grew fewer and more frightened.\n\nAt last they went to him together. "Great king," they said, "if you hunt as you do, soon there will be nobody left to rule. Let us send you one animal each day. You will eat without walking, and the rest of us will live."\n\nThe lion agreed, and so it was. Each morning one animal walked to the lion, and the forest was quiet.\n\nOne day the lot fell to an old hare. He went slowly. The sun rose high, and still he went slowly, and by the time he reached the lion it was afternoon and the lion was in a temper.\n\n"You are late," the lion said, "and you are small."\n\n"Both true," said the hare, "and neither my fault. Four hares set out this morning. Another lion stopped us on the road and ate three. I told him he had no right — that this forest already has a king. He laughed and said he was the real king, and told me to fetch you so he could prove it."\n\nThe lion stood up. "Take me to him."\n\nThe hare led him to an old well, deep and still. "He lives down there."\n\nThe lion looked in and saw a lion looking back at him, and roared, and the well roared back. He leapt at the impostor, and the water took him, and the forest was quiet again — but this time nobody had to walk to it.\n\nThe hare went home. He was old, and small, and none of that had mattered in the end.',
  10
),
(
  'The Monkey and the Wedge', 'en', 'panchatantra', 3,
  'A monkey who could not leave well enough alone.',
  E'A merchant was building a temple, and at midday the carpenters put down their tools and went to eat. They left a great log half split, with a wooden wedge driven in to hold the crack open.\n\nA troop of monkeys came down to play among the timbers. One of them, more curious than the rest, sat astride the log and looked at the wedge. It was loose. It was clearly meant to come out. He took hold of it with both hands and pulled.\n\nThe wedge came free. The log closed.\n\nThe other monkeys came and sat with him a while, and then went back up into the trees.\n\nIt is a small story, and it is told about monkeys, but the carpenters told it to each other about people: there is work you were not asked to do, and did not understand, and it costs more to undo than it ever cost to leave alone.',
  20
),
(
  'The Merchant and the Iron Scales', 'en', 'panchatantra', 4,
  'A man who cheated a friend, and the friend who answered in kind.',
  E'A merchant who was travelling left a set of heavy iron scales with a neighbour for safekeeping. He was gone a long while. When he came back, he asked for them.\n\n"I am sorry," said the neighbour. "The mice ate them."\n\nThe merchant thought about this. "Mice," he said. "Well. Iron is sweet, I suppose, if you are a mouse." And he went away without another word, which surprised the neighbour very much.\n\nThe next morning the merchant came back and asked whether the neighbour''s young son might come with him to the river. The boy went happily. He did not come home.\n\nBy evening the neighbour was at the merchant''s door, frantic.\n\n"A great hawk carried him off," said the merchant. "I saw it happen and could do nothing."\n\n"A hawk cannot carry a boy!"\n\n"In a country where mice eat iron," said the merchant, "a hawk can carry a boy."\n\nThey looked at each other for a long moment. Then the neighbour went and fetched the scales, and the merchant went and fetched the child, who had been sitting quite happily in a friend''s house all day, and neither of them ever mentioned it again.',
  30
),
(
  'The Monkey Who Saved the Herd', 'en', 'jataka', 4,
  'A leader who made himself the bridge.',
  E'Beside a river grew a mango tree so tall its branches reached out over the water, and its fruit was better than any fruit in the kingdom. A troop of monkeys lived in it, and their leader had told them to pick every mango that hung above the river before it ripened, so that none would ever fall in and float downstream.\n\nBut one hung hidden behind a nest of ants, and it ripened, and it fell.\n\nThe king found it in the water, tasted it, and came upriver with his archers to find the tree. He found it full of monkeys.\n\n"Shoot them," he said. "The fruit is mine."\n\nThe leader saw the archers stringing their bows. There was a second tree on the far bank, but the gap was too wide for the old and the young to jump. So he jumped it himself, carrying a long cane, and tied one end to the far tree and the other around his own waist — and the cane was a little too short, so he stretched himself across the gap and held on with his hands, and made his own body the last part of the bridge.\n\nThe troop went over him. All of them. The last few were heavy and his back gave way, and he hung there.\n\nThe king had watched the whole thing. He had the monkey brought down gently and laid on a cloth, and he sat beside him.\n\n"They walked on you," he said.\n\n"They are mine," said the monkey. "That is what it means."\n\nThe king went home and ruled differently after that.',
  40
),
(
  'The Two Travellers and the Bear', 'en', 'aesop', 2,
  'What a friend is, and when you find out.',
  E'Two men were walking a forest road together and had spent the morning promising each other that whatever happened, neither would leave the other.\n\nA bear came out of the trees.\n\nThe first man ran to a tree and climbed it and did not look down. The second was too slow and too far, so he lay flat in the road and held his breath and lay as still as anything dead.\n\nThe bear came and put its nose to his ear, and stood over him a long moment, and went away.\n\nThe first man came down. "What did it say to you? It seemed to whisper."\n\n"It gave me some advice," said the second man, picking up his bag. "It said never to travel with a friend who leaves you behind."\n\nAnd he walked on alone, which was, in the end, what he had been doing all morning.',
  50
)
) as v(title, language, tradition, minutes, summary, body, sort_order)
where not exists (select 1 from stories);
