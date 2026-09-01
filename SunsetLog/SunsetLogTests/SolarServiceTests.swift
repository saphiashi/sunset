import XCTest
@testable import SunsetLog

final class SolarServiceTests: XCTestCase {
    func testJuneSolsticeSanFranciscoIsEvening() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        var parts = DateComponents()
        parts.year = 2024
        parts.month = 6
        parts.day = 21
        parts.hour = 12
        let day = try XCTUnwrap(calendar.date(from: parts))
        let event = try XCTUnwrap(
            SolarService.event(on: day, latitude: 37.7749, longitude: -122.4194, calendar: calendar)
        )
        let hour = calendar.component(.hour, from: event.sunset)
        let minute = calendar.component(.minute, from: event.sunset)
        XCTAssertEqual(hour, 20, "June solstice sunset in San Francisco should be around 8:30pm")
        XCTAssertGreaterThan(minute, 20)
        XCTAssertLessThan(minute, 50)
    }

    func testDecemberSolsticeSanFranciscoIsLateAfternoon() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        var parts = DateComponents()
        parts.year = 2024
        parts.month = 12
        parts.day = 21
        parts.hour = 12
        let day = try XCTUnwrap(calendar.date(from: parts))
        let event = try XCTUnwrap(
            SolarService.event(on: day, latitude: 37.7749, longitude: -122.4194, calendar: calendar)
        )
        let hour = calendar.component(.hour, from: event.sunset)
        XCTAssertEqual(hour, 16)
    }

    func testNextSunsetSkipsAPassedSun() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")
        let now = Date()
        let next = SolarService.nextSunset(
            after: now,
            latitude: 37.7749,
            longitude: -122.4194,
            calendar: calendar
        )
        XCTAssertNotNil(next)
        XCTAssertGreaterThan(next ?? .distantPast, now)
    }

    func testStreakCountsConsecutiveMineDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func entry(daysAgo: Int, mine: Bool) -> SunsetEntry {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            return SunsetEntry(
                capturedAt: day.addingTimeInterval(19 * 3600),
                note: "",
                colorScore: 8,
                dramaScore: 8,
                overallScore: 8,
                authorHandle: mine ? "you" : "maya",
                authorName: mine ? "You" : "Maya",
                isMine: mine
            )
        }
        let entries = [entry(daysAgo: 0, mine: true), entry(daysAgo: 1, mine: true), entry(daysAgo: 2, mine: true), entry(daysAgo: 4, mine: true)]
        XCTAssertEqual(AppSession.streak(from: entries, now: today, calendar: calendar), 3)
    }
}
