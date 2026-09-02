import Foundation
import Observation
import SwiftData
import Supabase

/// SwiftData is the on-device journal. When a session exists, this pushes the
/// signed-in user's writes and pulls friends' public skies into the same store.
@MainActor
@Observable
final class CloudSync {
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    private(set) var lastError: String?
    private(set) var lastStatus: String = "Local journal"

    private let auth: AuthController
    private var context: ModelContext?
    private var syncTask: Task<Void, Never>?

    init(auth: AuthController) {
        self.auth = auth
    }

    private var queued = false

    func attach(_ context: ModelContext) {
        self.context = context
    }

    /// Debounced so logging, follows, and collection toggles can fire together.
    func schedule() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func syncNow() async {
        guard let client = auth.client, auth.isSignedIn, let userID = auth.userID else {
            lastStatus = auth.isConfigured
                ? "Signed out — journal stays on this phone"
                : "No Supabase keys — local only"
            return
        }
        guard let context else { return }
        if isSyncing {
            queued = true
            return
        }
        isSyncing = true
        lastError = nil
        lastStatus = "Syncing…"
        defer {
            isSyncing = false
            if queued {
                queued = false
                schedule()
            }
        }

        do {
            await applyProfileToMe(context: context)
            try await pushAll(client: client, userID: userID, context: context)
            try await pullAll(client: client, userID: userID, context: context)
            try context.save()
            lastSyncedAt = Date()
            lastStatus = "Synced just now"
        } catch {
            lastError = error.localizedDescription
            lastStatus = "Couldn’t reach the sky — will retry"
        }
    }

