import Foundation
import SwiftData
import SwiftUI
import CoreLocation

@Model
final class Spot {
    @Attribute(.unique) var id: UUID
    var name: String
    var locality: String
    var region: String
    var blurb: String
    var latitude: Double
    var longitude: Double
    var isSaved: Bool
    var isSeed: Bool
    var createdAt: Date
    var photoURL: String?
    var needsSync: Bool

    @Relationship(deleteRule: .nullify, inverse: \SunsetEntry.spot)
    var entries: [SunsetEntry]

    init(
        id: UUID = UUID(),
        name: String,
        locality: String,
        region: String,
        blurb: String,
        latitude: Double,
        longitude: Double,
        isSaved: Bool = false,
        isSeed: Bool = false,
        createdAt: Date = .now,
        photoURL: String? = nil,
        needsSync: Bool = false
    ) {
        self.id = id
        self.name = name
        self.locality = locality
        self.region = region
        self.blurb = blurb
        self.latitude = latitude
        self.longitude = longitude
        self.isSaved = isSaved
        self.isSeed = isSeed
        self.createdAt = createdAt
        self.photoURL = photoURL
        self.needsSync = needsSync
        self.entries = []
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var placeLine: String {
        "\(locality), \(region)"
    }

    var ratedEntries: [SunsetEntry] {
        entries
    }

    var averageOverall: Double? {
        guard !entries.isEmpty else { return nil }
        return entries.map(\.overallScore).reduce(0, +) / Double(entries.count)
    }

    var averageColor: Double? {
        guard !entries.isEmpty else { return nil }
        return entries.map(\.colorScore).reduce(0, +) / Double(entries.count)
    }

    var averageDrama: Double? {
        guard !entries.isEmpty else { return nil }
        return entries.map(\.dramaScore).reduce(0, +) / Double(entries.count)
    }

    var heroPhotoName: String? {
        entries.sorted { $0.overallScore > $1.overallScore }.first?.resolvedBundleName
    }
}

@Model
final class SunsetEntry {
    @Attribute(.unique) var id: UUID
    var capturedAt: Date
    var note: String
    var colorScore: Double
    var dramaScore: Double
    var overallScore: Double
    var photoBundleName: String?
    var photoFileName: String?
    var photoURL: String?
    var photoAssetId: String?
    var authorHandle: String
    var authorName: String
    var isMine: Bool
    var importedFromLibrary: Bool
    var isSeed: Bool
    var needsSync: Bool
    var createdAt: Date

    var spot: Spot?

    @Relationship(inverse: \SkyCollection.entries)
    var collections: [SkyCollection]

    init(
        id: UUID = UUID(),
        capturedAt: Date,
        note: String,
        colorScore: Double,
        dramaScore: Double,
        overallScore: Double,
        photoBundleName: String? = nil,
        photoFileName: String? = nil,
        photoURL: String? = nil,
        photoAssetId: String? = nil,
        authorHandle: String,
        authorName: String,
        isMine: Bool,
        importedFromLibrary: Bool = false,
        isSeed: Bool = false,
        needsSync: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.note = note
        self.colorScore = colorScore
        self.dramaScore = dramaScore
        self.overallScore = overallScore
        self.photoBundleName = photoBundleName
        self.photoFileName = photoFileName
        self.photoURL = photoURL
        self.photoAssetId = photoAssetId
        self.authorHandle = authorHandle
        self.authorName = authorName
        self.isMine = isMine
        self.importedFromLibrary = importedFromLibrary
        self.isSeed = isSeed
        self.needsSync = needsSync
        self.createdAt = createdAt
        self.collections = []
    }

    var resolvedBundleName: String? { photoBundleName }

    var dayKey: Date {
        Calendar.current.startOfDay(for: capturedAt)
    }
}

@Model
final class SkyCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var detail: String
    var symbol: String
    var accentToken: String
    var createdAt: Date
    var isSeed: Bool
    var entries: [SunsetEntry]

    init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        symbol: String,
        accentToken: String,
        createdAt: Date = .now,
        isSeed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.accentToken = accentToken
        self.createdAt = createdAt
        self.isSeed = isSeed
        self.entries = []
    }

    var accent: Color {
        switch accentToken {
        case "rose": return Palette.rose
        case "storm": return Palette.storm
        case "gold": return Palette.gold
        default: return Palette.ember
        }
    }
}

@Model
final class Person: Identifiable {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var handle: String
    var city: String
    var bio: String
    var isFollowing: Bool
    var isMe: Bool
    var avatarHue: Double
    var isSeed: Bool

    init(
        id: UUID = UUID(),
        displayName: String,
        handle: String,
        city: String,
        bio: String,
        isFollowing: Bool = false,
        isMe: Bool = false,
        avatarHue: Double,
        isSeed: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.city = city
        self.bio = bio
        self.handle = handle
        self.isFollowing = isFollowing
        self.isMe = isMe
        self.avatarHue = avatarHue
        self.isSeed = isSeed
    }
}

@Model
final class SharedSpotNote {
    @Attribute(.unique) var id: UUID
    var spotID: UUID
    var fromHandle: String
    var toHandle: String
    var message: String
    var sentAt: Date

    init(
        id: UUID = UUID(),
        spotID: UUID,
        fromHandle: String,
        toHandle: String,
        message: String,
        sentAt: Date = .now
    ) {
        self.id = id
        self.spotID = spotID
        self.fromHandle = fromHandle
        self.toHandle = toHandle
        self.message = message
        self.sentAt = sentAt
    }
}

@Model
final class UserPrefs {
    var remindersEnabled: Bool
    var reminderLeadMinutes: Int
    var hasCompletedWelcome: Bool

    init(remindersEnabled: Bool = false, reminderLeadMinutes: Int = 30, hasCompletedWelcome: Bool = false) {
        self.remindersEnabled = remindersEnabled
        self.reminderLeadMinutes = reminderLeadMinutes
        self.hasCompletedWelcome = hasCompletedWelcome
    }
}

enum ScoreFormat {
    static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
