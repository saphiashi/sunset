"""NOAA-style sunset calculator used as a reference for the Swift port."""

from __future__ import annotations

import math
from datetime import date, datetime, timedelta, timezone


def _rad(d: float) -> float:
    return math.radians(d)


def _deg(r: float) -> float:
    return math.degrees(r)


def julian_day(d: date) -> float:
    y, m, day = d.year, d.month, d.day
    if m <= 2:
        y -= 1
        m += 12
    a = y // 100
    b = 2 - a + a // 4
    return int(365.25 * (y + 4716)) + int(30.6001 * (m + 1)) + day + b - 1524.5


def sunset_utc(d: date, lat: float, lon: float) -> datetime | None:
    """Return sunset in UTC for a civil zenith of 90.833°."""
    jd = julian_day(d)
    n = jd - 2451545.0 + 0.0008
    jstar = n - lon / 360.0
    m = (357.5291 + 0.98560028 * jstar) % 360
    c = 1.9148 * math.sin(_rad(m)) + 0.0200 * math.sin(_rad(2 * m)) + 0.0003 * math.sin(_rad(3 * m))
    lam = (m + c + 180 + 102.9372) % 360
    jtransit = 2451545.0 + jstar + 0.0053 * math.sin(_rad(m)) - 0.0069 * math.sin(_rad(2 * lam))
    sin_dec = math.sin(_rad(lam)) * math.sin(_rad(23.4397))
    dec = math.asin(sin_dec)
    cos_h = (math.sin(_rad(-0.833)) - math.sin(_rad(lat)) * math.sin(dec)) / (
        math.cos(_rad(lat)) * math.cos(dec)
    )
    if cos_h < -1 or cos_h > 1:
        return None
    h = _deg(math.acos(cos_h))
    jset = jtransit + h / 360.0
    # julian to datetime
    unix = (jset - 2440587.5) * 86400.0
    return datetime.fromtimestamp(unix, tz=timezone.utc)


if __name__ == "__main__":
    # San Francisco
    lat, lon = 37.7749, -122.4194
    for iso in ("2024-06-21", "2024-12-21", "2024-09-22", "2026-09-01"):
        d = date.fromisoformat(iso)
        s = sunset_utc(d, lat, lon)
        print(iso, s, "PDT/PST local", s.astimezone() if s else None)
