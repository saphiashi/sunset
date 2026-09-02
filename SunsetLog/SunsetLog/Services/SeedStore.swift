import Foundation
import SwiftData

@MainActor
enum SeedStore {
    static func bootstrapIfNeeded(_ context: ModelContext) {
        let spots = (try? context.fetch(FetchDescriptor<Spot>())) ?? []
        if spots.isEmpty {
            insertAll(into: context)
            try? context.save()
        }
    }

    static func reset(_ context: ModelContext) {
        deleteAll(SunsetEntry.self, context)
        deleteAll(SkyCollection.self, context)
        deleteAll(SharedSpotNote.self, context)
        deleteAll(Spot.self, context)
        deleteAll(Person.self, context)
        deleteAll(UserPrefs.self, context)
        insertAll(into: context)
        try? context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) {
        let rows = (try? context.fetch(FetchDescriptor<T>())) ?? []
        for row in rows { context.delete(row) }
    }

    private static func insertAll(into context: ModelContext) {
        let spots = makeSpots()
        spots.forEach { context.insert($0) }
        let people = makePeople()
        people.forEach { context.insert($0) }
        let collections = makeCollections()
        collections.forEach { context.insert($0) }
        context.insert(UserPrefs())

        let byID = Dictionary(uniqueKeysWithValues: spots.map { ($0.id, $0) })
        let col = Dictionary(uniqueKeysWithValues: collections.map { ($0.id, $0) })

        for draft in makeEntries() {
            let entry = SunsetEntry(
                capturedAt: draft.when,
                note: draft.note,
                colorScore: draft.color,
                dramaScore: draft.drama,
                overallScore: draft.overall,
                photoBundleName: draft.photo,
                authorHandle: draft.handle,
                authorName: draft.author,
                isMine: draft.mine,
                importedFromLibrary: draft.imported,
                isSeed: true,
                needsSync: false
            )
            if let spot = byID[draft.spot] {
                entry.spot = spot
            }
            for cid in draft.collections {
                col[cid]?.entries.append(entry)
            }
            context.insert(entry)
        }

        if let baker = byID[SeedID.baker] {
            context.insert(
                SharedSpotNote(
                    spotID: baker.id,
                    fromHandle: "maya",
                    toHandle: "you",
                    message: "Stand past the last cypress. Wind is part of the rating."
                )
            )
        }
    }

    private static func makeSpots() -> [Spot] {
        [
            Spot(id: SeedID.baker, name: "Baker Beach", locality: "San Francisco", region: "CA",
                 blurb: "The Golden Gate sits in the frame like it was designed for dusk.",
                 latitude: 37.7936, longitude: -122.4836, isSaved: true, isSeed: true),
            Spot(id: SeedID.twinPeaks, name: "Twin Peaks", locality: "San Francisco", region: "CA",
                 blurb: "A windy saddle over the city. Color hits the fog like a lampshade.",
                 latitude: 37.7544, longitude: -122.4477, isSaved: true, isSeed: true),
            Spot(id: SeedID.griffith, name: "Griffith Observatory", locality: "Los Angeles", region: "CA",
                 blurb: "Basin light, Hollywood sign, and a sky that goes theatrical.",
                 latitude: 34.1184, longitude: -118.3004, isSeed: true),
            Spot(id: SeedID.elMatador, name: "El Matador", locality: "Malibu", region: "CA",
                 blurb: "Sea stacks and a low, pink tide. Arrive early for the stairs.",
                 latitude: 34.0384, longitude: -118.8764, isSaved: true, isSeed: true),
            Spot(id: SeedID.oceanBeach, name: "Ocean Beach", locality: "San Francisco", region: "CA",
                 blurb: "A long, honest horizon. Bonfires after the color dies.",
                 latitude: 37.7594, longitude: -122.5107, isSeed: true),
            Spot(id: SeedID.landsEnd, name: "Lands End", locality: "San Francisco", region: "CA",
                 blurb: "Cypress tunnels and a ruin of a bathhouse facing the gate.",
                 latitude: 37.7879, longitude: -122.5058, isSeed: true),
            Spot(id: SeedID.santaMonica, name: "Santa Monica Pier", locality: "Santa Monica", region: "CA",
                 blurb: "Ferris wheel lights against a gold plate of ocean.",
                 latitude: 34.0100, longitude: -118.4960, isSeed: true),
            Spot(id: SeedID.bixby, name: "Bixby Creek", locality: "Big Sur", region: "CA",
                 blurb: "The arch, the drop, and weather that writes its own score.",
                 latitude: 36.3714, longitude: -121.9016, isSeed: true),
            Spot(id: SeedID.alamo, name: "Alamo Square", locality: "San Francisco", region: "CA",
                 blurb: "Painted ladies, west-facing lawn, city in silhouette.",
                 latitude: 37.7763, longitude: -122.4348, isSeed: true),
            Spot(id: SeedID.tamalpais, name: "Mount Tamalpais", locality: "Mill Valley", region: "CA",
                 blurb: "Above the marine layer. Sometimes the sun sets on a second ocean of fog.",
                 latitude: 37.9235, longitude: -122.5965, isSaved: true, isSeed: true)
        ]
    }

