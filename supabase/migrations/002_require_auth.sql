-- Classly: lock down RLS now that login exists. Replaces the temporary
-- anon-open policies from 001_init.sql with authenticated-only access.

drop policy if exists "anon_all" on sections;
drop policy if exists "anon_all" on students;
drop policy if exists "anon_all" on assignments;
drop policy if exists "anon_all" on scores;
drop policy if exists "anon_all" on attendance;
drop policy if exists "anon_all" on notes;
drop policy if exists "anon_all" on standards;
drop policy if exists "anon_all" on mastery;

create policy "authenticated_all" on sections for all to authenticated using (true) with check (true);
create policy "authenticated_all" on students for all to authenticated using (true) with check (true);
create policy "authenticated_all" on assignments for all to authenticated using (true) with check (true);
create policy "authenticated_all" on scores for all to authenticated using (true) with check (true);
create policy "authenticated_all" on attendance for all to authenticated using (true) with check (true);
create policy "authenticated_all" on notes for all to authenticated using (true) with check (true);
create policy "authenticated_all" on standards for all to authenticated using (true) with check (true);
create policy "authenticated_all" on mastery for all to authenticated using (true) with check (true);
