-- Classly: initial schema (single-teacher prototype, no auth yet)
-- Mirrors the existing localStorage shape 1:1 so the migration is lossless.

create table if not exists sections (
  id text primary key,
  subject text not null,
  period text not null,
  room text,
  time text,
  color text,
  subject_type text not null default 'Core Subject',
  density text not null default 'Comfortable',
  student_names text not null default 'Full'
);

create table if not exists students (
  id text primary key,
  name text not null,
  first text not null,
  initials text not null,
  color text not null,
  guardian text
);

create table if not exists assignments (
  id text primary key,
  term int not null,
  comp text not null,
  name text not null,
  hps int not null,
  short text
);

create table if not exists scores (
  assignment_id text references assignments(id) on delete cascade,
  student_id text references students(id) on delete cascade,
  raw numeric,
  flag text,
  primary key (assignment_id, student_id)
);

create table if not exists attendance (
  att_date date not null,
  period int not null,
  student_id text references students(id) on delete cascade,
  status text not null,
  primary key (att_date, period, student_id)
);

create table if not exists notes (
  note_date date not null,
  period int not null,
  student_id text references students(id) on delete cascade,
  body text,
  primary key (note_date, period, student_id)
);

create table if not exists standards (
  id text primary key,
  name text not null
);

create table if not exists mastery (
  standard_id text references standards(id) on delete cascade,
  student_id text references students(id) on delete cascade,
  level int,
  primary key (standard_id, student_id)
);

-- RLS: TEMPORARY permissive policies (no auth exists yet — locked down in the
-- "Authentication" phase that follows this one). Anon key can read/write everything.
alter table sections enable row level security;
alter table students enable row level security;
alter table assignments enable row level security;
alter table scores enable row level security;
alter table attendance enable row level security;
alter table notes enable row level security;
alter table standards enable row level security;
alter table mastery enable row level security;

drop policy if exists "anon_all" on sections;
create policy "anon_all" on sections for all using (true) with check (true);
drop policy if exists "anon_all" on students;
create policy "anon_all" on students for all using (true) with check (true);
drop policy if exists "anon_all" on assignments;
create policy "anon_all" on assignments for all using (true) with check (true);
drop policy if exists "anon_all" on scores;
create policy "anon_all" on scores for all using (true) with check (true);
drop policy if exists "anon_all" on attendance;
create policy "anon_all" on attendance for all using (true) with check (true);
drop policy if exists "anon_all" on notes;
create policy "anon_all" on notes for all using (true) with check (true);
drop policy if exists "anon_all" on standards;
create policy "anon_all" on standards for all using (true) with check (true);
drop policy if exists "anon_all" on mastery;
create policy "anon_all" on mastery for all using (true) with check (true);
