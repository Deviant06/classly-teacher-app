-- Classly Phase 3 fix: attendance/notes are now keyed by class_id (migration 003),
-- but the old NOT-NULL `period` index column from 001 was left behind and blocks
-- inserts. Drop it — it is no longer referenced by the app.

alter table attendance drop column if exists period;
alter table notes drop column if exists period;
