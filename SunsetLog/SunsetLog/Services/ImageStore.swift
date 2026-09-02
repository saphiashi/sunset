import Foundation
import UIKit

enum ImageStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("SunsetPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func save(_ image: UIImage, quality: CGFloat = 0.86) -> String? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        let name = UUID().uuidString + ".jpg"
        let url = directory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func data(named fileName: String) -> Data? {
        let url = directory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    static func load(_ fileName: String) -> UIImage? {
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func bundleImage(named name: String) -> UIImage? {
        if let img = UIImage(named: name) { return img }
        let urls = [
            Bundle.main.url(forResource: name, withExtension: "jpg"),
            Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "SeedPhotos"),
            Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Resources/SeedPhotos")
        ]
        for url in urls.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }
}
