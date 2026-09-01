import Foundation
import UserNotifications
import Observation
import CoreLocation

@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var authorization: UNAuthorizationStatus = .notDetermined
    var lastScheduledSunset: Date?

    private let center = UNUserNotificationCenter.current()
    static let requestID = "sunset-tonight"

    override init() {
        super.init()
        center.delegate = self
    }

    func refresh() async {
        let settings = await center.notificationSettings()
        authorization = settings.authorizationStatus
    }

    @discardableResult
    func request() async -> Bool {
        do {
            let ok = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refresh()
            return ok
        } catch {
            await refresh()
            return false
        }
    }

    func syncReminder(enabled: Bool, leadMinutes: Int, sunset: Date?) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
        lastScheduledSunset = nil
        guard enabled, let sunset else { return }
        if authorization == .notDetermined {
            _ = await request()
        }
        guard authorization == .authorized || authorization == .provisional else { return }

        let fire = sunset.addingTimeInterval(TimeInterval(-leadMinutes * 60))
        guard fire > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "The light is leaving"
        content.body = "Sunset in \(leadMinutes) minutes. Step outside if you can."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: Self.requestID, content: content, trigger: trigger)
        do {
            try await center.add(request)
            lastScheduledSunset = sunset
        } catch {
            lastScheduledSunset = nil
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
