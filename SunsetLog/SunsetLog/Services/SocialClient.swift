import Foundation
import SwiftData

/// Network seam. Views talk only to this protocol so a real backend can replace the mock.
protocol SocialClient: AnyObject {
    func setFollowing(personID: UUID, isFollowing: Bool, context: ModelContext) throws
    func acceptFollower(personID: UUID, context: ModelContext) throws
    /// Declines a pending request or removes an accepted follower.
    func removeFollower(personID: UUID, context: ModelContext) throws
    func shareSpot(spotID: UUID, to personID: UUID, message: String, from handle: String, context: ModelContext) throws
}

/// Local, SwiftData-backed stand-in. Seed people live in `SeedStore`.
final class MockSocialClient: SocialClient {
    func setFollowing(personID: UUID, isFollowing: Bool, context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<Person>())
        guard let person = all.first(where: { $0.id == personID && !$0.isMe }) else { return }
        person.isFollowing = isFollowing
        person.followPending = isFollowing && person.isPrivate
        try context.save()
    }

    func acceptFollower(personID: UUID, context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<Person>())
        guard let person = all.first(where: { $0.id == personID && !$0.isMe }) else { return }
        person.requestedToFollowMe = false
        person.followsMe = true
        try context.save()
    }

    func removeFollower(personID: UUID, context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<Person>())
        guard let person = all.first(where: { $0.id == personID && !$0.isMe }) else { return }
        person.requestedToFollowMe = false
        person.followsMe = false
        try context.save()
    }

    func shareSpot(
        spotID: UUID,
        to personID: UUID,
        message: String,
        from handle: String,
        context: ModelContext
    ) throws {
        let people = try context.fetch(FetchDescriptor<Person>())
        guard let person = people.first(where: { $0.id == personID }) else { return }
        let note = SharedSpotNote(
            spotID: spotID,
            fromHandle: handle,
            toHandle: person.handle,
            message: message
        )
        context.insert(note)
        try context.save()
    }
}
