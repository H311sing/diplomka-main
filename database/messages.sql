-- ============================================================
-- GymBro — Direct messages / friend chat (run on the CLOUD project).
-- Self-hosted setups already get this via supabase/migrations/.
-- Requires database/social.sql (friendships) first.
-- ============================================================

create table if not exists public.messages (
  id          uuid primary key default gen_random_uuid(),
  sender_id   uuid not null references public.profiles (id) on delete cascade,
  receiver_id uuid not null references public.profiles (id) on delete cascade,
  content     text not null,
  created_at  timestamptz not null default now(),
  check (sender_id <> receiver_id)
);

create index if not exists messages_pair_idx
  on public.messages (sender_id, receiver_id, created_at);
create index if not exists messages_receiver_idx
  on public.messages (receiver_id);

alter table public.messages enable row level security;

create policy "Users see their own messages"
  on public.messages for select to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Users send messages to friends"
  on public.messages for insert to authenticated
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester_id = sender_id and f.addressee_id = receiver_id)
          or (f.addressee_id = sender_id and f.requester_id = receiver_id)
        )
    )
  );

create policy "Users delete their own messages"
  on public.messages for delete to authenticated
  using (auth.uid() = sender_id);

do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
end
$$;
