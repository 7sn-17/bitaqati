-- Phase C: two-level deck hierarchy.
--
-- Phase A already enforces "main deck -> sub-deck" in the Flutter app. This
-- migration makes Postgres the last line of defence and matches the local
-- Drift constraint in lib/data/local/tables.dart.
--
-- Safe on existing data: the live table contained no decks deeper than 0 when
-- this ran, and the app has rejected deeper decks since Phase A.

alter table public.decks drop constraint if exists decks_depth_check;

alter table public.decks
  add constraint decks_depth_check check (depth >= 0 and depth <= 1);

comment on constraint decks_depth_check on public.decks is
  'Decks are at most two levels deep: main deck (0) and sub-deck (1).';
