-- Beli-style ranking: each of your skies sits in a tier (0 okay, 1 lovely,
-- 2 unforgettable) at a best-first position. overall_score is derived from it.

alter table public.sunset_entries
  add column rank_tier smallint check (rank_tier between 0 and 2),
  add column rank_order integer check (rank_order >= 0);

create index sunset_entries_user_rank_idx
  on public.sunset_entries (user_id, rank_tier desc, rank_order);
