-- ============================================================================
-- Richer elder profiles and medication records
-- ----------------------------------------------------------------------------
-- Covers the Priority-1 gaps in the product review: the profile could not hold
-- a photo, gender, height or weight, and a medication was only a name, a
-- dosage string and a schedule — no picture, no pill count, no refill warning,
-- no notes.
--
-- Everything here is data the family types in or a photo they take. Vitals
-- that need a device to measure (heart rate, SpO2, sleep, steps) are
-- deliberately NOT added: a column that nothing can ever fill is worse than
-- no column, because the UI then has to invent a value or show a permanent
-- blank. Those arrive with Health Connect / wearable integration.
-- ============================================================================

-- ---------------------------------------------------------------- profile ---
alter table elder_profiles
  add column if not exists gender text
    check (gender in ('female', 'male', 'other', 'prefer_not_to_say')),
  add column if not exists photo_url text;

comment on column elder_profiles.gender is
  'Self-described. Nullable and includes prefer_not_to_say — never required to
   complete a profile.';
comment on column elder_profiles.photo_url is
  'Path in the elder-photos storage bucket. A face makes the dashboard feel
   like a person rather than a record.';

-- Height and weight sit with the health profile, not the identity record:
-- they are medical measurements, they change, and they belong under the same
-- caregiver-visibility rules as blood type and allergies.
alter table elder_health_profile
  add column if not exists height_cm numeric(5, 1)
    check (height_cm is null or (height_cm > 30 and height_cm < 260)),
  add column if not exists weight_kg numeric(5, 1)
    check (weight_kg is null or (weight_kg > 10 and weight_kg < 400));

comment on column elder_health_profile.height_cm is
  'Centimetres. Bounded to catch unit mix-ups (feet typed into a cm field).';
comment on column elder_health_profile.weight_kg is
  'Kilograms. With height this yields BMI, which is derived on read rather
   than stored — a stored BMI goes stale the moment weight changes.';

-- ------------------------------------------------------------- medication ---
alter table elder_medications
  add column if not exists photo_url text,
  add column if not exists pills_remaining integer
    check (pills_remaining is null or pills_remaining >= 0),
  add column if not exists refill_at integer
    check (refill_at is null or refill_at >= 0),
  add column if not exists notes text,
  add column if not exists prescribed_by text;

comment on column elder_medications.photo_url is
  'Photo of the strip or bottle, in the medication-photos bucket. An elder who
   cannot read a long generic name can still match the picture.';
comment on column elder_medications.pills_remaining is
  'Counted down as doses are marked taken. Null means the family is not
   tracking the count for this medicine.';
comment on column elder_medications.refill_at is
  'Warn when pills_remaining drops to this. Null disables the warning rather
   than defaulting to an arbitrary number nobody chose.';

-- Storage for the two new kinds of image. Both are private: a photo of an
-- elder's face and a photo of their prescription are health data, reachable
-- only through short-lived signed URLs.
insert into storage.buckets (id, name, public)
values ('elder-photos', 'elder-photos', false),
       ('medication-photos', 'medication-photos', false)
on conflict (id) do nothing;

-- Read access mirrors the existing elder-visibility rule: the elder
-- themselves, or an actively linked family member. Uploads are limited to the
-- same set, so a caregiver cannot silently replace a medication photo.
do $$
declare
  b text;
begin
  foreach b in array array['elder-photos', 'medication-photos'] loop
    execute format($f$
      drop policy if exists "%1$s_read" on storage.objects;
      create policy "%1$s_read" on storage.objects for select
        using (
          bucket_id = %1$L
          and exists (
            select 1 from elder_profiles e
            left join family_links fl
              on fl.elder_id = e.id
             and fl.family_user_id = auth.uid()
             and fl.status = 'active'
            where e.id::text = split_part(storage.objects.name, '/', 1)
              and (e.auth_user_id = auth.uid() or fl.id is not null)
          )
        );

      drop policy if exists "%1$s_write" on storage.objects;
      create policy "%1$s_write" on storage.objects for insert
        with check (
          bucket_id = %1$L
          and exists (
            select 1 from elder_profiles e
            left join family_links fl
              on fl.elder_id = e.id
             and fl.family_user_id = auth.uid()
             and fl.status = 'active'
            where e.id::text = split_part(storage.objects.name, '/', 1)
              and (e.auth_user_id = auth.uid() or fl.id is not null)
          )
        );
    $f$, b);
  end loop;
end $$;
