-- Sunset Log — public schema, RLS, storage, and catalog spots.
-- Apply with: supabase db push   (or the SQL editor, in order)

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

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
  );
$$;

-- ---------------------------------------------------------------------------
-- Profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  handle text not null unique,
  display_name text not null default 'You',
  city text not null default '',
  bio text not null default '',
  avatar_hue double precision not null default 0.08,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_handle_format check (handle ~ '^[a-z0-9_]{2,32}$')
);

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base text;
  candidate text;
  n int := 0;
  full_name text;
begin
  base := lower(regexp_replace(
    split_part(coalesce(new.email, 'sky'), '@', 1),
    '[^a-z0-9_]',
    '',
    'g'
  ));
  if length(base) < 2 then
    base := 'sky';
  end if;
  candidate := base;
  while exists (select 1 from public.profiles where handle = candidate) loop
    n := n + 1;
    candidate := left(base, 28) || n::text;
  end loop;

  full_name := coalesce(
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'name',
    'You'
  );

  insert into public.profiles (id, handle, display_name)
  values (new.id, candidate, full_name)
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Spots
-- ---------------------------------------------------------------------------

create table public.spots (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  locality text not null default '',
  region text not null default '',
  blurb text not null default '',
  latitude double precision not null,
  longitude double precision not null,
  created_by uuid references public.profiles (id) on delete set null,
  is_public boolean not null default true,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index spots_created_by_idx on public.spots (created_by);
create trigger spots_updated_at
  before update on public.spots
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Sunset entries
-- ---------------------------------------------------------------------------

create table public.sunset_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  spot_id uuid references public.spots (id) on delete set null,
  captured_at timestamptz not null,
  note text not null default '',
  color_score double precision not null default 7
    check (color_score >= 1 and color_score <= 10),
  drama_score double precision not null default 7
    check (drama_score >= 1 and drama_score <= 10),
  overall_score double precision not null default 7
    check (overall_score >= 1 and overall_score <= 10),
  photo_url text,
  photo_path text,
  imported boolean not null default false,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index sunset_entries_user_captured_idx
  on public.sunset_entries (user_id, captured_at desc);
create index sunset_entries_spot_idx on public.sunset_entries (spot_id);
create trigger sunset_entries_updated_at
  before update on public.sunset_entries
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Collections (private to the owner)
-- ---------------------------------------------------------------------------

create table public.collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  detail text not null default '',
  symbol text not null default 'folder.fill',
  accent_token text not null default 'ember',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index collections_user_idx on public.collections (user_id);
create trigger collections_updated_at
  before update on public.collections
  for each row execute function public.set_updated_at();

create table public.collection_entries (
  collection_id uuid not null references public.collections (id) on delete cascade,
  entry_id uuid not null references public.sunset_entries (id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (collection_id, entry_id)
);

-- ---------------------------------------------------------------------------
-- Follows (one-way). Reading a friend's public skies requires following them.
-- ---------------------------------------------------------------------------

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  constraint follows_not_self check (follower_id <> followee_id)
);

create index follows_followee_idx on public.follows (followee_id);

-- ---------------------------------------------------------------------------
-- Saved spots
-- ---------------------------------------------------------------------------

create table public.saved_spots (
  user_id uuid not null references public.profiles (id) on delete cascade,
  spot_id uuid not null references public.spots (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, spot_id)
);

-- ---------------------------------------------------------------------------
-- Shared pin notes
-- ---------------------------------------------------------------------------

create table public.shared_spot_notes (
  id uuid primary key default gen_random_uuid(),
  spot_id uuid not null references public.spots (id) on delete cascade,
  from_user_id uuid not null references public.profiles (id) on delete cascade,
  to_user_id uuid not null references public.profiles (id) on delete cascade,
  from_handle text not null default '',
  to_handle text not null default '',
  message text not null default '',
  created_at timestamptz not null default now()
);

create index shared_spot_notes_to_idx on public.shared_spot_notes (to_user_id);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.spots enable row level security;
alter table public.sunset_entries enable row level security;
alter table public.collections enable row level security;
alter table public.collection_entries enable row level security;
alter table public.follows enable row level security;
alter table public.saved_spots enable row level security;
alter table public.shared_spot_notes enable row level security;

-- Profiles: signed-in users can look people up; only you write your row.
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid());

create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Spots: catalog (created_by is null) + your own + public spots of people you follow.
create policy "spots_select"
  on public.spots for select
  to authenticated
  using (
    created_by is null
    or created_by = auth.uid()
    or (is_public and public.is_following(created_by))
  );

create policy "spots_insert_own"
  on public.spots for insert
  to authenticated
  with check (created_by = auth.uid());

create policy "spots_update_own"
  on public.spots for update
  to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

create policy "spots_delete_own"
  on public.spots for delete
  to authenticated
  using (created_by = auth.uid());

-- Entries: own always; friends' public skies if you follow them.
create policy "sunset_entries_select"
  on public.sunset_entries for select
  to authenticated
  using (
    user_id = auth.uid()
    or (is_public and public.is_following(user_id))
  );

create policy "sunset_entries_insert_own"
  on public.sunset_entries for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "sunset_entries_update_own"
  on public.sunset_entries for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "sunset_entries_delete_own"
  on public.sunset_entries for delete
  to authenticated
  using (user_id = auth.uid());