    private static func makePeople() -> [Person] {
        [
            Person(id: SeedID.me, displayName: "You", handle: "you", city: "San Francisco",
                   bio: "Collecting last light.", isFollowing: false, isMe: true, avatarHue: 0.08, isSeed: true),
            Person(id: SeedID.maya, displayName: "Maya Chen", handle: "maya", city: "San Francisco",
                   bio: "Chases pink over the Pacific. Always one ridge too far.",
                   isFollowing: true, avatarHue: 0.92, isSeed: true),
            Person(id: SeedID.jordan, displayName: "Jordan Hale", handle: "jordan", city: "Los Angeles",
                   bio: "Drama over color. Storms preferred.",
                   isFollowing: true, avatarHue: 0.62, isSeed: true),
            Person(id: SeedID.priya, displayName: "Priya Nair", handle: "priya", city: "Oakland",
                   bio: "Notes first, photos second.",
                   isFollowing: true, avatarHue: 0.12, isSeed: true),
            Person(id: SeedID.leo, displayName: "Leo Park", handle: "leo", city: "Malibu",
                   bio: "Knows every legal pull-out on PCH.",
                   isFollowing: false, avatarHue: 0.48, isSeed: true)
        ]
    }

    private static func makeCollections() -> [SkyCollection] {
        [
            SkyCollection(id: SeedID.pinkSkies, name: "Pink skies", detail: "Wash, blush, leftover daylight.",
                          symbol: "heart.fill", accentToken: "rose", isSeed: true),
            SkyCollection(id: SeedID.stormLight, name: "Storm light", detail: "When the weather writes.",
                          symbol: "cloud.bolt.fill", accentToken: "storm", isSeed: true),
            SkyCollection(id: SeedID.favorites, name: "Favorites", detail: "The ones you keep returning to.",
                          symbol: "star.fill", accentToken: "gold", isSeed: true),
            SkyCollection(id: SeedID.coastal, name: "Coastal", detail: "West-facing water.",
                          symbol: "water.waves", accentToken: "ember", isSeed: true)
        ]
    }

    private struct Draft {
        var when: Date
        var note: String
        var color: Double
        var drama: Double
        var overall: Double
        var photo: String
        var handle: String
        var author: String
        var mine: Bool
        var imported: Bool
        var spot: UUID
        var collections: [UUID]
    }

