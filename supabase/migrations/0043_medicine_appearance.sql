-- What the tablet actually looks like.
--
-- People do not identify their medicines by name. They identify them as "the
-- small white one" and "the big yellow capsule" — which is also how they get
-- them wrong. CareHive has been showing a name and a dosage string, both of
-- which are exactly what somebody with four long-term prescriptions cannot
-- reliably match to the strip in their hand.
--
-- So a medicine can carry its own appearance, and the Today card can show the
-- tablet next to the time. This is not decoration: taking the wrong one of
-- four look-alike white tablets is the failure mode that a medicine reminder
-- app should most want to prevent, and the app currently offers no help at all.
--
-- Both columns are nullable and neither is inferred. There is no database of
-- what any given drug looks like — the same generic ships in different colours
-- from different manufacturers — so guessing here would be worse than the blank
-- we have now. Only the person holding the box can say, and if they don't, the
-- card falls back to a neutral outline.
--
-- Stored as tokens rather than hex so the app owns the rendering: it keeps the
-- swatches inside the palette that has been contrast-checked, and stops a
-- free-form colour picker producing a pale yellow pill nobody can see.

alter table elder_medications
  add column if not exists pill_color text
    check (pill_color in (
      'white','yellow','orange','red','pink','purple','blue','green','brown'
    )),
  add column if not exists pill_shape text
    check (pill_shape in ('round','oval','capsule','oblong'));

comment on column elder_medications.pill_color is
  'Token from a fixed set, never a hex value — the app maps it to a rendered
   swatch so every colour stays legible. Null means the person did not say.';

comment on column elder_medications.pill_shape is
  'round | oval | capsule | oblong. Null means the person did not say.';