    func lookupHandle(_ raw: String) async -> ProfileRow? {
        guard let client = auth.client, auth.isSignedIn else { return nil }
        let handle = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard handle.count >= 2 else { return nil }
        do {
            let rows: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .eq("handle", value: handle)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func rememberRemotePerson(_ row: ProfileRow, context: ModelContext) {
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        if let existing = people.first(where: { $0.id == row.id }) {
            existing.displayName = row.displayName
            existing.handle = row.handle
            existing.city = row.city
            existing.bio = row.bio
            existing.avatarHue = row.avatarHue
            existing.isSeed = false
        } else {
            context.insert(
                Person(
                    id: row.id,
                    displayName: row.displayName,
                    handle: row.handle,
                    city: row.city,
                    bio: row.bio,
                    avatarHue: row.avatarHue,
                    isSeed: false
                )
            )
        }
    }

    // MARK: - Push

    private func pushAll(client: SupabaseClient, userID: UUID, context: ModelContext) async throws {
        let spots = (try? context.fetch(FetchDescriptor<Spot>())) ?? []
        for spot in spots where !spot.isSeed && spot.needsSync {
            try await client.from("spots").upsert(spotRow(spot, userID: userID)).execute()
            spot.needsSync = false
        }

        let entries = (try? context.fetch(FetchDescriptor<SunsetEntry>())) ?? []
        for entry in entries where shouldPush(entry) {
            try await pushEntry(entry, client: client, userID: userID)
        }

        let saved = spots.filter(\.isSaved)
        let savedRows = saved.map { SavedSpotRow(userId: userID, spotId: $0.id) }
        if !savedRows.isEmpty {
            try await client.from("saved_spots").upsert(savedRows).execute()
        }
        for spot in spots where !spot.isSaved {
            try await client.from("saved_spots")
                .delete()
                .eq("user_id", value: userID.uuidString.lowercased())
                .eq("spot_id", value: spot.id.uuidString.lowercased())
                .execute()
        }

        let collections = (try? context.fetch(FetchDescriptor<SkyCollection>())) ?? []
        for collection in collections where !collection.isSeed {
            try await client.from("collections").upsert(collectionRow(collection, userID: userID)).execute()
            for entry in collection.entries where entry.isMine && !isSeedPhoto(entry) {
                try await client.from("collection_entries").upsert(
                    CollectionEntryRow(collectionId: collection.id, entryId: entry.id)
                ).execute()
            }
        }

        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        for person in people where !person.isMe && !person.isSeed {
            if person.isFollowing {
                try await client.from("follows").upsert(
                    FollowRow(followerId: userID, followeeId: person.id)
                ).execute()
            }
        }
    }

    private func pushEntry(_ entry: SunsetEntry, client: SupabaseClient, userID: UUID) async throws {
        var photoURL = entry.photoURL
        var photoPath: String?
        if photoURL == nil, let data = PhotoUploader.jpegData(for: entry) {
            let uploaded = try await PhotoUploader.upload(
                data: data,
                userID: userID,
                entryID: entry.id,
                client: client
            )
            photoURL = uploaded.publicURL.absoluteString
            photoPath = uploaded.path
            entry.photoURL = photoURL
        }
        let row = EntryRow(
            id: entry.id,
            userId: userID,
            spotId: entry.spot?.id,
            capturedAt: entry.capturedAt,
            note: entry.note,
            colorScore: entry.colorScore,
            dramaScore: entry.dramaScore,
            overallScore: entry.overallScore,
            photoURL: photoURL,
            photoPath: photoPath,
            imported: entry.importedFromLibrary,
            isPublic: true
        )
        try await client.from("sunset_entries").upsert(row).execute()
        entry.needsSync = false
        entry.authorHandle = auth.profile?.handle ?? entry.authorHandle
        entry.authorName = auth.profile?.displayName ?? entry.authorName
    }

    // MARK: - Pull

    private func pullAll(client: SupabaseClient, userID: UUID, context: ModelContext) async throws {
        let mySpots: [SpotRow] = try await client
            .from("spots")
            .select()
            .eq("created_by", value: userID.uuidString.lowercased())
            .execute()
            .value
        for row in mySpots {
            upsertSpot(row, context: context, markSaved: false)
        }

        let myEntries: [EntryRow] = try await client
            .from("sunset_entries")
            .select()
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value
        for row in myEntries {
            upsertEntry(row, mine: true, context: context)
        }

        let myCollections: [CollectionRow] = try await client
            .from("collections")
            .select()
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value
        for row in myCollections {
            upsertCollection(row, context: context)
        }

        let membership: [CollectionEntryRow] = try await client
            .from("collection_entries")
            .select()
            .execute()
            .value
        applyMembership(membership, context: context)

        let saved: [SavedSpotRow] = try await client
            .from("saved_spots")
            .select()
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value
        let savedIDs = Set(saved.map(\.spotId))
        let spots = (try? context.fetch(FetchDescriptor<Spot>())) ?? []
        for spot in spots {
            if savedIDs.contains(spot.id) {
                spot.isSaved = true
            }
        }

        let follows: [FollowRow] = try await client
            .from("follows")
            .select()
            .eq("follower_id", value: userID.uuidString.lowercased())
            .execute()
            .value

        for follow in follows {
            let profiles: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .eq("id", value: follow.followeeId.uuidString.lowercased())
                .limit(1)
                .execute()
                .value
            if let profile = profiles.first {
                rememberRemotePerson(profile, context: context)
            }
            let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
            people.first(where: { $0.id == follow.followeeId })?.isFollowing = true

            let friendEntries: [EntryRow] = try await client
                .from("sunset_entries")
                .select()
                .eq("user_id", value: follow.followeeId.uuidString.lowercased())
                .order("captured_at", ascending: false)
                .limit(24)
                .execute()
                .value
            for row in friendEntries {
                if let spotID = row.spotId {
                    let friendSpots: [SpotRow] = try await client
                        .from("spots")
                        .select()
                        .eq("id", value: spotID.uuidString.lowercased())
                        .limit(1)
                        .execute()
                        .value
                    if let spot = friendSpots.first {
                        upsertSpot(spot, context: context, markSaved: false)
                    }
                }
                upsertEntry(row, mine: false, context: context)
            }
        }

        let notes: [SharedNoteRow] = try await client
            .from("shared_spot_notes")
            .select()
            .eq("to_user_id", value: userID.uuidString.lowercased())
            .execute()
            .value
        let existingNotes = (try? context.fetch(FetchDescriptor<SharedSpotNote>())) ?? []
        for row in notes {
            if existingNotes.contains(where: { $0.id == row.id }) { continue }
            context.insert(
                SharedSpotNote(
                    id: row.id,
                    spotID: row.spotId,
                    fromHandle: row.fromHandle,
                    toHandle: row.toHandle,
                    message: row.message,
                    sentAt: row.createdAt
                )
            )
        }
    }

    // MARK: - Local mapping

    private func applyProfileToMe(context: ModelContext) async {
        guard let profile = auth.profile else { return }
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        if let me = people.first(where: \.isMe) {
            me.displayName = profile.displayName
            me.handle = profile.handle
        }
    }

    private func upsertSpot(_ row: SpotRow, context: ModelContext, markSaved: Bool) {
        let spots = (try? context.fetch(FetchDescriptor<Spot>())) ?? []
        if let existing = spots.first(where: { $0.id == row.id }) {
            if !existing.isSeed {
                existing.name = row.name
                existing.locality = row.locality
                existing.region = row.region
                existing.blurb = row.blurb
                existing.latitude = row.latitude
                existing.longitude = row.longitude
            }
            existing.photoURL = row.photoURL
            if markSaved { existing.isSaved = true }
            return
        }
        let spot = Spot(
            id: row.id,
            name: row.name,
            locality: row.locality,
            region: row.region,
            blurb: row.blurb,
            latitude: row.latitude,
            longitude: row.longitude,
            isSaved: markSaved,
            isSeed: row.createdBy == nil,
            photoURL: row.photoURL
        )
        context.insert(spot)
    }

    private func upsertEntry(_ row: EntryRow, mine: Bool, context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<SunsetEntry>())) ?? []
        if let existing = entries.first(where: { $0.id == row.id }) {
            if existing.isMine && existing.needsSync { return }
            existing.capturedAt = row.capturedAt
            existing.note = row.note
            existing.colorScore = row.colorScore
            existing.dramaScore = row.dramaScore
            existing.overallScore = row.overallScore
            existing.photoURL = row.photoURL
            existing.importedFromLibrary = row.imported
            existing.isMine = mine
            existing.needsSync = false
            if let spotID = row.spotId {
                let spots = (try? context.fetch(FetchDescriptor<Spot>())) ?? []
                existing.spot = spots.first(where: { $0.id == spotID })
            }
            return
        }
        let author = authorFor(userID: row.userId, context: context, mine: mine)
        let entry = SunsetEntry(
            id: row.id,
            capturedAt: row.capturedAt,
            note: row.note,
            colorScore: row.colorScore,
            dramaScore: row.dramaScore,
            overallScore: row.overallScore,
            photoURL: row.photoURL,
            authorHandle: author.handle,
            authorName: author.displayName,
            isMine: mine,
            importedFromLibrary: row.imported,
            needsSync: false
        )
        if let spotID = row.spotId {
            let spots = (try? context.fetch(FetchDescriptor<Spot>())) ?? []
            entry.spot = spots.first(where: { $0.id == spotID })
        }
        context.insert(entry)
    }

