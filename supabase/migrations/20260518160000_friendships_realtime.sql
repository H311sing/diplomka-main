-- ============================================================
-- GymBro — stream friendship changes over Realtime so the Home
-- screen's friend-request badge updates live.
-- ============================================================
do $$
begin
  alter publication supabase_realtime add table public.friendships;
exception
  when duplicate_object then null;
end
$$;
