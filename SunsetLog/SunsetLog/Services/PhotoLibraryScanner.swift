import Foundation
import Photos
import UIKit
import Observation

struct ScanCandidate: Identifiable {
    var id: String
    var assetID: String
    var createdAt: Date
    var warmth: Double
    var nearSunset: Bool
    var preview: UIImage?
    var reason: String
    var isSimulatorDemo: Bool
}

enum LibraryAccess: Equatable {
    case unknown
    case notDetermined
    case denied
    case limited
    case authorized
    case unavailable
}

@MainActor
@Observable
final class PhotoLibraryScanner {
    var access: LibraryAccess = .unknown
    var isScanning = false
    var candidates: [ScanCandidate] = []
    var lastError: String?

    func refreshAccess() {
        access = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        access = Self.map(status)
    }

    func scan(near latitude: Double, longitude: Double) async {
        isScanning = true
        lastError = nil
        defer { isScanning = false }

        refreshAccess()
        guard access == .authorized || access == .limited else {
            candidates = []
            return
        }

        let found = await Task.detached(priority: .userInitiated) {
            Self.fetchCandidates(latitude: latitude, longitude: longitude)
        }.value

        if found.isEmpty {
            candidates = Self.demoCandidatesIfSimulator()
        } else {
            candidates = found
        }
    }

    nonisolated private static func fetchCandidates(latitude: Double, longitude: Double) -> [ScanCandidate] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 400
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var results: [ScanCandidate] = []
        let manager = PHImageManager.default()
        let request = PHImageRequestOptions()
        request.isSynchronous = true
        request.deliveryMode = .fastFormat
        request.resizeMode = .fast

        assets.enumerateObjects { asset, _, stop in
            guard results.count < 24 else {
                stop.pointee = true
                return
            }
            guard let created = asset.creationDate else { return }

            var lat = latitude
            var lon = longitude
            if let loc = asset.location {
                lat = loc.coordinate.latitude
                lon = loc.coordinate.longitude
            }
            let near = SolarService.isNearSunset(created, latitude: lat, longitude: lon)

            var image: UIImage?
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 240, height: 300),
                contentMode: .aspectFill,
                options: request
            ) { result, _ in
                image = result
            }

            let warmth = warmthScore(image)
            let warmEnough = warmth >= 0.42
            guard near || warmEnough else { return }
            guard near && warmEnough || (near && warmth >= 0.28) || (warmEnough && SolarService.fallbackNearDusk(created)) else {
                return
            }

            var bits: [String] = []
            if near { bits.append("timed to last light") }
            if warmEnough { bits.append("warm sky") }
            results.append(
                ScanCandidate(
                    id: asset.localIdentifier,
                    assetID: asset.localIdentifier,
                    createdAt: created,
                    warmth: warmth,
                    nearSunset: near,
                    preview: image,
                    reason: bits.joined(separator: " · "),
                    isSimulatorDemo: false
                )
            )
        }
        return results
    }

    nonisolated private static func warmthScore(_ image: UIImage?) -> Double {
        guard let image, let cg = image.cgImage else { return 0 }
        let width = 24
        let height = 24
        let bytesPerPixel = 4
        var data = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let ctx = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var warm = 0
        var total = 0
        // Bias toward the upper two-thirds — sky, not pavement.
        for y in 0..<(height * 2 / 3) {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let r = Double(data[i])
                let g = Double(data[i + 1])
                let b = Double(data[i + 2])
                let maxc = max(r, g, b)
                let minc = min(r, g, b)
                guard maxc > 40 else { continue }
                total += 1
                let sat = maxc == 0 ? 0 : (maxc - minc) / maxc
                let warmBias = r - b
                if warmBias > 18 && sat > 0.18 && r >= g {
                    warm += 1
                }
            }
        }
        guard total > 0 else { return 0 }
        return Double(warm) / Double(total)
    }

    private static func demoCandidatesIfSimulator() -> [ScanCandidate] {
        #if targetEnvironment(simulator)
        let names = ["pink_wash", "storm_light", "gold_hour", "lavender_dusk"]
        let cal = Calendar.current
        return names.enumerated().compactMap { index, name in
            guard let image = ImageStore.bundleImage(named: name) else { return nil }
            let day = cal.date(byAdding: .day, value: -(index + 2), to: Date()) ?? Date()
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = 19
            comps.minute = 12
            let when = cal.date(from: comps) ?? day
            return ScanCandidate(
                id: "demo-\(name)",
                assetID: "demo-\(name)",
                createdAt: when,
                warmth: 0.7,
                nearSunset: true,
                preview: image,
                reason: "timed to last light · warm sky",
                isSimulatorDemo: true
            )
        }
        #else
        return []
        #endif
    }

    private static func map(_ status: PHAuthorizationStatus) -> LibraryAccess {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted, .denied: return .denied
        case .limited: return .limited
        case .authorized: return .authorized
        @unknown default: return .unavailable
        }
    }
}
