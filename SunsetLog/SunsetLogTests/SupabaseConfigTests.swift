import XCTest
@testable import SunsetLog

final class SupabaseConfigTests: XCTestCase {
    func testPlaceholdersAreNotConfigured() {
        XCTAssertFalse(
            SupabaseConfig.isConfigured(
                url: "https://YOUR_PROJECT.supabase.co",
                anonKey: "your-anon-key"
            )
        )
    }

    func testEmptyIsNotConfigured() {
        XCTAssertFalse(SupabaseConfig.isConfigured(url: "", anonKey: ""))
        XCTAssertFalse(SupabaseConfig.isConfigured(url: "not-a-url", anonKey: "aaaaaaaaaaaaaaaaaaaa"))
    }

    func testLiveLookingKeysAreConfigured() {
        XCTAssertTrue(
            SupabaseConfig.isConfigured(
                url: "https://abcdefghijk.supabase.co",
                anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.placeholder"
            )
        )
    }

    func testProfileRowUsesSnakeCaseKeys() throws {
        let json = """
        {"id":"A1B2C3D4-0002-4000-8000-000000000001","handle":"maya","display_name":"Maya Chen","city":"San Francisco","bio":"Chases pink.","avatar_hue":0.92}
        """.data(using: .utf8)!
        let row = try JSONDecoder().decode(ProfileRow.self, from: json)
        XCTAssertEqual(row.handle, "maya")
        XCTAssertEqual(row.displayName, "Maya Chen")
        XCTAssertEqual(row.avatarHue, 0.92, accuracy: 0.001)
    }
}
