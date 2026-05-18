-- ============================================================
-- GymBro — Activity feed (Social phase 2).
-- A user's workouts surface in a feed shared with their friends,
-- where friends can like them.
-- ============================================================

-- ── activities ──────────────────────────────────────────────
create table if not exists public.activities (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  type       text not null default 'workout',
  title      text not null,
  detail     text,
  created_at timestamptz not null default now()
);

create index if not exists activities_user_id_idx
  on public.activities (user_id);
create index if not exists activities_created_at_idx
  on public.activities (created_at desc);

alter table public.activities enable row level security;

-- A user sees their own activities and those of accepted friends.
create policy "Users see own and friends activities"
  on public.activities for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester_id = (select auth.uid())
             and f.addressee_id = activities.user_id)
          or (f.addressee_id = (select auth.uid())
             and f.requester_id = activities.user_id)
        )
    )
  );
create policy "Users create own activities"
  on public.activities for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "Users delete own activities"
  on public.activities for delete to authenticated
  using (user_id = (select auth.uid()));

-- ── activity_likes ──────────────────────────────────────────
create table if not exists public.activity_likes (
  id          uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (activity_id, user_id)
);

create index if not exists activity_likes_activity_id_idx
  on public.activity_likes (activity_id);
create index if not exists activity_likes_user_id_idx
  on public.activity_likes (user_id);

alter table public.activity_likes enable row level security;

create policy "Likes are visible to authenticated users"
  on public.activity_likes for select to authenticated using (true);
create policy "Users add their own likes"
  on public.activity_likes for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "Users remove their own likes"
  on public.activity_likes for delete to authenticated
  using (user_id = (select auth.uid()));
