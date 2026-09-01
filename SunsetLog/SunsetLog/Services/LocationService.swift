import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var authorization: CLAuthorizationStatus
    var coordinate: CLLocationCoordinate2D?
    var locality: String?
    var lastError: String?

    /// Bay Area fallback so the map and clock still feel placed when permission is denied.
    static let fallback = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    static let fallbackLocality = "San Francisco"

    var effectiveCoordinate: CLLocationCoordinate2D {
        coordinate ?? Self.fallback
    }

    var usesFallback: Bool {
        coordinate == nil
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        coordinate = location.coordinate
        lastError = nil
        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] marks, _ in
            let name = marks?.first?.locality ?? marks?.first?.name
            Task { @MainActor in
                self?.locality = name
            }
        }
    }
}
