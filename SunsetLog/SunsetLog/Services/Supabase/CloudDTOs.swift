import Foundation

struct ProfileRow: Codable, Sendable, Equatable {
    var id: UUID
    var handle: String
    var displayName: String
    var city: String
    var bio: String
    var avatarHue: Double

    enum CodingKeys: String, CodingKey {
        case id, handle, city, bio
        case displayName = "display_name"
        case avatarHue = "avatar_hue"
    }
}

struct SpotRow: Codable, Sendable {
    var id: UUID
    var name: String
    var locality: String
    var region: String
    var blurb: String
    var latitude: Double
    var longitude: Double
    var createdBy: UUID?
    var isPublic: Bool
    var photoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, locality, region, blurb, latitude, longitude
        case createdBy = "created_by"
        case isPublic = "is_public"
        case photoURL = "photo_url"
    }
}

struct EntryRow: Codable, Sendable {
    var id: UUID
    var userId: UUID
    var spotId: UUID?
    var capturedAt: Date
    var note: String
    var colorScore: Double
    var dramaScore: Double
    var overallScore: Double
    var photoURL: String?
    var photoPath: String?
    var imported: Bool
    var isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case id, note, imported
        case userId = "user_id"
        case spotId = "spot_id"
        case capturedAt = "captured_at"
        case colorScore = "color_score"
        case dramaScore = "drama_score"
        case overallScore = "overall_score"
        case photoURL = "photo_url"
        case photoPath = "photo_path"
        case isPublic = "is_public"
    }
}

struct CollectionRow: Codable, Sendable {
    var id: UUID
    var userId: UUID
    var name: String
    var detail: String
    var symbol: String
    var accentToken: String

    enum CodingKeys: String, CodingKey {
        case id, name, detail, symbol
        case userId = "user_id"
        case accentToken = "accent_token"
    }
}

struct CollectionEntryRow: Codable, Sendable {
    var collectionId: UUID
    var entryId: UUID

    enum CodingKeys: String, CodingKey {
        case collectionId = "collection_id"
        case entryId = "entry_id"
    }
}

struct FollowRow: Codable, Sendable {
    var followerId: UUID
    var followeeId: UUID

    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followeeId = "followee_id"
    }
}

struct SavedSpotRow: Codable, Sendable {
    var userId: UUID
    var spotId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case spotId = "spot_id"
    }
}

struct SharedNoteRow: Codable, Sendable {
    var id: UUID
    var spotId: UUID
    var fromUserId: UUID
    var toUserId: UUID
    var fromHandle: String
    var toHandle: String
    var message: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, message
        case spotId = "spot_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case fromHandle = "from_handle"
        case toHandle = "to_handle"
        case createdAt = "created_at"
    }
}
