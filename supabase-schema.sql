-- ============================================================
-- abkya.in - Supabase Schema (safe to rerun)
-- Paste into Supabase SQL Editor and Run
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- PROFILES
-- ============================================================
create table if not exists public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  email            text,
  name             text,
  avatar_url       text,
  age              int,
  education        text,
  stream           text,
  work_ex          int default 0,
  role             text,
  industry         text,
  goals            text,
  career_target    text,
  location_pref    text,
  home_state       text,
  salary_target    int default 0,
  priorities       text,
  profile_complete boolean default false,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

alter table public.profiles
  add column if not exists email text,
  add column if not exists name text,
  add column if not exists avatar_url text,
  add column if not exists age int,
  add column if not exists education text,
  add column if not exists stream text,
  add column if not exists work_ex int default 0,
  add column if not exists role text,
  add column if not exists industry text,
  add column if not exists goals text,
  add column if not exists career_target text,
  add column if not exists location_pref text,
  add column if not exists home_state text,
  add column if not exists salary_target int default 0,
  add column if not exists priorities text,
  add column if not exists profile_complete boolean default false,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

alter table public.profiles enable row level security;

drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles
  for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, email, name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture', '')
  )
  on conflict (id) do update set
    email = excluded.email,
    name = coalesce(excluded.name, public.profiles.name),
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- ============================================================
-- REPORTS
-- ============================================================
create table if not exists public.reports (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid unique references auth.users(id) on delete cascade,
  plan        text not null check (plan in ('basic','pro')),
  payment_id  text,
  order_id    text,
  paid_at     timestamptz default now(),
  report_data jsonb,
  updated_at  timestamptz default now()
);

alter table public.reports
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists plan text,
  add column if not exists payment_id text,
  add column if not exists order_id text,
  add column if not exists paid_at timestamptz default now(),
  add column if not exists report_data jsonb,
  add column if not exists updated_at timestamptz default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'reports_user_id_key'
  ) then
    alter table public.reports add constraint reports_user_id_key unique (user_id);
  end if;
end $$;

alter table public.reports enable row level security;

drop policy if exists "read own report" on public.reports;
create policy "read own report" on public.reports
  for select using (auth.uid() = user_id);

drop policy if exists "service write" on public.reports;
create policy "service write" on public.reports
  for all using (true) with check (true);

-- ============================================================
-- OPTIONAL FEE TABLE FOR ROI
-- Fill this with verified fee data later. The frontend only shows ROI when
-- total_fee is available for a college record.
-- ============================================================
create table if not exists public.college_program_fees (
  id             uuid primary key default gen_random_uuid(),
  record_id      text,
  institution_name text not null,
  programme_name text not null,
  annual_fee     numeric,
  total_fee      numeric,
  source_url     text,
  source_note    text,
  updated_at     timestamptz default now(),
  created_at     timestamptz default now(),
  unique (record_id, programme_name)
);

alter table public.college_program_fees
  add column if not exists record_id text,
  add column if not exists institution_name text,
  add column if not exists programme_name text,
  add column if not exists annual_fee numeric,
  add column if not exists total_fee numeric,
  add column if not exists source_url text,
  add column if not exists source_note text,
  add column if not exists updated_at timestamptz default now(),
  add column if not exists created_at timestamptz default now();

alter table public.college_program_fees enable row level security;

drop policy if exists "read fee rows" on public.college_program_fees;
create policy "read fee rows" on public.college_program_fees
  for select using (true);

drop policy if exists "service write fee rows" on public.college_program_fees;
create policy "service write fee rows" on public.college_program_fees
  for all using (true) with check (true);

-- ============================================================
-- updated_at triggers
-- ============================================================
create or replace function public.update_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_ts on public.profiles;
create trigger profiles_ts
before update on public.profiles
for each row execute function public.update_updated_at();

drop trigger if exists reports_ts on public.reports;
create trigger reports_ts
before update on public.reports
for each row execute function public.update_updated_at();

drop trigger if exists college_fees_ts on public.college_program_fees;
create trigger college_fees_ts
before update on public.college_program_fees
for each row execute function public.update_updated_at();
