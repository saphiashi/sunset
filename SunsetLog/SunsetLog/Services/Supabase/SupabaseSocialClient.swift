import Foundation
import SwiftData
import Supabase

/// Writes SwiftData first (so the UI stays snappy offline), then asks CloudSync
/// to upsert when a session exists. Seed people have no `profiles` row, so
/// following them stays local-only.
@MainActor
final class SupabaseSocialClient: SocialClient {
    private let local = MockSocialClient()
    private let cloud: CloudSync
    private let auth: AuthController

    init(cloud: CloudSync, auth: AuthController) {
        self.cloud = cloud
        self.auth = auth
    }

    /// The follow/unfollow itself is pushed by CloudSync (`followNeedsSync`), so
    /// an offline change retries on the next sync instead of being dropped.
    func setFollowing(personID: UUID, isFollowing: Bool, context: ModelContext) throws {
        try local.setFollowing(personID: personID, isFollowing: isFollowing, context: context)
        let people = try context.fetch(FetchDescriptor<Person>())
        guard let person = people.first(where: { $0.id == personID }), !person.isSeed else { return }
        person.followNeedsSync = true
        try context.save()
        guard auth.isSignedIn else { return }
        Task { await cloud.syncNow() }
    }

    /// Like follows, accept/decline/remove are pushed by CloudSync (`followerNeedsSync`),
    /// so a failed write retries instead of leaving the follower with access.
    func acceptFollower(personID: UUID, context: ModelContext) throws {
        try local.acceptFollower(personID: personID, context: context)
        try markFollowerChange(personID, context: context)
    }

    func removeFollower(personID: UUID, context: ModelContext) throws {
        try local.removeFollower(personID: personID, context: context)
        try markFollowerChange(personID, context: context)
    }

    private func markFollowerChange(_ personID: UUID, context: ModelContext) throws {
        let people = try context.fetch(FetchDescriptor<Person>())
        guard let person = people.first(where: { $0.id == personID }), !person.isSeed else { return }
        person.followerNeedsSync = true
        try context.save()
        guard auth.isSignedIn else { return }
        Task { await cloud.syncNow() }
    }

    func shareSpot(
        spotID: UUID,
        to personID: UUID,
        message: String,
        from handle: String,
        context: ModelContext
    ) throws {
        try local.shareSpot(spotID: spotID, to: personID, message: message, from: handle, context: context)
        guard auth.isSignedIn, let client = auth.client, let userID = auth.userID else { return }
        let people = try context.fetch(FetchDescriptor<Person>())
        guard let person = people.first(where: { $0.id == personID }), !person.isSeed else { return }
        let row = SharedNoteRow(
            id: UUID(),
            spotId: spotID,
            fromUserId: userID,
            toUserId: personID,
            fromHandle: auth.profile?.handle ?? handle,
            toHandle: person.handle,
            message: message,
            createdAt: Date()
        )
        Task {
            do {
                try await client.from("shared_spot_notes").insert(row).execute()
            } catch {
                // Kept locally in SharedSpotNote.
            }
        }
    }
}
