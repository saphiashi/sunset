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

    func setFollowing(personID: UUID, isFollowing: Bool, context: ModelContext) throws {
        try local.setFollowing(personID: personID, isFollowing: isFollowing, context: context)
        guard auth.isSignedIn, let client = auth.client, let userID = auth.userID else { return }
        let people = try context.fetch(FetchDescriptor<Person>())
        guard let person = people.first(where: { $0.id == personID }), !person.isSeed else { return }
        Task {
            do {
                if isFollowing {
                    try await client.from("follows").upsert(
                        FollowRow(followerId: userID, followeeId: personID)
                    ).execute()
                } else {
                    try await client.from("follows")
                        .delete()
                        .eq("follower_id", value: userID.uuidString.lowercased())
                        .eq("followee_id", value: personID.uuidString.lowercased())
                        .execute()
                }
                await cloud.syncNow()
            } catch {
                // Local follow already stuck; next full sync retries.
            }
        }
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
