-- Minimal stand-in for the parts of a real Supabase project the
-- migrations assume exist: the auth schema/roles, auth.uid(), the
-- supabase_realtime publication, and (as of 0006) a bare-bones
-- storage.objects/storage.buckets pair so storage RLS policies can be
-- exercised too.
--
-- This is NOT a claim that it reproduces Supabase exactly — there's no
-- PostgREST, GoTrue, or Realtime server behind it. It exists because the
-- Supabase CLI needs Docker to pull images from Docker Hub, which this
-- environment's network policy blocks; a plain local Postgres + this stub
-- was the closest available approximation, and it's enough surface for
-- the RLS test suite in rls_smoke_test.sql to actually exercise the
-- policies as different simulated users. If you have the Supabase CLI
-- available, prefer `supabase db reset` over this — it's the real thing.

create schema if not exists auth;

create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email text
);

create or replace function auth.uid() returns uuid
language sql stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to authenticated, service_role;
alter default privileges in schema public grant select on tables to anon;

-- Stand-in for the publication Supabase Realtime manages automatically.
-- (Emits a "wal_level is insufficient" warning on a default local
-- Postgres install — harmless for this purpose, just means nothing will
-- actually stream through it here.)
create publication supabase_realtime;

-- Bare-bones stand-in for Supabase Storage's own tables — just enough
-- columns for 0006_caregiver_documents_storage.sql's RLS policies to
-- reference. The real storage.objects has many more columns (metadata,
-- version, etc.); none of them matter to the policies being tested here.
create schema if not exists storage;

create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false
);

create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text,
  owner uuid,
  created_at timestamptz not null default now()
);

alter table storage.objects enable row level security;
grant usage on schema storage to anon, authenticated, service_role;
grant select, insert, update, delete on storage.buckets, storage.objects to authenticated, service_role;
grant select on storage.buckets, storage.objects to anon;
