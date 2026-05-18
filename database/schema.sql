-- ============================================================
-- GymBro — database schema for new features
-- Run this in the Supabase Dashboard → SQL Editor.
-- Existing tables (profiles, nutrition_logs, water_logs,
-- workout_logs) are assumed to already exist.
-- ============================================================

-- ── Workout plan exercises ──────────────────────────────────
-- Backs the Workout Plan screen and Home's "Today's Workout".
create table if not exists public.workout_exercises (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  name         text not null,
  sets         int  not null default 3,
  reps         int  not null default 10,
  muscle_group text not null default 'Other',
  is_done      boolean not null default false,
  created_at   timestamptz not null default now()
);

alter table public.workout_exercises enable row level security;

create policy "Users manage own exercises"
  on public.workout_exercises
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── Weight history ──────────────────────────────────────────
-- Backs the Weight Progress chart on the Stats screen.
-- One entry per user per day (upsert on conflict).
create table if not exists public.weight_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  weight     numeric(5,1) not null,
  logged_at  date not null default current_date,
  created_at timestamptz not null default now(),
  unique (user_id, logged_at)
);

alter table public.weight_logs enable row level security;

create policy "Users manage own weight logs"
  on public.weight_logs
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
