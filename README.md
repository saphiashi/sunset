# Sunset Log

A SwiftUI journal for last light — photograph a sunset, rate the color and the weather, keep the places, and see who else was looking up.

The working title stayed. The voice did not: quieter labels, large photographs, scores you can feel.

## What is in this build

All day-one features are navigable on first launch from seed data.

| Surface | What it does |
| --- | --- |
| **Tonight** | Golden-hour countdown from your location (SunCalc / NOAA civil sunset), streak, recent evenings |
| **Log** | Photo (library or camera), spot, date, note, tactile Color / Drama / Overall rails (1.0–10.0) |
| **Journal** | Feed of yours or the circle, plus a day calendar |
| **Scan** | PhotoKit pass: time near local sunset + warm-sky pixels, then a review sheet to import and rate |
| **Atlas** | MapKit of highly rated spots, with a San Francisco fallback when location is off |
| **Spot pages** | Place profile, averages, pin, recent skies, save, system share, send-to-a-friend |
| **Circle** | Follow mock friends, their recent sunsets, spots they passed to you |
| **Collections** | Pink skies, storm light, favorites, coastal — add from an evening you logged |
| **Reminder** | Local notification a chosen number of minutes before tonight’s sunset |

**Not in this pass:** Stories share cards (image exports), sunrise logging, a real multi-user backend.

## Requirements

- macOS with Xcode 15.4 or later
- iOS 17+ Simulator or device
- A development team in Signing & Capabilities if you run on a device (Simulator works with automatic signing empty)

## Run

1. Open `SunsetLog/SunsetLog.xcodeproj` in Xcode.
2. Select the **Sunset Log** scheme and an iPhone simulator (or a device).
3. Run (`⌘R`).
4. On first launch the journal is filled with California seed spots, friends, collections, and fourteen evenings.

To start from a clean seed later: **Circle → gear → Reseed demo data**.

### Simulator notes

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
| Photo library | Camera-roll scan and the log picker |
| Camera | Photograph tonight from the log sheet |
| Location when in use | Golden hour, atlas, tagging a new spot |
| Notifications | Optional “light is leaving” ping |

Declined location does not brick the app: the atlas and clock fall back to the Bay Area seed set and say so. Declined photos shows an editorial empty state with a path to Settings. Limited library access is supported.

## What is real vs mocked

| Piece | Status |
| --- | --- |
| SwiftData journal, spots, collections, prefs | Real, on device |
| User photographs | Real JPEG files under Application Support |
| Seed photographs | Bundled cinematic stills (generated for the demo) |
| Solar timing | Real geometry (SunCalc / NOAA civil −0.833°) |
| Map, location, PhotoKit, local notifications, share sheet | Real system APIs |
| Friends, follow, send-a-spot | **Mock.** `SocialClient` is the seam; `MockSocialClient` writes SwiftData. Swap the client to go online. |
| Auth / accounts | None. You are `@you`. |
| Share cards | Deferred. Share a **spot** (URL / share sheet / in-circle send), not a rendered Stories image. |

## Architecture

MVVM-ish SwiftUI, iOS 17:

- `Models/` — SwiftData (`Spot`, `SunsetEntry`, `SkyCollection`, `Person`, `SharedSpotNote`, `UserPrefs`)
- `Services/` — solar math, location, PhotoKit scan, notifications, image disk, seed, `SocialClient`
- `ViewModels/` — `AppSession`, `Router`
- `Views/` — one folder per surface
- `DesignSystem/` — type, palette, rails, empty and permission states

Deep links: `sunsetlog://spot/<uuid>` and `sunsetlog://entry/<uuid>`.

Tests in `SunsetLogTests` cover solstice sunset hours for San Francisco, streak counting, and deep-link parsing.

## Product limits to know

- Social is local theater so the UI can be finished without a backend.
- Scan heuristics are intentionally conservative (time window + warmth). They will miss some real sunsets and keep some warm interiors; you always confirm before import.
- Polar / midnight-sun latitudes can yield no civil sunset; the clock says so.
- Share cards (pretty image exports) were deferred on purpose.

## License

Demo project. Seed photography is original generated artwork, not third-party stock.
