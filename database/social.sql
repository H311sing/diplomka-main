-- ============================================================
-- GymBro — Social feature tables (run on the CLOUD project).
-- Self-hosted setups already get this via supabase/migrations/.
-- Run in the Supabase Dashboard → SQL Editor.
-- ============================================================

-- ── friendships ─────────────────────────────────────────────
-- requester_id / addressee_id reference profiles so the app can
-- embed the related profile when querying friendships.
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

-- The Friends screen searches users by name, so authenticated users
-- must be able to read every profile. If your existing profiles table
-- restricts SELECT to the owner, replace that policy with this one:
--
--   drop policy if exists "<old select policy name>" on public.profiles;
--   create policy "Profiles are viewable by authenticated users"
--     on public.profiles for select to authenticated using (true);