    private func upsertCollection(_ row: CollectionRow, context: ModelContext) {
        let collections = (try? context.fetch(FetchDescriptor<SkyCollection>())) ?? []
        if let existing = collections.first(where: { $0.id == row.id }) {
            existing.name = row.name
            existing.detail = row.detail
            existing.symbol = row.symbol
            existing.accentToken = row.accentToken
            return
        }
        context.insert(
            SkyCollection(
                id: row.id,
                name: row.name,
                detail: row.detail,
                symbol: row.symbol,
                accentToken: row.accentToken,
                isSeed: false
            )
        )
    }

    private func applyMembership(_ rows: [CollectionEntryRow], context: ModelContext) {
        let collections = (try? context.fetch(FetchDescriptor<SkyCollection>())) ?? []
        let entries = (try? context.fetch(FetchDescriptor<SunsetEntry>())) ?? []
        for row in rows {
            guard let collection = collections.first(where: { $0.id == row.collectionId }) else { continue }
            guard let entry = entries.first(where: { $0.id == row.entryId }) else { continue }
            if !collection.entries.contains(where: { $0.id == entry.id }) {
                collection.entries.append(entry)
            }
        }
    }

    private func authorFor(userID: UUID, context: ModelContext, mine: Bool) -> (handle: String, displayName: String) {
        if mine, let profile = auth.profile {
            return (profile.handle, profile.displayName)
        }
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        if let person = people.first(where: { $0.id == userID }) {
            return (person.handle, person.displayName)
        }
        return ("sky", "Someone")
    }

    private func shouldPush(_ entry: SunsetEntry) -> Bool {
        entry.isMine && !isSeedPhoto(entry) && entry.needsSync
    }

    private func isSeedPhoto(_ entry: SunsetEntry) -> Bool {
        entry.isSeed || (entry.photoBundleName != nil && entry.photoFileName == nil && entry.photoURL == nil)
    }

    private func spotRow(_ spot: Spot, userID: UUID) -> SpotRow {
        SpotRow(
            id: spot.id,
            name: spot.name,
            locality: spot.locality,
            region: spot.region,
            blurb: spot.blurb,
            latitude: spot.latitude,
            longitude: spot.longitude,
            createdBy: userID,
            isPublic: true,
            photoURL: spot.photoURL
        )
    }

    private func collectionRow(_ collection: SkyCollection, userID: UUID) -> CollectionRow {
        CollectionRow(
            id: collection.id,
            userId: userID,
            name: collection.name,
            detail: collection.detail,
            symbol: collection.symbol,
            accentToken: collection.accentToken
        )
    }
}
