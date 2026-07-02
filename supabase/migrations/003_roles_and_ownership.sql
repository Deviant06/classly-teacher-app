-- Classly Phase 3: roles + per-teacher/admin data isolation.
-- Turns the single-shared-dataset prototype into a whole-school model where
-- each teacher owns their classes and only sees their own data; admins see all.
--
-- NOTE: this clears the old shared demo rows (students/assignments/scores/
-- attendance/notes/mastery/sections). They were un-owned seed data and become
-- invisible under the new RLS anyway; the app now seeds a demo class per account.
-- The 5 global `standards` rows are kept as shared reference data.

------------------------------------------------------------------------
-- 1. Profiles + roles
------------------------------------------------------------------------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'teacher' check (role in ('teacher','admin')),
  school text,
  dept text,
  created_at timestamptz default now()
);
alter table profiles enable row level security;

-- is_admin(): SECURITY DEFINER so it can read profiles without tripping RLS
-- (avoids infinite recursion in profiles' own policies).
create or replace function is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists(select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select to authenticated
  using (id = auth.uid() or is_admin());
drop policy if exists profiles_insert on profiles;
create policy profiles_insert on profiles for insert to authenticated
  with check (id = auth.uid());
drop policy if exists profiles_update on profiles;
create policy profiles_update on profiles for update to authenticated
  using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());

-- Auto-create a profile row when a user signs up.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- Block non-admins from escalating their own role.
create or replace function guard_profile_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and not is_admin() then
    raise exception 'Only admins can change roles';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_role on profiles;
create trigger guard_role before update on profiles
  for each row execute function guard_profile_role();

------------------------------------------------------------------------
-- 2. Clear old shared demo data (child -> parent order)
------------------------------------------------------------------------
delete from mastery;
delete from attendance;
delete from notes;
delete from scores;
delete from assignments;
delete from students;
delete from sections;

------------------------------------------------------------------------
-- 3. Ownership columns + class scoping
------------------------------------------------------------------------
-- sections == "classes"
alter table sections add column if not exists owner_id uuid references auth.users(id) on delete cascade;
alter table sections add column if not exists section text;
alter table sections add column if not exists grade_level text;
alter table sections add column if not exists school_year text;
alter table sections add column if not exists term_system text default 'trimester';

-- students & assignments belong to a class
alter table students   add column if not exists class_id text references sections(id) on delete cascade;
alter table assignments add column if not exists class_id text references sections(id) on delete cascade;

-- attendance & notes: re-key on class_id instead of the old period index
alter table attendance add column if not exists class_id text references sections(id) on delete cascade;
alter table attendance drop constraint if exists attendance_pkey;
alter table attendance alter column class_id set not null;
alter table attendance add constraint attendance_pkey primary key (att_date, class_id, student_id);

alter table notes add column if not exists class_id text references sections(id) on delete cascade;
alter table notes drop constraint if exists notes_pkey;
alter table notes alter column class_id set not null;
alter table notes add constraint notes_pkey primary key (note_date, class_id, student_id);

------------------------------------------------------------------------
-- 4. RLS rewrite: scope every table to the class owner (admins bypass)
------------------------------------------------------------------------
-- owns_class(): SECURITY DEFINER so it reads sections directly.
create or replace function owns_class(cid text) returns boolean
language sql security definer stable set search_path = public as $$
  select exists(
    select 1 from sections s
    where s.id = cid and (s.owner_id = auth.uid() or is_admin())
  );
$$;

-- Drop every earlier blanket policy (Phase-1 "anon_all" and Phase-2
-- "authenticated_all") so nothing survives to grant unscoped access,
-- regardless of which prior migrations were applied.
drop policy if exists "anon_all" on sections;
drop policy if exists "anon_all" on students;
drop policy if exists "anon_all" on assignments;
drop policy if exists "anon_all" on scores;
drop policy if exists "anon_all" on attendance;
drop policy if exists "anon_all" on notes;
drop policy if exists "anon_all" on mastery;
drop policy if exists "authenticated_all" on sections;
drop policy if exists "authenticated_all" on students;
drop policy if exists "authenticated_all" on assignments;
drop policy if exists "authenticated_all" on scores;
drop policy if exists "authenticated_all" on attendance;
drop policy if exists "authenticated_all" on notes;
drop policy if exists "authenticated_all" on mastery;

-- Classes: you own the row.
create policy sections_all on sections for all to authenticated
  using (owner_id = auth.uid() or is_admin())
  with check (owner_id = auth.uid() or is_admin());

-- Students / assignments / attendance / notes: scoped by their class.
create policy students_all on students for all to authenticated
  using (owns_class(class_id)) with check (owns_class(class_id));
create policy assignments_all on assignments for all to authenticated
  using (owns_class(class_id)) with check (owns_class(class_id));
create policy attendance_all on attendance for all to authenticated
  using (owns_class(class_id)) with check (owns_class(class_id));
create policy notes_all on notes for all to authenticated
  using (owns_class(class_id)) with check (owns_class(class_id));

-- Scores & mastery: scoped through the owning student's class.
create policy scores_all on scores for all to authenticated
  using (exists(select 1 from students st where st.id = scores.student_id and owns_class(st.class_id)))
  with check (exists(select 1 from students st where st.id = scores.student_id and owns_class(st.class_id)));
create policy mastery_all on mastery for all to authenticated
  using (exists(select 1 from students st where st.id = mastery.student_id and owns_class(st.class_id)))
  with check (exists(select 1 from students st where st.id = mastery.student_id and owns_class(st.class_id)));

-- Standards stay shared reference data: everyone reads, only admins edit.
drop policy if exists "authenticated_all" on standards;
drop policy if exists standards_select on standards;
create policy standards_select on standards for select to authenticated using (true);
drop policy if exists standards_admin on standards;
create policy standards_admin on standards for all to authenticated
  using (is_admin()) with check (is_admin());
