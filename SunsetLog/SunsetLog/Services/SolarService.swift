import Foundation
import CoreLocation

/// Civil sunset using the SunCalc / NOAA geometry (Meeus-style).
/// Sunrise is computed internally so the hour-angle math stays correct; it is not a product feature.
enum SolarService {
    private static let rad = Double.pi / 180
    private static let j1970 = 2_440_588.0
    private static let j2000 = 2_451_545.0
    private static let obliquity = (Double.pi / 180) * 23.4397

    struct Event: Hashable, Sendable {
        var sunset: Date
        var solarNoon: Date
        var goldenHourStart: Date
    }

    static func event(
        on day: Date,
        latitude: Double,
        longitude: Double,
        calendar: Calendar = .current
    ) -> Event? {
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = 12
        parts.minute = 0
        parts.second = 0
        let localNoon = calendar.date(from: parts) ?? day
        guard let times = solarTimes(reference: localNoon, latitude: latitude, longitude: longitude) else {
            return nil
        }
        return Event(
            sunset: times.set,
            solarNoon: times.noon,
            goldenHourStart: times.set.addingTimeInterval(-60 * 60)
        )
    }

    static func nextSunset(
        after now: Date = .now,
        latitude: Double,
        longitude: Double,
        calendar: Calendar = .current
    ) -> Date? {
        if let today = event(on: now, latitude: latitude, longitude: longitude, calendar: calendar),
           today.sunset > now {
            return today.sunset
        }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        return event(on: tomorrow, latitude: latitude, longitude: longitude, calendar: calendar)?.sunset
    }

    static func isNearSunset(
        _ date: Date,
        latitude: Double,
        longitude: Double,
        before: TimeInterval = 50 * 60,
        after: TimeInterval = 25 * 60
    ) -> Bool {
        guard let sunset = event(on: date, latitude: latitude, longitude: longitude)?.sunset else {
            return fallbackNearDusk(date)
        }
        let delta = date.timeIntervalSince(sunset)
        return delta >= -before && delta <= after
    }

    static func fallbackNearDusk(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let stamp = hour * 60 + minute
        return stamp >= (17 * 60) && stamp <= (20 * 60 + 15)
    }

    // MARK: - Geometry (SunCalc)

    private struct RawTimes {
        var rise: Date
        var noon: Date
        var set: Date
    }

    private static func solarTimes(reference: Date, latitude: Double, longitude: Double) -> RawTimes? {
        let lw = rad * -longitude
        let phi = rad * latitude
        let d = toDays(reference)
        let n = julianCycle(d, lw: lw)
        let ds = approxTransit(0, lw: lw, n: n)
        let m = solarMeanAnomaly(ds)
        let l = eclipticLongitude(m)
        let dec = declination(l)
        guard let jset = setJulian(angle: -0.833 * rad, lw: lw, phi: phi, dec: dec, n: n, m: m, l: l) else {
            return nil
        }
        let jnoon = solarTransitJ(ds, m: m, l: l)
        let jrise = jnoon - (jset - jnoon)
        return RawTimes(rise: fromJulian(jrise), noon: fromJulian(jnoon), set: fromJulian(jset))
    }

    private static func toJulian(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 - 0.5 + j1970
    }

    private static func fromJulian(_ j: Double) -> Date {
        Date(timeIntervalSince1970: (j + 0.5 - j1970) * 86_400)
    }

    private static func toDays(_ date: Date) -> Double {
        toJulian(date) - j2000
    }

    private static func solarMeanAnomaly(_ d: Double) -> Double {
        rad * (357.5291 + 0.98560028 * d)
    }

    private static func eclipticLongitude(_ m: Double) -> Double {
        let c = rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m))
        let p = rad * 102.9372
        return m + c + p + Double.pi
    }

    private static func declination(_ l: Double) -> Double {
        asin(sin(obliquity) * sin(l))
    }

    private static func julianCycle(_ d: Double, lw: Double) -> Double {
        (d - 0.0009 - lw / (2 * Double.pi)).rounded()
    }

    private static func approxTransit(_ ht: Double, lw: Double, n: Double) -> Double {
        0.0009 + (ht + lw) / (2 * Double.pi) + n
    }

    private static func solarTransitJ(_ ds: Double, m: Double, l: Double) -> Double {
        j2000 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l)
    }

    private static func hourAngle(_ h: Double, phi: Double, dec: Double) -> Double? {
        let cosH = (sin(h) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec))
        guard cosH >= -1, cosH <= 1 else { return nil }
        return acos(cosH)
    }

    private static func setJulian(
        angle: Double,
        lw: Double,
        phi: Double,
        dec: Double,
        n: Double,
        m: Double,
        l: Double
    ) -> Double? {
        guard let w = hourAngle(angle, phi: phi, dec: dec) else { return nil }
        let a = approxTransit(w, lw: lw, n: n)
        return solarTransitJ(a, m: m, l: l)
    }
}

enum SolarPhase: Equatable {
    case waiting(Date)
    case goldenHour(Date)
    case afterglow
    case polarNight
}