    private static func evening(_ daysAgo: Int, hour: Int = 19, minute: Int = 18) -> Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        var c = cal.dateComponents([.year, .month, .day], from: day)
        c.hour = hour
        c.minute = minute
        return cal.date(from: c) ?? day
    }

    private static func makeEntries() -> [Draft] {
        [
            Draft(when: evening(0, hour: 19, minute: 22), note: "A quiet gold. The gate went black first.",
                  color: 8.4, drama: 6.2, overall: 8.1, photo: "baker_beach",
                  handle: "you", author: "You", mine: true, imported: false,
                  spot: SeedID.baker, collections: [SeedID.favorites, SeedID.coastal]),
            Draft(when: evening(1, hour: 19, minute: 28), note: "Fog sat under us like a second tide.",
                  color: 7.6, drama: 8.8, overall: 8.4, photo: "tamalpais",
                  handle: "you", author: "You", mine: true, imported: false,
                  spot: SeedID.tamalpais, collections: [SeedID.stormLight, SeedID.favorites]),
            Draft(when: evening(2, hour: 19, minute: 31), note: "Pink for less than four minutes. Worth it.",
                  color: 9.2, drama: 5.4, overall: 8.6, photo: "pink_wash",
                  handle: "you", author: "You", mine: true, imported: true,
                  spot: SeedID.oceanBeach, collections: [SeedID.pinkSkies, SeedID.coastal]),
            Draft(when: evening(3, hour: 19, minute: 36), note: "The painted ladies held the last stripe of light.",
                  color: 7.1, drama: 6.8, overall: 7.4, photo: "alamo",
                  handle: "you", author: "You", mine: true, imported: false,
                  spot: SeedID.alamo, collections: []),
            Draft(when: evening(6, hour: 19, minute: 40), note: "Wind loud enough to erase the city.",
                  color: 8.0, drama: 7.9, overall: 8.2, photo: "twin_peaks",
                  handle: "you", author: "You", mine: true, imported: false,
                  spot: SeedID.twinPeaks, collections: [SeedID.pinkSkies]),
            Draft(when: evening(0, hour: 19, minute: 10), note: "Cypress going ink. The ocean kept a peach rim.",
                  color: 8.8, drama: 7.2, overall: 8.7, photo: "lands_end",
                  handle: "maya", author: "Maya Chen", mine: false, imported: false,
                  spot: SeedID.landsEnd, collections: []),
            Draft(when: evening(1, hour: 19, minute: 4), note: "Same beach, different weather. Always.",
                  color: 7.9, drama: 6.0, overall: 7.8, photo: "ocean_beach",
                  handle: "maya", author: "Maya Chen", mine: false, imported: false,
                  spot: SeedID.oceanBeach, collections: []),
            Draft(when: evening(2, hour: 19, minute: 48), note: "Basin went copper. Helicopters, of course.",
                  color: 8.6, drama: 7.5, overall: 8.3, photo: "griffith",
                  handle: "jordan", author: "Jordan Hale", mine: false, imported: false,
                  spot: SeedID.griffith, collections: []),
            Draft(when: evening(4, hour: 19, minute: 12), note: "A bruise of a sky. I stayed for the after.",
                  color: 6.4, drama: 9.4, overall: 8.8, photo: "storm_light",
                  handle: "jordan", author: "Jordan Hale", mine: false, imported: false,
                  spot: SeedID.bixby, collections: [SeedID.stormLight]),
            Draft(when: evening(3, hour: 19, minute: 8), note: "Notes: cold, salt, one good minute of rose.",
                  color: 8.9, drama: 5.8, overall: 8.0, photo: "el_matador",
                  handle: "priya", author: "Priya Nair", mine: false, imported: false,
                  spot: SeedID.elMatador, collections: [SeedID.pinkSkies, SeedID.coastal]),
            Draft(when: evening(5, hour: 19, minute: 20), note: "Pier lights came on before the color left.",
                  color: 7.7, drama: 6.6, overall: 7.5, photo: "santa_monica",
                  handle: "leo", author: "Leo Park", mine: false, imported: false,
                  spot: SeedID.santaMonica, collections: [SeedID.coastal]),
            Draft(when: evening(7, hour: 19, minute: 6), note: "Gold hour that actually was.",
                  color: 9.0, drama: 6.1, overall: 8.9, photo: "gold_hour",
                  handle: "maya", author: "Maya Chen", mine: false, imported: false,
                  spot: SeedID.baker, collections: [SeedID.favorites, SeedID.coastal]),
            Draft(when: evening(8, hour: 19, minute: 33), note: "Lavender, then nothing. A clean ending.",
                  color: 7.4, drama: 5.2, overall: 7.2, photo: "lavender_dusk",
                  handle: "you", author: "You", mine: true, imported: true,
                  spot: SeedID.landsEnd, collections: []),
            Draft(when: evening(9, hour: 19, minute: 15), note: "The arch took the last highlight.",
                  color: 7.2, drama: 8.6, overall: 8.1, photo: "bixby",
                  handle: "jordan", author: "Jordan Hale", mine: false, imported: false,
                  spot: SeedID.bixby, collections: [SeedID.stormLight])
        ]
    }
}