-- Collections are private shelves.
create policy "collections_all_own"
  on public.collections for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "collection_entries_select_own"
  on public.collection_entries for select
  to authenticated
  using (
    exists (
      select 1 from public.collections c
      where c.id = collection_id and c.user_id = auth.uid()
    )
  );

create policy "collection_entries_write_own"
  on public.collection_entries for insert
  to authenticated
  with check (
    exists (
      select 1 from public.collections c
      where c.id = collection_id and c.user_id = auth.uid()
    )
    and exists (
      select 1 from public.sunset_entries e
      where e.id = entry_id and e.user_id = auth.uid()
    )
  );

create policy "collection_entries_delete_own"
  on public.collection_entries for delete
  to authenticated
  using (
    exists (
      select 1 from public.collections c
      where c.id = collection_id and c.user_id = auth.uid()
    )
  );

-- Follows: you write your outgoing follows; you can read edges that include you.
create policy "follows_select_involved"
  on public.follows for select
  to authenticated
  using (follower_id = auth.uid() or followee_id = auth.uid());

create policy "follows_insert_own"
  on public.follows for insert
  to authenticated
  with check (follower_id = auth.uid());

create policy "follows_delete_own"
  on public.follows for delete
  to authenticated
  using (follower_id = auth.uid());

-- Saved spots: yours only.
create policy "saved_spots_all_own"
  on public.saved_spots for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Shared notes: sender writes; sender or recipient reads.
create policy "shared_notes_select_involved"
  on public.shared_spot_notes for select
  to authenticated
  using (from_user_id = auth.uid() or to_user_id = auth.uid());

create policy "shared_notes_insert_sender"
  on public.shared_spot_notes for insert
  to authenticated
  with check (from_user_id = auth.uid());

create policy "shared_notes_delete_sender"
  on public.shared_spot_notes for delete
  to authenticated
  using (from_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Storage: sunset-photos / {user_id}/{entry_id}.jpg
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'sunset-photos',
  'sunset-photos',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "sunset_photos_public_read"
  on storage.objects for select
  to public
  using (bucket_id = 'sunset-photos');

create policy "sunset_photos_insert_own_folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'sunset-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "sunset_photos_update_own_folder"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'sunset-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'sunset-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "sunset_photos_delete_own_folder"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'sunset-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- Catalog spots (same UUIDs as the iOS seed) so local logs can FK on sync.
-- created_by is null: nobody "owns" the California demo atlas.
-- ---------------------------------------------------------------------------

insert into public.spots (id, name, locality, region, blurb, latitude, longitude, created_by, is_public)
values
  ('a1b2c3d4-0001-4000-8000-000000000001', 'Baker Beach', 'San Francisco', 'CA',
   'The Golden Gate sits in the frame like it was designed for dusk.', 37.7936, -122.4836, null, true),
  ('a1b2c3d4-0001-4000-8000-000000000002', 'Twin Peaks', 'San Francisco', 'CA',
   'A windy saddle over the city. Color hits the fog like a lampshade.', 37.7544, -122.4477, null, true),
  ('a1b2c3d4-0001-4000-8000-000000000003', 'Griffith Observatory', 'Los Angeles', 'CA',
   'Basin light, Hollywood sign, and a sky that goes theatrical.', 34.1184, -118.3004, null, true),
  ('a1b2c3d4-0001-4000-8000-000000000004', 'El Matador', 'Malibu', 'CA',
   'Sea stacks and a low, pink tide. Arrive early for the stairs.', 34.0384, -118.8764, null, true),
  ('a1b2c3d4-0001-4000-8000-000000000005', 'Ocean Beach', 'San Francisco', 'CA',
   'A long, honest horizon. Bonfires after the color dies.', 37.7594, -122.5107, null, true),
  ('a1b2c3d4-0001-4000-8000-000000000006', 'Lands End', 'San Francisco', 'CA',
   'Cypress tunnels and a ruin of a bathhouse facing the gate.', 37.7879, -122.5058, null, true),
  ('a1b2c3d4-0001-4000-8000-000000000007', 'Santa Monica Pier', 'Santa Monica', 'CA',
   'Ferris wheel lights against a gold plate of ocean.', 34.0100, -118.4960, null, true),
  ('a1b2c3d4-0001-4000-8000-000000000008', 'Bixby Creek', 'Big Sur', 'CA',
   'The arch, the drop, and weather that writes its own score.', 36.3714, -121.9016, null, true),
  ('a1b2c3d4-0001-4000-8000-000000000009', 'Alamo Square', 'San Francisco', 'CA',
   'Painted ladies, west-facing lawn, city in silhouette.', 37.7763, -122.4348, null, true),
  ('a1b2c3d4-0001-4000-8000-00000000000a', 'Mount Tamalpais', 'Mill Valley', 'CA',
   'Above the marine layer. Sometimes the sun sets on a second ocean of fog.', 37.9235, -122.5965, null, true)
on conflict (id) do nothing;

grant usage on schema public to authenticated;
grant select, insert, update, delete on
  public.profiles,
  public.spots,
  public.sunset_entries,
  public.collections,
  public.collection_entries,
  public.follows,
  public.saved_spots,
  public.shared_spot_notes
to authenticated;
grant execute on function public.is_following(uuid) to authenticated;

