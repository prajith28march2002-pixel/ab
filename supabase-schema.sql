-- ============================================================
-- abkya.in — Supabase Schema
-- Paste into Supabase SQL Editor and Run
-- ============================================================

-- PROFILES: one row per user
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text,
  name          text,
  avatar_url    text,
  age           int,
  education     text,
  stream        text,
  work_ex       int default 0,
  role          text,
  industry      text,
  goals         text,
  career_target text,
  location_pref text,
  home_state    text,
  salary_target int default 0,
  priorities      text,
  profile_complete boolean default false,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

alter table public.profiles enable row level security;
create policy "own profile" on public.profiles
  using (auth.uid() = id) with check (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture', '')
  )
  on conflict (id) do update set
    email = excluded.email,
    name  = coalesce(excluded.name, profiles.name),
    avatar_url = coalesce(excluded.avatar_url, profiles.avatar_url),
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- REPORTS: one paid report per user (upserted on payment)
create table if not exists public.reports (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid unique references auth.users(id) on delete cascade,
  plan         text not null check (plan in ('basic','pro')),
  payment_id   text,
  order_id     text,
  paid_at      timestamptz default now(),
  report_data  jsonb,
  updated_at   timestamptz default now()
);

alter table public.reports enable row level security;
-- Users read own; service role writes
create policy "read own report" on public.reports
  for select using (auth.uid() = user_id);
create policy "service write" on public.reports
  for all using (true) with check (true);

-- Updated_at triggers
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists profiles_ts on public.profiles;
create trigger profiles_ts before update on public.profiles
  for each row execute function update_updated_at();

drop trigger if exists reports_ts on public.reports;
create trigger reports_ts before update on public.reports
  for each row execute function update_updated_at();
