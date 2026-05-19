-- ============================================================
-- GymBro — Challenges & leaderboards (run on the CLOUD project).
-- Self-hosted setups already get this via supabase/migrations/.
-- Requires database/social.sql (friendships) first.
-- ============================================================

create table if not exists public.challenges (
  id         uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles (id) on delete cascade,
  title      text not null,
  metric     text not null default 'workouts'
               check (metric in ('workouts', 'minutes', 'calories')),
  starts_at  date not null default current_date,
  ends_at    date not null,
  created_at timestamptz not null default now(),
  check (ends_at >= starts_at)
);

create index if not exists challenges_creator_id_idx
  on public.challenges (creator_id);
create index if not exists challenges_created_at_idx
  on public.challenges (created_at desc);

create table if not exists public.challenge_participants (
  id           uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  joined_at    timestamptz not null default now(),
  unique (challenge_id, user_id)
);

create index if not exists challenge_participants_challenge_id_idx
  on public.challenge_participants (challenge_id);
create index if not exists challenge_participants_user_id_idx
  on public.challenge_participants (user_id);

alter table public.challenges enable row level security;
alter table public.challenge_participants enable row level security;

create policy "Users see relevant challenges"
  on public.challenges for select to authenticated
  using (
    creator_id = (select auth.uid())
    or exists (
      select 1 from public.challenge_participants cp
      where cp.challenge_id = challenges.id
        and cp.user_id = (select auth.uid())
    )
    or exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester_id = (select auth.uid())
             and f.addressee_id = challenges.creator_id)
          or (f.addressee_id = (select auth.uid())
             and f.requester_id = challenges.creator_id)
        )
    )
  );
create policy "Users create own challenges"
  on public.challenges for insert to authenticated
  with check (creator_id = (select auth.uid()));
create policy "Creators update own challenges"
  on public.challenges for update to authenticated
  using (creator_id = (select auth.uid()));
create policy "Creators delete own challenges"
  on public.challenges for delete to authenticated
  using (creator_id = (select auth.uid()));

create policy "Participants are visible to authenticated users"
  on public.challenge_participants for select to authenticated using (true);
create policy "Users join challenges themselves"
  on public.challenge_participants for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.challenges c where c.id = challenge_id)
  );
create policy "Users leave challenges themselves"
  on public.challenge_participants for delete to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.handle_new_challenge()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.challenge_participants (challenge_id, user_id)
  values (new.id, new.creator_id)
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_challenge_created on public.challenges;
create trigger on_challenge_created
  after insert on public.challenges
  for each row execute function public.handle_new_challenge();

create or replace function public.challenge_leaderboard(p_challenge uuid)
returns table (
  member_id     uuid,
  member_name   text,
  member_avatar text,
  score         numeric
)
language plpgsql
security definer set search_path = public
as $$
declare
  c public.challenges%rowtype;
begin
  select * into c from public.challenges where id = p_challenge;
  if not found then
    return;
  end if;
  if not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge
      and challenge_participants.user_id = auth.uid()
  ) then
    return;
  end if;

  return query
  select cp.user_id,
         pr.full_name,
         pr.avatar_url,
         coalesce(
           case c.metric
             when 'minutes'  then sum(w.duration_minutes)
             when 'calories' then sum(w.calories_burned)
             else count(w.id)
           end,
           0
         )::numeric
  from public.challenge_participants cp
  join public.profiles pr on pr.id = cp.user_id
  left join public.workout_logs w
    on w.user_id = cp.user_id
   and w.workout_date >= c.starts_at
   and w.workout_date <= c.ends_at
  where cp.challenge_id = p_challenge
  group by cp.user_id, pr.full_name, pr.avatar_url, c.metric
  order by 4 desc;
end;
$$;

grant execute on function public.challenge_leaderboard(uuid) to authenticated;
