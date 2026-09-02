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
    var auth: AuthController
    var cloud: CloudSync
    var now: Date = .now
    var pendingLink: DeepLink?
    var logPresented = false
    var scanPresented = false
    var signInPresented = false

    private var clockTask: Task<Void, Never>?

    /// Default arguments are evaluated in a nonisolated context, so MainActor
    /// services are created here in the isolated body instead of as defaults.
    convenience init() {
        let auth = AuthController()
        let cloud = CloudSync(auth: auth)
        self.init(
            location: LocationService(),
            notifications: NotificationService(),
            scanner: PhotoLibraryScanner(),
            social: SupabaseSocialClient(cloud: cloud, auth: auth),
            auth: auth,
            cloud: cloud
        )
    }

    init(
        location: LocationService,
        notifications: NotificationService,
        scanner: PhotoLibraryScanner,
        social: SocialClient,
        auth: AuthController,
        cloud: CloudSync
    ) {
        self.location = location
        self.notifications = notifications
        self.scanner = scanner
        self.social = social
        self.auth = auth
        self.cloud = cloud
        auth.onSessionChange = { [weak cloud] in
            cloud?.schedule()
        }
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

    func start(context: ModelContext) {
        cloud.attach(context)
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
        Task {
            await auth.restoreSession()
            await cloud.syncNow()
        }
    }

    func stop() {
        clockTask?.cancel()
    }

    func handleOpenURL(_ url: URL) {
        if url.host == "auth-callback"
            || url.path.contains("auth-callback")
            || url.absoluteString.contains("access_token")
            || url.absoluteString.contains("type=magiclink") {
            Task { await auth.handleOpenURL(url) }
            return
        }
        pendingLink = DeepLink.parse(url)
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
