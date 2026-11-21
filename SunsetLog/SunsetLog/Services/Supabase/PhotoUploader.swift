import Foundation
import UIKit
import Supabase

enum PhotoUploader {
    static let bucket = "sunset-photos"

    static func jpegData(for entry: SunsetEntry) -> Data? {
        if let file = entry.photoFileName, let data = ImageStore.data(named: file) {
            return data
        }
        if let file = entry.photoFileName, let image = ImageStore.load(file) {
            return image.jpegData(compressionQuality: 0.86)
        }
        return nil
    }

    static func upload(
        data: Data,
        userID: UUID,
        entryID: UUID,
        client: SupabaseClient
    ) async throws -> String {
        let path = "\(userID.uuidString.lowercased())/\(entryID.uuidString.lowercased()).jpg"
        try await client.storage
            .from(bucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        return path
    }

    /// Entries uploaded while the bucket was public stored a public URL instead of a path.
    static func path(fromPublicURL url: String) -> String? {
        let marker = "/object/public/\(bucket)/"
        guard let range = url.range(of: marker) else { return nil }
        let path = String(url[range.upperBound...])
        return path.isEmpty ? nil : path
    }
}
