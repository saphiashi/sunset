# Sunset Log

A SwiftUI journal for last light — photograph a sunset, rate the color and the weather, keep the places, and see who else was looking up.

The working title stayed. The voice did not: quieter labels, large photographs, scores you can feel.

## What is in this build

All day-one features are navigable on first launch from seed data. Signed-out you get a local journal. Signed-in, evenings and the circle sync through Supabase.

| Surface | What it does |
| --- | --- |
| **Tonight** | Golden-hour countdown from your location (SunCalc / NOAA civil sunset), streak, recent evenings |
| **Log** | Photo (library or camera), spot, date, note, tactile Color / Drama / Overall rails (1.0–10.0). Signed-in photos upload to Storage |
| **Journal** | Feed of yours or the circle, plus a day calendar |
| **Scan** | PhotoKit pass: time near local sunset + warm-sky pixels, then a review sheet to import and rate |
| **Atlas** | MapKit of highly rated spots, with a San Francisco fallback when location is off |
| **Spot pages** | Place profile, averages, pin, recent skies, save, system share, send-to-a-friend |
| **Circle** | Sign in, follow (cloud when the person is a real account), recent public skies, spots they passed to you |
| **Collections** | Pink skies, storm light, favorites, coastal — add from an evening you logged |
| **Reminder** | Local notification a chosen number of minutes before tonight’s sunset |

**Not in this pass:** Stories share cards (image exports), sunrise logging, an admin dashboard.

## Auth and sync (how it behaves)

| State | Journal | Circle |
| --- | --- | --- |
| **Signed out** | SwiftData on this phone, including California seed evenings | Demo circle on device. Follow/share stay local. Sign-in card on Circle |
| **Signed in** | SwiftData is the offline cache. Your new evenings, spots, collections, and saved pins upsert to Postgres. Photos go to the `sunset-photos` bucket | Look up a handle, follow, read that person’s **public** skies. Seed friends stay as “on this phone” and do not write `follows` rows (they are not Auth users) |
| **Offline while signed in** | Logging still writes SwiftData (`needsSync`). Next launch / pull-to-refresh on Circle retries | Follow still sticks locally; the cloud write retries on the next sync |
| **No keys in the build** | Same as signed out. Settings explains the placeholders | Sign-in sheet says keys are missing |

The app **does not require live Supabase credentials** to compile or to walk the journal. Placeholder `YOUR_PROJECT` / `your-anon-key` values are treated as unconfigured.

## Requirements

- macOS with Xcode 15.4 or later
- iOS 17+ Simulator or device
- A development team in Signing & Capabilities if you run on a device (Simulator works with automatic signing empty)
- A Supabase project if you want accounts, sync, and Storage (optional for local preview)

## Run

1. Open `SunsetLog/SunsetLog.xcodeproj` in Xcode.
2. Select the **Sunset Log** scheme and an iPhone simulator (or a device).
3. Run (`⌘R`).
4. On first launch the journal is filled with California seed spots, friends, collections, and fourteen evenings.

To start from a clean seed later: **Circle → gear → Reseed demo data**.

### Plug in Supabase keys

Never commit the service role key or a filled `Secrets.xcconfig`.

1. Copy `SunsetLog/Secrets.xcconfig.example` to `SunsetLog/Secrets.xcconfig`.
2. Put your project URL and **anon** key in it. xcconfig treats `//` as a comment, so write the URL as:

```
SUPABASE_URL = https:/$()/abcdxyz.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

3. `Config.xcconfig` includes `Secrets.xcconfig` when it exists and substitutes `$(SUPABASE_URL)` / `$(SUPABASE_ANON_KEY)` into `Info.plist`.
4. Clean build folder if Xcode cached the placeholders.

You can also set the same two build settings in the Sunset Log target. The anon key is a public client key; RLS is what protects rows.

## Create the Supabase project

1. Create a project at [supabase.com](https://supabase.com).
2. Install the [Supabase CLI](https://supabase.com/docs/guides/cli) and log in (`supabase login`).
3. From this repo:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Or paste `supabase/migrations/20260902000000_init.sql` into the SQL editor and run it once. That file creates:

- tables: `profiles`, `spots`, `sunset_entries`, `collections`, `collection_entries`, `follows`, `saved_spots`, `shared_spot_notes`
- RLS so you only write your own rows; you can read a friend’s **public** entries/spots if you follow them
- catalog California spots (same UUIDs as the iOS seed) so logs at Baker Beach still satisfy `spot_id` FKs
- storage bucket `sunset-photos` (public read, write only into `{auth.uid()}/…`)
- a trigger that inserts `profiles` when `auth.users` gets a row

### Storage bucket

The migration inserts `sunset-photos`. Confirm in **Storage**: public bucket, 10 MB, JPEG/PNG/HEIC/WebP. Object path is `{user_uuid}/{entry_uuid}.jpg`. The public URL is stored on `sunset_entries.photo_url`.

If you create the bucket in the dashboard instead, still run the storage RLS statements in the migration.

### Auth URLs

In **Authentication → URL configuration**:

- Site URL: `sunsetlog://auth-callback`
- Redirect URLs: `sunsetlog://auth-callback`

Magic links open the app via the existing `sunsetlog` URL scheme.

### Sign in with Apple (preferred)

App (Xcode):

1. Apple Developer → Identifiers → App ID `com.sunsetlog.app` → enable **Sign in with Apple**.
2. Xcode target → **Signing & Capabilities** → Sign in with Apple (the repo already has `SunsetLog.entitlements`).
3. For TestFlight / device builds, pick a paid team so the capability is real. Simulator can still use the email magic link.

