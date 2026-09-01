import Foundation
import Observation
import SwiftData
import CoreLocation

@MainActor
@Observable
final class AppSession {
    var location: LocationService
    var notifications: NotificationService
    var scanner: PhotoLibraryScanner
    var social: SocialClient
    var now: Date = .now
    var pendingLink: DeepLink?
    var logPresented = false
    var scanPresented = false

    private var clockTask: Task<Void, Never>?

    init(
        location: LocationService = LocationService(),
        notifications: NotificationService = NotificationService(),
        scanner: PhotoLibraryScanner = PhotoLibraryScanner(),
        social: SocialClient = MockSocialClient()
    ) {
        self.location = location
        self.notifications = notifications
        self.scanner = scanner
        self.social = social
    }

    var solar: SolarService.Event? {
        SolarService.event(
            on: now,
            latitude: location.effectiveCoordinate.latitude,
            longitude: location.effectiveCoordinate.longitude
        )
    }

    var nextSunset: Date? {
        SolarService.nextSunset(
            after: now,
            latitude: location.effectiveCoordinate.latitude,
            longitude: location.effectiveCoordinate.longitude
        )
    }

    var phase: SolarPhase {
        guard let sunset = nextSunset, let event = solar else { return .polarNight }
        if now >= event.sunset {
            return .afterglow
        }
        if now >= event.goldenHourStart {
            return .goldenHour(sunset)
        }
        return .waiting(sunset)
    }

    func start() {
        location.request()
        scanner.refreshAccess()
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.now = Date()
            }
        }
        Task { await notifications.refresh() }
    }

    func stop() {
        clockTask?.cancel()
    }

    nonisolated static func streak(from entries: [SunsetEntry], now: Date = .now, calendar: Calendar = .current) -> Int {
        let mine = entries.filter(\.isMine)
        let days = Set(mine.map { calendar.startOfDay(for: $0.capturedAt) })
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
