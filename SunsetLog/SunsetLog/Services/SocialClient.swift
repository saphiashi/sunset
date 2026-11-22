import Foundation
import SwiftData

/// Network seam. Views talk only to this protocol so a real backend can replace the mock.
protocol SocialClient: AnyObject {
    func setFollowing(personID: UUID, isFollowing: Bool, context: ModelContext) throws
    /// Blocking unfollows both ways and drops their skies from this phone.
    func setBlocked(personID: UUID, isBlocked: Bool, context: ModelContext) throws
    func report(personID: UUID?, entryID: UUID?, reason: ReportReason, details: String) async throws
    func shareSpot(spotID: UUID, to personID: UUID, message: String, from handle: String, context: ModelContext) throws
}

enum ReportReason: String, CaseIterable, Identifiable, Sendable {
    case spam, harassment, inappropriate, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment or bullying"
        case .inappropriate: return "Nudity or graphic content"
        case .other: return "Something else"
        }
    }
}

/// Local, SwiftData-backed stand-in. Seed people live in `SeedStore`.
final class MockSocialClient: SocialClient {
    func setFollowing(personID: UUID, isFollowing: Bool, context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<Person>())
        guard let person = all.first(where: { $0.id == personID && !$0.isMe }) else { return }
        person.isFollowing = isFollowing
        try context.save()
    }

    func setBlocked(personID: UUID, isBlocked: Bool, context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<Person>())
        guard let person = all.first(where: { $0.id == personID && !$0.isMe }) else { return }
        person.isBlocked = isBlocked
        if isBlocked {
            person.isFollowing = false
            let entries = try context.fetch(FetchDescriptor<SunsetEntry>())
            for entry in entries where !entry.isMine && entry.authorHandle == person.handle {
                context.delete(entry)
            }
        }
        try context.save()
    }

    func report(personID: UUID?, entryID: UUID?, reason: ReportReason, details: String) async throws {}

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
