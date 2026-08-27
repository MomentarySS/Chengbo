"""Generate 澄波 launcher icons: Android mipmaps, adaptive icon, Windows ICO."""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "assets" / "branding"

# Deep clear water, aligned with app seed Color(0xFF1565C0).
BG_CENTER = np.array([21, 102, 168], dtype=np.float64)  # #1565A8
BG_EDGE = np.array([8, 42, 78], dtype=np.float64)  # #082A4E
WAVE = (255, 255, 255, 255)
WAVE_SOFT = (214, 236, 248, 210)

ANDROID_LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
# Adaptive foreground is 108dp.
ANDROID_FOREGROUND = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}
ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)


def _radial_background(size: int) -> Image.Image:
    yy, xx = np.ogrid[:size, :size]
    cx = cy = (size - 1) / 2
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    t = np.clip(dist / (size * 0.72), 0, 1) ** 1.15
    rgb = BG_CENTER * (1 - t[..., None]) + BG_EDGE * t[..., None]
    arr = np.concatenate(
        [rgb.astype(np.uint8), np.full((size, size, 1), 255, dtype=np.uint8)],
        axis=2,
    )
    return Image.fromarray(arr, "RGBA")


def _wave_points(
    cx: float,
    cy: float,
    half_w: float,
    amp: float,
    cycles: float,
    n: int,
) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    for i in range(n):
        t = i / (n - 1)
        x = cx - half_w + 2 * half_w * t
        y = cy + amp * math.sin(2 * math.pi * cycles * t)
        pts.append((x, y))
    return pts


def _stroke_wave(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    width: float,
    fill: tuple[int, int, int, int],
) -> None:
    radius = width / 2
    for x, y in points:
        draw.ellipse(
            (x - radius, y - radius, x + radius, y + radius),
            fill=fill,
        )


def _draw_waves(draw: ImageDraw.ImageDraw, size: int, *, dual: bool) -> None:
    cx = cy = size / 2
    half_w = size * 0.28
    amp = size * 0.09
    stroke = max(size * 0.078, 2.0)
    gap = size * 0.11
    cycles = 1.0
    samples = max(int(half_w * 2.4), 64)

    if dual:
        _stroke_wave(
            draw,
            _wave_points(cx, cy - gap / 2, half_w, amp, cycles, samples),
            stroke,
            WAVE,
        )
        _stroke_wave(
            draw,
            _wave_points(cx, cy + gap / 2, half_w, amp * 0.92, cycles, samples),
            stroke * 0.72,
            WAVE_SOFT,
        )
    else:
        _stroke_wave(
            draw,
            _wave_points(cx, cy, half_w, amp * 1.05, cycles, samples),
            max(stroke, 3.0),
            WAVE,
        )


def render(*, size: int, background: bool, dual: bool | None = None) -> Image.Image:
    if dual is None:
        dual = size >= 32
    scale = 4 if size >= 48 else (3 if size >= 24 else 2)
    canvas = size * scale
    img = (
        _radial_background(canvas)
        if background
        else Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    )
    draw = ImageDraw.Draw(img, "RGBA")
    _draw_waves(draw, canvas, dual=dual)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def _save_ico(path: Path) -> None:
    images = [render(size=s, background=True).convert("RGBA") for s in ICO_SIZES]
    images[0].save(
        path,
        format="ICO",
        sizes=[(s, s) for s in ICO_SIZES],
        append_images=images[1:],
    )


def main() -> None:
    BRANDING.mkdir(parents=True, exist_ok=True)
    master = render(size=1024, background=True)
    foreground = render(size=1024, background=False)
    master.save(BRANDING / "app_icon.png", "PNG")
    foreground.save(BRANDING / "app_icon_foreground.png", "PNG")

    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, px in ANDROID_LEGACY.items():
        dest = res / folder
        dest.mkdir(parents=True, exist_ok=True)
        render(size=px, background=True).save(dest / "ic_launcher.png", "PNG")
    for folder, px in ANDROID_FOREGROUND.items():
        dest = res / folder
        dest.mkdir(parents=True, exist_ok=True)
        render(size=px, background=False).save(dest / "ic_launcher_foreground.png", "PNG")

    ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    _save_ico(ico)
    print(f"Wrote {BRANDING / 'app_icon.png'}")
    print(f"Wrote {ico}")


if __name__ == "__main__":
    main()
