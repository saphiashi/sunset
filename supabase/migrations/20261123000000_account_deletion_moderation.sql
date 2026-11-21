-- In-app account deletion (App Store 5.1.1(v)) and report/block (1.2).

-- ---------------------------------------------------------------------------
-- Blocks
-- ---------------------------------------------------------------------------

create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_not_self check (blocker_id <> blocked_id)
);

create index blocks_blocked_idx on public.blocks (blocked_id);

alter table public.blocks enable row level security;

create policy "blocks_all_own"
  on public.blocks for all
  to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

-- Both helpers only answer about the caller, so they can't probe strangers' blocks.
create or replace function public.is_blocked_with(_other uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = auth.uid() and blocked_id = _other)
       or (blocker_id = _other and blocked_id = auth.uid())
  );
$$;

-- Runs as definer: blocks RLS would otherwise hide the other person's block from the caller.
create or replace function public.has_blocked_me(_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.blocks
    where blocker_id = _user and blocked_id = auth.uid()
  );
$$;

-- Blocking ends follows in both directions.
create or replace function public.blocks_drop_follows()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.follows
    where (follower_id = new.blocker_id and followee_id = new.blocked_id)
       or (follower_id = new.blocked_id and followee_id = new.blocker_id);
  return new;
end;
$$;

create trigger blocks_drop_follows
  after insert on public.blocks
  for each row execute function public.blocks_drop_follows();

-- Blocked people can't find you, follow you, or send you pins.
drop policy "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_unblocked"
  on public.profiles for select
  to authenticated
  using (
    id = auth.uid()
    or not public.has_blocked_me(id)
  );

drop policy "follows_insert_own" on public.follows;
create policy "follows_insert_own_unblocked"
  on public.follows for insert
  to authenticated
  with check (
    follower_id = auth.uid()
    and not public.is_blocked_with(followee_id)
  );

drop policy "shared_notes_insert_sender" on public.shared_spot_notes;
create policy "shared_notes_insert_sender_unblocked"
  on public.shared_spot_notes for insert
  to authenticated
  with check (
    from_user_id = auth.uid()
    and not public.is_blocked_with(to_user_id)
  );

-- ---------------------------------------------------------------------------
-- Reports (reviewed by the developer in the dashboard; reporters see their own)
-- ---------------------------------------------------------------------------

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles (id) on delete set null,
  reported_user_id uuid references public.profiles (id) on delete set null,
  entry_id uuid references public.sunset_entries (id) on delete set null,
  reason text not null check (reason in ('spam', 'harassment', 'inappropriate', 'other')),
  details text not null default '' check (length(details) <= 1000),
  created_at timestamptz not null default now()
);

create index reports_created_idx on public.reports (created_at desc);

alter table public.reports enable row level security;

create policy "reports_insert_own"
  on public.reports for insert
  to authenticated
  with check (reporter_id = auth.uid());

create policy "reports_select_own"
  on public.reports for select
  to authenticated
  using (reporter_id = auth.uid());

grant select, insert, update, delete on public.blocks to authenticated;
grant select, insert on public.reports to authenticated;
grant execute on function public.is_blocked_with(uuid) to authenticated;
grant execute on function public.has_blocked_me(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Account deletion. The app removes the user's Storage folder first (Storage
-- objects can't be deleted from SQL); deleting auth.users cascades through
-- profiles to every row the user owns.
-- ---------------------------------------------------------------------------

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
