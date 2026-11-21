import Foundation
import Supabase

/// `sunset-photos` is private, so remote photos load through short-lived signed URLs.
/// Cached per path so AsyncImage sees a stable URL until it nears expiry.
@MainActor
final class PhotoLinks {
    static let shared = PhotoLinks()

    var client: SupabaseClient?

    private var cache: [String: (url: URL, expires: Date)] = [:]
    private let lifetime = 3600

    func url(for path: String) async -> URL? {
        if let hit = cache[path], hit.expires > Date().addingTimeInterval(300) {
            return hit.url
        }
        guard let client else { return nil }
        do {
            let url = try await client.storage
                .from(PhotoUploader.bucket)
                .createSignedURL(path: path, expiresIn: lifetime)
            cache[path] = (url, Date().addingTimeInterval(TimeInterval(lifetime)))
            return url
        } catch {
            return nil
        }
    }

    func clear() {
        cache = [:]
    }
}
