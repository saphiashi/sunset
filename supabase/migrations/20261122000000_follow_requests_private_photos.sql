-- Private accounts, follow requests, and private photo storage.

-- ---------------------------------------------------------------------------
-- Private accounts
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column is_private boolean not null default false;

-- ---------------------------------------------------------------------------
-- Follow requests: a follow is 'pending' until a private followee accepts.
-- ---------------------------------------------------------------------------

alter table public.follows
  add column status text not null default 'accepted'
    check (status in ('pending', 'accepted'));

create index follows_followee_pending_idx
  on public.follows (followee_id) where status = 'pending';

-- The server decides the starting status; clients cannot self-accept.
create or replace function public.follows_set_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.status := case
    when exists (select 1 from public.profiles p where p.id = new.followee_id and p.is_private)
      then 'pending'
    else 'accepted'
  end;
  return new;
end;
$$;

create trigger follows_set_status
  before insert on public.follows
  for each row execute function public.follows_set_status();

-- Going public accepts everyone who was waiting.
create or replace function public.profiles_accept_pending_on_public()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.is_private and not new.is_private then
    update public.follows
      set status = 'accepted'
      where followee_id = new.id and status = 'pending';
  end if;
  return new;
end;
$$;

create trigger profiles_accept_pending_on_public
  after update of is_private on public.profiles
  for each row execute function public.profiles_accept_pending_on_public();

-- Only accepted follows grant read access.
create or replace function public.is_following(_followee uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.follows
    where follower_id = auth.uid()
      and followee_id = _followee
      and status = 'accepted'
  );
$$;

-- Followee accepts (status only); either side can end the edge
-- (unfollow, decline a request, or remove a follower).
revoke update on public.follows from authenticated;
grant update (status) on public.follows to authenticated;

create policy "follows_update_followee"
  on public.follows for update
  to authenticated
  using (followee_id = auth.uid())
  with check (followee_id = auth.uid() and status = 'accepted');

drop policy "follows_delete_own" on public.follows;
create policy "follows_delete_involved"
  on public.follows for delete
  to authenticated
  using (follower_id = auth.uid() or followee_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Private photos: the bucket is no longer public. Owners read their folder;
-- accepted followers read photos attached to public entries. Clients use
-- short-lived signed URLs.
-- ---------------------------------------------------------------------------

update public.sunset_entries
  set photo_path = split_part(photo_url, '/object/public/sunset-photos/', 2)
  where photo_path is null
    and photo_url like '%/object/public/sunset-photos/%';

update public.sunset_entries
  set photo_url = null
  where photo_url like '%/object/public/sunset-photos/%';

create index sunset_entries_photo_path_idx
  on public.sunset_entries (photo_path) where photo_path is not null;

create or replace function public.can_view_photo(_path text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.sunset_entries e
    where e.photo_path = _path
      -- photo_path is client-written; only trust it inside the owner's own folder.
      and split_part(_path, '/', 1) = e.user_id::text
      and (
        e.user_id = auth.uid()
        or (e.is_public and public.is_following(e.user_id))
      )
  );
$$;

grant execute on function public.can_view_photo(text) to authenticated;

update storage.buckets set public = false where id = 'sunset-photos';

drop policy "sunset_photos_public_read" on storage.objects;

create policy "sunset_photos_read_owner_or_follower"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'sunset-photos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.can_view_photo(name)
    )
  );
