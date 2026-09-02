import Foundation

/// Reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from Info.plist (xcconfig substitutions).
enum SupabaseConfig {
    static var urlString: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var anonKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var url: URL? { URL(string: urlString) }

    static var isConfigured: Bool {
        isConfigured(url: urlString, anonKey: anonKey)
    }

    static func isConfigured(url: String, anonKey: String) -> Bool {
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: url), parsed.scheme == "https", parsed.host != nil else {
            return false
        }
        let host = parsed.host ?? ""
        if host.contains("YOUR_PROJECT") || host.contains("example.supabase") {
            return false
        }
        if key.isEmpty || key == "your-anon-key" || key.lowercased().contains("replace") {
            return false
        }
        return key.count >= 20
    }
}
