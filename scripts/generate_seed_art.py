#!/usr/bin/env python3
"""Cinematic seed sunsets and app icon for Sunset Log."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = Path("/workspace/SunsetLog/SunsetLog")
PHOTOS = ROOT / "Resources" / "SeedPhotos"
ICON_DIR = ROOT / "Assets.xcassets" / "AppIcon.appiconset"
PHOTOS.mkdir(parents=True, exist_ok=True)
ICON_DIR.mkdir(parents=True, exist_ok=True)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def lerp_color(c1, c2, t):
    return tuple(int(lerp(a, b, t)) for a, b in zip(c1, c2))


def vertical_sky(w, h, stops):
    """stops: list of (t, rgb) from 0 at top to 1 at bottom."""
    img = Image.new("RGB", (w, h))
    px = img.load()
    stops = sorted(stops)
    for y in range(h):
        t = y / (h - 1)
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1 or i == len(stops) - 2:
                local = 0 if t1 == t0 else (t - t0) / (t1 - t0)
                local = max(0.0, min(1.0, local))
                # ease
                local = local * local * (3 - 2 * local)
                color = lerp_color(c0, c1, local)
                for x in range(w):
                    px[x, y] = color
                break
    return img


def add_sun(img, cx, cy, radius, color, glow=1.8):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    w, h = img.size
    for i in range(8, 0, -1):
        r = int(radius * (1 + glow * i / 4))
        alpha = int(18 / i)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*color, alpha))
    d.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(*color, 230))
    # hot core
    cr = int(radius * 0.45)
    d.ellipse((cx - cr, cy - cr, cx + cr, cy + cr), fill=(255, 250, 230, 255))
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def add_clouds(img, rng, tint, count=7, y_range=(0.12, 0.55)):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    w, h = img.size
    d = ImageDraw.Draw(overlay)
    for _ in range(count):
        cx = rng.randint(int(-0.1 * w), int(1.1 * w))
        cy = rng.randint(int(y_range[0] * h), int(y_range[1] * h))
        rw = rng.randint(int(0.18 * w), int(0.42 * w))
        rh = rng.randint(int(0.03 * h), int(0.08 * h))
        alpha = rng.randint(40, 110)
        color = (*tint, alpha)
        for k in range(4):
            ox = rng.randint(-rw // 3, rw // 3)
            oy = rng.randint(-rh // 2, rh // 2)
            d.ellipse((cx + ox - rw, cy + oy - rh, cx + ox + rw, cy + oy + rh), fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=18))
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def add_water(img, horizon, shimmer):
    w, h = img.size
    water = img.crop((0, 0, w, horizon)).transpose(Image.FLIP_TOP_BOTTOM)
    water = water.resize((w, h - horizon))
    water = ImageEnhance.Brightness(water).enhance(0.55)
    water = ImageEnhance.Color(water).enhance(0.85)
    # ripples
    px = water.load()
    rng = random.Random(horizon)
    for y in range(water.size[1]):
        wave = int(math.sin(y / 7.0) * 4)
        if wave:
            row = [px[min(max(x + wave, 0), w - 1), y] for x in range(w)]
            for x in range(w):
                px[x, y] = row[x]
        if shimmer and y % 5 == 0:
            for x in range(0, w, rng.randint(8, 22)):
                if rng.random() < 0.25:
                    c = px[x, y]
                    px[x, y] = tuple(min(255, int(c[i] + 40)) for i in range(3))
    img.paste(water, (0, horizon))
    return img


def add_silhouette_hills(img, horizon, peaks, color):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    w, h = img.size
    pts = [(0, h), (0, horizon)]
    for x_t, lift in peaks:
        pts.append((int(x_t * w), int(horizon - lift * h)))
    pts.append((w, horizon))
    pts.append((w, h))
    d.polygon(pts, fill=(*color, 255))
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def add_city(img, horizon, rng, color):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    w, h = img.size
    x = 0
    while x < w:
        bw = rng.randint(10, 28)
        bh = rng.randint(18, 90)
        d.rectangle((x, horizon - bh, x + bw - 2, h), fill=(*color, 255))
        # windows
        if bh > 40 and rng.random() < 0.6:
            for wy in range(horizon - bh + 6, horizon - 8, 10):
                for wx in range(x + 3, x + bw - 5, 7):
                    if rng.random() < 0.35:
                        d.rectangle((wx, wy, wx + 2, wy + 3), fill=(255, 200, 120, 180))
        x += bw
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def add_grain(img, amount=12):
    rng = random.Random(3)
    grain = Image.new("RGB", img.size)
    gp = grain.load()
    w, h = img.size
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            v = rng.randint(-amount, amount)
            gp[x, y] = (v + 128, v + 128, v + 128)
    grain = grain.resize(img.size, Image.BILINEAR).filter(ImageFilter.GaussianBlur(0.6))
    return Image.blend(img.convert("RGB"), grain, 0.07)


def finish(img):
    img = img.convert("RGB")
    img = ImageEnhance.Contrast(img).enhance(1.08)
    img = ImageEnhance.Color(img).enhance(1.12)
    img = add_grain(img)
    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    return img


RECIPES = [
    # name, sky stops, sun, hills, water, city, clouds
    dict(
        name="baker_beach",
        stops=[(0, (28, 36, 78)), (0.35, (232, 98, 78)), (0.55, (255, 176, 92)), (0.72, (255, 214, 150)), (1, (90, 60, 70))],
        sun=(0.72, 0.48, 54, (255, 196, 110)),
        hills=[(0.0, 0.02), (0.15, 0.06), (0.4, 0.03), (0.7, 0.08), (1.0, 0.04)],
        hill_color=(28, 22, 32),
        water=True,
        city=False,
        cloud_tint=(255, 170, 140),
    ),
    dict(
        name="twin_peaks",
        stops=[(0, (42, 24, 72)), (0.4, (196, 72, 110)), (0.62, (255, 140, 96)), (1, (40, 28, 38))],
        sun=(0.55, 0.52, 40, (255, 180, 130)),
        hills=[(0.0, 0.1), (0.25, 0.18), (0.5, 0.08), (0.78, 0.2), (1.0, 0.12)],
        hill_color=(22, 16, 28),
        water=False,
        city=False,
        cloud_tint=(255, 140, 160),
    ),
    dict(
        name="griffith",
        stops=[(0, (18, 22, 48)), (0.38, (255, 92, 64)), (0.58, (255, 168, 72)), (1, (48, 30, 36))],
        sun=(0.78, 0.5, 48, (255, 210, 120)),
        hills=[(0.0, 0.04), (0.3, 0.07), (0.6, 0.05), (1.0, 0.09)],
        hill_color=(30, 20, 28),
        water=False,
        city=True,
        cloud_tint=(255, 150, 110),
    ),
    dict(
        name="el_matador",
        stops=[(0, (64, 40, 88)), (0.3, (240, 86, 120)), (0.55, (255, 168, 108)), (0.7, (255, 214, 168)), (1, (70, 48, 58))],
        sun=(0.62, 0.5, 46, (255, 200, 140)),
        hills=[(0.0, 0.0), (0.2, 0.12), (0.35, 0.02), (0.55, 0.16), (0.8, 0.03), (1.0, 0.1)],
        hill_color=(36, 24, 30),
        water=True,
        city=False,
        cloud_tint=(255, 160, 170),
    ),
    dict(
        name="ocean_beach",
        stops=[(0, (20, 28, 60)), (0.42, (255, 120, 70)), (0.6, (255, 190, 100)), (1, (80, 56, 52))],
        sun=(0.5, 0.52, 58, (255, 220, 140)),
        hills=[(0.0, 0.01), (0.5, 0.02), (1.0, 0.015)],
        hill_color=(32, 26, 30),
        water=True,
        city=False,
        cloud_tint=(255, 186, 140),
    ),
    dict(
        name="lands_end",
        stops=[(0, (36, 28, 70)), (0.36, (120, 70, 140)), (0.58, (255, 130, 90)), (1, (44, 30, 40))],
        sun=(0.8, 0.54, 36, (255, 170, 110)),
        hills=[(0.0, 0.06), (0.22, 0.14), (0.48, 0.05), (0.7, 0.11), (1.0, 0.07)],
        hill_color=(20, 16, 26),
        water=True,
        city=False,
        cloud_tint=(210, 140, 180),
    ),
    dict(
        name="santa_monica",
        stops=[(0, (24, 32, 70)), (0.4, (255, 110, 88)), (0.62, (255, 186, 110)), (1, (56, 40, 48))],
        sun=(0.68, 0.5, 50, (255, 210, 130)),
        hills=[(0.0, 0.02), (1.0, 0.02)],
        hill_color=(28, 22, 30),
        water=True,
        city=True,
        cloud_tint=(255, 160, 130),
    ),
    dict(
        name="bixby",
        stops=[(0, (48, 32, 64)), (0.34, (88, 56, 110)), (0.55, (255, 148, 96)), (1, (38, 28, 34))],
        sun=(0.42, 0.5, 34, (255, 190, 130)),
        hills=[(0.0, 0.16), (0.18, 0.22), (0.4, 0.08), (0.65, 0.2), (1.0, 0.14)],
        hill_color=(18, 16, 22),
        water=True,
        city=False,
        cloud_tint=(180, 130, 160),
    ),
    dict(
        name="alamo",
        stops=[(0, (30, 24, 58)), (0.4, (255, 96, 78)), (0.6, (255, 168, 96)), (1, (50, 32, 40))],
        sun=(0.74, 0.48, 42, (255, 200, 120)),
        hills=[(0.0, 0.03), (0.5, 0.04), (1.0, 0.03)],
        hill_color=(26, 18, 24),
        water=False,
        city=True,
        cloud_tint=(255, 140, 120),
    ),
    dict(
        name="tamalpais",
        stops=[(0, (22, 26, 52)), (0.32, (70, 50, 110)), (0.52, (255, 124, 82)), (0.7, (255, 200, 130)), (1, (40, 30, 36))],
        sun=(0.6, 0.46, 44, (255, 214, 140)),
        hills=[(0.0, 0.08), (0.3, 0.2), (0.55, 0.1), (0.85, 0.18), (1.0, 0.09)],
        hill_color=(16, 14, 22),
        water=False,
        city=False,
        cloud_tint=(200, 140, 170),
    ),
    dict(
        name="storm_light",
        stops=[(0, (16, 18, 28)), (0.3, (48, 36, 58)), (0.5, (180, 70, 54)), (0.7, (255, 140, 70)), (1, (30, 22, 26))],
        sun=(0.3, 0.58, 28, (255, 160, 80)),
        hills=[(0.0, 0.05), (0.4, 0.09), (1.0, 0.06)],
        hill_color=(12, 12, 16),
        water=False,
        city=False,
        cloud_tint=(80, 70, 90),
        extra_clouds=12,
    ),
    dict(
        name="pink_wash",
        stops=[(0, (70, 40, 90)), (0.35, (255, 120, 160)), (0.58, (255, 186, 176)), (1, (80, 50, 70))],
        sun=(0.48, 0.5, 38, (255, 220, 200)),
        hills=[(0.0, 0.04), (0.5, 0.07), (1.0, 0.05)],
        hill_color=(32, 20, 36),
        water=True,
        city=False,
        cloud_tint=(255, 180, 200),
    ),
    dict(
        name="gold_hour",
        stops=[(0, (40, 48, 88)), (0.4, (255, 150, 70)), (0.62, (255, 210, 120)), (1, (90, 60, 40))],
        sun=(0.58, 0.5, 62, (255, 230, 160)),
        hills=[(0.0, 0.03), (0.45, 0.05), (1.0, 0.04)],
        hill_color=(34, 24, 22),
        water=True,
        city=False,
        cloud_tint=(255, 200, 140),
    ),
    dict(
        name="lavender_dusk",
        stops=[(0, (24, 20, 48)), (0.4, (110, 70, 140)), (0.62, (220, 130, 140)), (1, (36, 24, 40))],
        sun=(0.85, 0.56, 22, (255, 170, 140)),
        hills=[(0.0, 0.07), (0.35, 0.12), (0.7, 0.06), (1.0, 0.1)],
        hill_color=(18, 14, 28),
        water=False,
        city=False,
        cloud_tint=(180, 140, 200),
    ),
]


def render_recipe(recipe, size=(1400, 1750)):
    w, h = size
    rng = random.Random(sum(ord(c) for c in recipe["name"]))
    img = vertical_sky(w, h, recipe["stops"])
    sx, sy, r, sc = recipe["sun"]
    img = add_sun(img, int(sx * w), int(sy * h), r, sc)
    extra = recipe.get("extra_clouds", 7)
    img = add_clouds(img, rng, recipe["cloud_tint"], count=extra)
    horizon = int(h * 0.68)
    if recipe["water"]:
        img = add_water(img.convert("RGB"), horizon, shimmer=True)
        img = img.convert("RGBA")
    if recipe["city"]:
        img = add_city(img, horizon, rng, recipe["hill_color"])
    else:
        img = add_silhouette_hills(img, horizon, recipe["hills"], recipe["hill_color"])
    return finish(img)


def render_icon(size=1024):
    img = vertical_sky(
        size,
        size,
        [(0, (28, 24, 58)), (0.45, (232, 90, 78)), (0.7, (255, 176, 96)), (1, (40, 24, 32))],
    )
    img = add_sun(img, int(size * 0.58), int(size * 0.46), 90, (255, 210, 140), glow=2.2)
    img = add_silhouette_hills(
        img,
        int(size * 0.72),
        [(0, 0.04), (0.25, 0.1), (0.5, 0.05), (0.8, 0.12), (1, 0.06)],
        (22, 16, 24),
    )
    img = finish(img)
    # subtle circular crop feel via vignette
    vig = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(vig)
    d.ellipse((20, 20, size - 20, size - 20), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(28))
    # keep square (iOS icons are square) but darkened corners
    dark = Image.new("RGB", (size, size), (18, 12, 16))
    img = Image.composite(img, dark, vig)
    return img


def main():
    for recipe in RECIPES:
        out = PHOTOS / f"{recipe['name']}.jpg"
        render_recipe(recipe).save(out, "JPEG", quality=90)
        print("wrote", out.name)
    icon = render_icon()
    icon_path = ICON_DIR / "AppIcon.png"
    icon.save(icon_path, "PNG")
    print("wrote icon")


if __name__ == "__main__":
    main()
