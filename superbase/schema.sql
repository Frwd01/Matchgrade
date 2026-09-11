-- MatchGrade Supabase Schema
-- Run this in the Supabase SQL Editor (Dashboard → SQL → New query)
-- Project must have Auth enabled (email provider is fine).

-- ============================================================
-- 1. PROFILES (extends auth.users)
-- ============================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- 2. MATCHES
-- ============================================================
create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  player_name text not null default 'Unnamed player',
  club text,
  opponent text,
  sport text not null check (sport in ('soccer', 'basketball', 'cricket')),
  role_code text not null,
  role_label text,
  rating numeric(4,2) not null check (rating >= 1 and rating <= 10),
  verdict text,
  verdict_sub text,
  tier text,
  minutes integer,
  result text check (result is null or result in ('win', 'draw', 'loss')),
  stats jsonb not null default '{}'::jsonb,
  breakdown jsonb not null default '[]'::jsonb,
  match_date date default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists matches_user_id_idx on public.matches(user_id);
create index if not exists matches_user_created_idx on public.matches(user_id, created_at desc);
create index if not exists matches_sport_idx on public.matches(sport);

-- updated_at helper
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists matches_set_updated_at on public.matches;
create trigger matches_set_updated_at
  before update on public.matches
  for each row execute function public.set_updated_at();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ============================================================
-- 3. ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles enable row level security;
alter table public.matches enable row level security;

-- Profiles: users can read/update only their own
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Matches: full CRUD only for owner
drop policy if exists "matches_select_own" on public.matches;
create policy "matches_select_own"
  on public.matches for select
  using (auth.uid() = user_id);

drop policy if exists "matches_insert_own" on public.matches;
create policy "matches_insert_own"
  on public.matches for insert
  with check (auth.uid() = user_id);

drop policy if exists "matches_update_own" on public.matches;
create policy "matches_update_own"
  on public.matches for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "matches_delete_own" on public.matches;
create policy "matches_delete_own"
  on public.matches for delete
  using (auth.uid() = user_id);

-- ============================================================
-- 4. OPTIONAL: aggregate view for future percentiles
--    (no personal data; safe for authenticated read later)
-- ============================================================
-- Example only — not enabled by default. Uncomment when you
-- have enough real data and want percentile features.
--
-- create or replace view public.rating_stats_by_role as
-- select sport, role_code,
--   count(*) as n,
--   avg(rating) as avg_rating,
--   percentile_cont(0.5) within group (order by rating) as median_rating
-- from public.matches
-- group by sport, role_code
-- having count(*) >= 50;
--
-- grant select on public.rating_stats_by_role to authenticated;

-- ============================================================
-- DONE
-- After running this:
-- 1. Auth → Providers → enable Email (and optionally Magic Link)
-- 2. Project Settings → API → copy Project URL + anon public key
-- 3. Paste them into index.html SUPABASE_CONFIG
-- ============================================================
