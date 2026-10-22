#!/usr/bin/env python3
"""Genera el icono de Aura Music estilo YouTube Music.

Diseño: círculo rojo (#FF0033) con anillo blanco y triángulo de «play»
blanco centrado (proporciones del icono oficial de YouTube Music).

Genera:
  - mipmap-*/ic_launcher.png e ic_launcher_round.png (icono clásico)
  - mipmap-*/ic_launcher_foreground.png (capa frontal adaptativa)
  - mipmap-*/ic_launcher_mono.png (icono monocromo para Android 13+)
  - mipmap-anydpi-v26/ic_launcher.xml e ic_launcher_round.xml
  - values/ic_launcher_background.xml (color de fondo de la capa)

Uso:  python3 tool/make_app_icon.py
"""

from __future__ import annotations

import math
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.normpath(os.path.join(HERE, os.pardir, "android", "app", "src", "main", "res"))

RED = (255, 0, 51, 255)          # #FF0033, rojo YouTube Music
RED_EDGE = (214, 3, 28, 255)     # borde inferior derecho (sombra sutil)
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)

PNG_DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
ADAPTIVE_DENSITIES = {  # 108dp de lienzo con zona segura de 66dp
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}


# ────────────────────────────── PNG writer ──────────────────────────────

def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def save_png(path: str, size: int, pixels: list) -> None:
    raw = bytearray()
    for y in range(size):
        raw.append(0)  # filtro: None
        row = pixels[y]
        for x in range(size):
            r, g, b, a = row[x]
            raw += bytes((r & 0xFF, g & 0xFF, b & 0xFF, a & 0xFF))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(
            b"IHDR",
            struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0),
        )
        + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(png)


# ────────────────────────────── dibujo ──────────────────────────────

def blend(dst: tuple, src: tuple, alpha: float) -> tuple:
    if alpha >= 1.0:
        return src
    if alpha <= 0.0:
        return dst
    a = src[3] * alpha
    out_a = a + dst[3] * (1.0 - alpha)
    if out_a <= 0:
        return TRANSPARENT
    ch = []
    for i in range(3):
        ch.append(int(round((src[i] * a + dst[i] * dst[3] * (1.0 - alpha)) / out_a)))
    return (ch[0], ch[1], ch[2], int(round(out_a)))


def make_legacy_icon(size: int) -> list:
    """Icono clásico: círculo rojo sobre fondo transparente."""
    px = [[TRANSPARENT for _ in range(size)] for _ in range(size)]
    center = (size - 1) / 2.0
    radius = size * 0.5 - max(1.0, size * 0.015)
    _draw_circle(px, size, center, center, radius, RED, RED_EDGE)
    ring_r = size * 0.30
    tri_r = size * 0.15
    _draw_ring_and_triangle(px, size, center, center, ring_r, tri_r)
    return px


def make_foreground(size: int) -> list:
    """Capa frontal adaptativa: círculo dentro de la zona segura (66/108)."""
    px = [[TRANSPARENT for _ in range(size)] for _ in range(size)]
    center = (size - 1) / 2.0
    radius = size * (66.0 / 108.0) / 2.0
    _draw_circle(px, size, center, center, radius, RED, RED_EDGE)
    _draw_ring_and_triangle(
        px, size, center, center, radius * 0.595, radius * 0.30
    )
    return px


def make_mono_foreground(size: int) -> list:
    """Icono monocromo (Android 13+): solo triángulo en blanco."""
    px = [[TRANSPARENT for _ in range(size)] for _ in range(size)]
    center = (size - 1) / 2.0
    radius = size * (66.0 / 108.0) / 2.0
    _draw_play_triangle(
        px, size, center + radius * 0.04, center, radius * 0.30
    )
    return px


def _draw_circle(px, size, cx, cy, radius, color, edge_color) -> None:
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            # Anti-aliasing de 1px en el borde.
            alpha = max(0.0, min(1.0, radius - d + 0.5))
            if alpha <= 0.0:
                continue
            # Degradado sutil: borde inferior-derecho un poco más oscuro.
            nx = (x - cx) / radius
            ny = (y - cy) / radius
            shade = (nx + ny) / 2.0  # -1..1
            base = color if shade < 0.25 else edge_color
            if 0.0 <= shade < 0.25:
                t = shade / 0.25
                base = tuple(
                    int(round(color[i] + (edge_color[i] - color[i]) * t))
                    for i in range(3)
                ) + (255,)
            px[y][x] = blend(px[y][x], base, alpha)


def _draw_ring_and_triangle(px, size, cx, cy, ring_r, tri_r) -> None:
    # Anillo blanco (círculo con agujero).
    thickness = max(2, int(round(size * 0.028)))
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            if abs(d - ring_r) <= thickness / 2.0 + 0.5:
                alpha = max(
                    0.0, min(1.0, thickness / 2.0 + 0.5 - abs(d - ring_r))
                )
                px[y][x] = blend(px[y][x], WHITE, alpha)
    _draw_play_triangle(px, size, cx, cy, tri_r)


def _draw_play_triangle(px, size, cx, cy, tri_r) -> None:
    height = tri_r * math.sqrt(3.0)
    left = cx - tri_r / 2.0
    right = cx + tri_r
    top = cy - height / 2.0
    bottom = cy + height / 2.0

    def inside(px_, py_) -> bool:
        # Triángulo apuntando a la derecha con esquinas redondeadas suaves.
        if px_ < left - 0.5 or px_ > right + 0.5:
            return False
        t = (px_ - left) / (right - left)
        t = max(0.0, min(1.0, t))
        half_h = (height / 2.0) * (1.0 - t)
        return abs(py_ - cy) <= half_h

    for y in range(size):
        for x in range(size):
            if inside(x + 0.5, y + 0.5):
                px[y][x] = blend(px[y][x], WHITE, 1.0)


# ────────────────────────────── recursos ──────────────────────────────

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_mono"/>
</adaptive-icon>
"""

COLORS_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FF0033</color>
</resources>
"""


def main() -> None:
    # Iconos clásicos.
    for density, size in PNG_DENSITIES.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        save_png(os.path.join(folder, "ic_launcher.png"), size, make_legacy_icon(size))
        save_png(
            os.path.join(folder, "ic_launcher_round.png"),
            size,
            make_legacy_icon(size),
        )

    # Capas adaptativas.
    for density, size in ADAPTIVE_DENSITIES.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        save_png(
            os.path.join(folder, "ic_launcher_foreground.png"),
            size,
            make_foreground(size),
        )
        save_png(
            os.path.join(folder, "ic_launcher_mono.png"),
            size,
            make_mono_foreground(size),
        )

    # XML adaptativo y color de fondo.
    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w") as fh:
        fh.write(ADAPTIVE_XML)
    with open(os.path.join(anydpi, "ic_launcher_round.xml"), "w") as fh:
        fh.write(ADAPTIVE_XML)

    values = os.path.join(RES, "values")
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, "ic_launcher_background.xml"), "w") as fh:
        fh.write(COLORS_XML)

    print("Icono generado en", RES)


if __name__ == "__main__":
    main()
