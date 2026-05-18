-- ============================================================
-- GymBro — initial schema for the self-hosted (Dockerized) backend.
-- Applied automatically by `supabase start` / `supabase db reset`.
-- ============================================================

-- ── profiles ────────────────────────────────────────────────
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text,
  email      text,
  weight     numeric(5,1),
  height     numeric(5,1),
  age        int,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by authenticated users"
  on public.profiles for select to authenticated using (true);
create policy "Users insert own profile"
  on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy "Users update own profile"
  on public.profiles for update to authenticated using (auth.uid() = id);

-- Auto-create a profile row whenever a new auth user signs up
-- (covers Google sign-in, which does not hit the register screen).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (new.id, new.raw_user_meta_data ->> 'full_name', new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── nutrition_logs ──────────────────────────────────────────
create table if not exists public.nutrition_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  meal_name  text not null,
  meal_type  text not null,
  calories   numeric not null default 0,
  protein    numeric not null default 0,
  carbs      numeric not null default 0,
  fat        numeric not null default 0,
  meal_date  date not null default current_date,
  created_at timestamptz not null default now()
);

alter table public.nutrition_logs enable row level security;
create policy "Users manage own nutrition logs"
  on public.nutrition_logs for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── water_logs ──────────────────────────────────────────────
create table if not exists public.water_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  amount_ml  numeric not null default 0,
  log_date   date not null default current_date,
  created_at timestamptz not null default now()
);

alter table public.water_logs enable row level security;
create policy "Users manage own water logs"
  on public.water_logs for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── workout_logs ────────────────────────────────────────────
create table if not exists public.workout_logs (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  name             text not null,
  duration_minutes int not null default 0,
  calories_burned  numeric not null default 0,
  workout_date     date not null default current_date,
  created_at       timestamptz not null default now()
);

alter table public.workout_logs enable row level security;
create policy "Users manage own workout logs"
  on public.workout_logs for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── workout_exercises (Workout Plan feature) ────────────────
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
  on public.workout_exercises for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── weight_logs (Weight Progress feature) ───────────────────
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
  on public.weight_logs for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── friendships (Social feature) ────────────────────────────
-- requester_id / addressee_id reference profiles so PostgREST can
-- embed the related profile when the app queries friendships.
create table if not exists public.friendships (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status       text not null default 'pending'
                 check (status in ('pending', 'accepted')),
  created_at   timestamptz not null default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

alter table public.friendships enable row level security;

create policy "Users see their own friendships"
  on public.friendships for select to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);
create policy "Users send friend requests"
  on public.friendships for insert to authenticated
  with check (auth.uid() = requester_id);
create policy "Users respond to requests they received"
  on public.friendships for update to authenticated
  using (auth.uid() = addressee_id);
create policy "Either party can remove a friendship"
  on public.friendships for delete to authenticated
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

-- ── storage: avatars bucket ─────────────────────────────────
insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict (id) do nothing;

create policy "Avatar images are publicly readable"
  on storage.objects for select using (bucket_id = 'avatars');
create policy "Users upload their own avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "Users update their own avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
