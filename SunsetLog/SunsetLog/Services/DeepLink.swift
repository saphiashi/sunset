import Foundation

enum DeepLink: Equatable {
    case spot(UUID)
    case entry(UUID)

    static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == "sunsetlog" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        let host = url.host
        if host == "spot", let raw = parts.first, let id = UUID(uuidString: raw) {
            return .spot(id)
        }
        if host == "entry", let raw = parts.first, let id = UUID(uuidString: raw) {
            return .entry(id)
        }
        // sunsetlog://spot/<uuid> and sunsetlog:/spot/<uuid>
        if parts.count >= 2, parts[0] == "spot", let id = UUID(uuidString: parts[1]) {
            return .spot(id)
        }
        if parts.count >= 2, parts[0] == "entry", let id = UUID(uuidString: parts[1]) {
            return .entry(id)
        }
        return nil
    }

    static func spotURL(_ id: UUID) -> URL {
        URL(string: "sunsetlog://spot/\(id.uuidString)")!
    }
}
