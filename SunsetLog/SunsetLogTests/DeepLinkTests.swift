import XCTest
@testable import SunsetLog

final class DeepLinkTests: XCTestCase {
    func testParsesSpotHost() {
        let id = SeedID.baker
        let url = URL(string: "sunsetlog://spot/\(id.uuidString)")!
        XCTAssertEqual(DeepLink.parse(url), .spot(id))
    }

    func testRoundTripSpotURL() {
        let id = SeedID.elMatador
        XCTAssertEqual(DeepLink.parse(DeepLink.spotURL(id)), .spot(id))
    }

    func testRejectsForeignScheme() {
        XCTAssertNil(DeepLink.parse(URL(string: "https://example.com/spot/1")!))
    }

    func testIgnoresAuthCallback() {
        XCTAssertNil(DeepLink.parse(URL(string: "sunsetlog://auth-callback")!))
    }
}
