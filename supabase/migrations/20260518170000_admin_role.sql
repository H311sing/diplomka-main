-- ============================================================
-- GymBro — Admin role
-- Adds an is_admin flag to profiles, auto-promotes the configured
-- admin email on signup, and exposes a SECURITY DEFINER helper so
-- RLS can check admin status without recursing into profiles itself.
-- ============================================================

alter table public.profiles
  add column if not exists is_admin boolean not null default false;

-- The email that should always be admin. (Hardcoded for simplicity —
-- could be a settings table later.)
-- ------------------------------------------------------------

-- Update new-user trigger: promote on signup if the email matches.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  is_admin_user boolean := (new.email = 'qwsxillhellsing@gmail.com');
begin
  insert into public.profiles (id, full_name, email, is_admin)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.email,
    is_admin_user
  )
  on conflict (id) do update
    set is_admin = excluded.is_admin or public.profiles.is_admin;
  return new;
end;
$$;

-- Promote any *existing* user with the admin email.
update public.profiles
   set is_admin = true
 where id in (
   select id from auth.users where email = 'qwsxillhellsing@gmail.com'
 );

-- SECURITY DEFINER helper — bypasses RLS so policies can call it
-- without recursing into the very table they protect.
create or replace function public.is_current_user_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (select is_admin from public.profiles where id = auth.uid()),
    false
  );
$$;

grant execute on function public.is_current_user_admin() to authenticated;

-- Extra RLS: admins may read every profile (needed for the admin
-- panel's user list). The existing "viewable by authenticated" policy
-- already covers non-admin reads, but kept here as an explicit grant.
do $$
begin
  if not exists (
    select 1 from pg_policies
     where schemaname = 'public'
       and tablename = 'profiles'
       and policyname = 'Admins read all profiles'
  ) then
    create policy "Admins read all profiles"
      on public.profiles for select to authenticated
      using (public.is_current_user_admin());
  end if;
end
$$;