Supabase:

1. Authentication → Providers → **Apple** → Enable.
2. **Services ID** (or App ID, depending on current Supabase docs) from Apple Developer → Identifiers → Services ID, with Sign in with Apple enabled, return URL:

   `https://YOUR_PROJECT.supabase.co/auth/v1/callback`

3. Create a key (Keys → Sign in with Apple) and paste the Key ID, Team ID, and `.p8` contents into the Supabase Apple provider fields.
4. Bundle ID must match `com.sunsetlog.app`.

Email magic link is the documented fallback while Apple’s capability / Services ID is in progress.

### TestFlight notes

- Archive with the same bundle ID and Apple capability as the App ID.
- Auth redirect stays `sunsetlog://auth-callback` unless you add Associated Domains for https magic links.
- The anon key in the binary is expected; do not embed `SUPABASE_SERVICE_ROLE_KEY`.
- First Apple sign-in is the only time Apple sends the person’s name — the app writes it to `profiles.display_name`.
- Reviewers can walk the journal without signing in. Sign-in is required only for cloud sync and real follows.

## Schema (short)

```
auth.users ──< profiles
profiles ──< spots.created_by          (null = catalog pin)
profiles ──< sunset_entries.user_id
spots    ──< sunset_entries.spot_id
profiles ──< collections.user_id
collections / sunset_entries ──< collection_entries
profiles ──< follows (follower_id, followee_id)
profiles + spots ──< saved_spots
profiles + spots ──< shared_spot_notes
```

Photos: Storage `sunset-photos` / `{user_id}/{entry_id}.jpg` → `sunset_entries.photo_url`.

## Simulator notes

- **Location:** Features → Location → Apple or a custom coordinate. Until then the clock and atlas use San Francisco.
- **Photos:** The simulator library is usually empty. Scan still offers a clearly labeled **demo find** set so you can walk the import/rate flow. On a device, PhotoKit reads the real roll.
- **Notifications:** Grant when asked, or toggle **Sunset tonight reminder** under Circle → Settings. Notifications are local only.
- **Deep link:** From Terminal, with the simulator booted and the app installed:

```bash
xcrun simctl openurl booted "sunsetlog://spot/A1B2C3D4-0001-4000-8000-000000000001"
```

That opens Baker Beach.

## Permissions

Usage strings live in `SunsetLog/SunsetLog/Info.plist` and are merged with generated keys.

| Permission | Why |
| --- | --- |
| Photo library | Camera-roll scan and the log picker; signed-in logs may upload the JPEG you keep |
| Camera | Photograph tonight from the log sheet |
| Location when in use | Golden hour, atlas, tagging a new spot |
| Notifications | Optional “light is leaving” ping |

Declined location does not brick the app: the atlas and clock fall back to the Bay Area seed set and say so. Declined photos shows an editorial empty state with a path to Settings. Limited library access is supported.

## What is real vs mocked

| Piece | Status |
| --- | --- |
| SwiftData journal, spots, collections, prefs | Real, on device (offline cache when signed in) |
| User photographs | JPEG under Application Support; signed-in uploads to Supabase Storage |
| Seed photographs | Bundled cinematic stills (generated for the demo) — not uploaded |
| Solar timing | Real geometry (SunCalc / NOAA civil −0.833°) |
| Map, location, PhotoKit, local notifications, share sheet | Real system APIs |
| Friends, follow, send-a-spot | `SocialClient` protocol. App uses `SupabaseSocialClient` (local write + cloud). `MockSocialClient` remains for previews/tests |
| Auth / accounts | Sign in with Apple + email magic link via Supabase Auth when keys are set |
| Share cards | Deferred. Share a **spot** (URL / share sheet / in-circle send), not a rendered Stories image |

## Architecture

MVVM-ish SwiftUI, iOS 17:

- `Models/` — SwiftData (`Spot`, `SunsetEntry`, `SkyCollection`, `Person`, `SharedSpotNote`, `UserPrefs`)
- `Services/` — solar math, location, PhotoKit scan, notifications, image disk, seed, `SocialClient`
- `Services/Supabase/` — config, Auth, DTOs, Storage upload, `CloudSync`, `SupabaseSocialClient`
- `ViewModels/` — `AppSession`, `Router`
- `Views/` — one folder per surface
- `DesignSystem/` — type, palette, rails, empty and permission states
- `supabase/migrations/` — Postgres + RLS + Storage

Deep links: `sunsetlog://spot/<uuid>`, `sunsetlog://entry/<uuid>`, `sunsetlog://auth-callback`.

Regenerate the Xcode project after adding Swift files:

```bash
python3 scripts/generate_xcodeproj.py
```

The generator keeps the supabase-swift SPM product (`Supabase`, 2.29+) and `Config.xcconfig`.

Tests in `SunsetLogTests` cover solstice sunset hours for San Francisco, streak counting, deep-link parsing, and placeholder key detection.

## Product limits to know

- Seed friends are theater so Circle isn’t empty before anyone has an account. Following them does not insert `follows` (no matching `profiles` row).
- Scan heuristics are intentionally conservative (time window + warmth). They will miss some real sunsets and keep some warm interiors; you always confirm before import.
- Polar / midnight-sun latitudes can yield no civil sunset; the clock says so.
- Share cards (pretty image exports) were deferred on purpose.

## License

Demo project. Seed photography is original generated artwork, not third-party stock.
