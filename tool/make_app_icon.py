#!/usr/bin/env python3
"""Genera el icono y los recursos gráficos propios de Aura («A·Play»).

Diseño sobre lienzo normalizado 100 × 100 con antialiasing por supermuestreo 4×:
  - A: polilínea (20, 82) -> (50, 18) -> (80, 82) con grosor 13, extremos y
    unión redondeados («cápsula»), y degradado diagonal de marca
    (#FF8A3D -> #FF3D7F -> #8B5CFF).
  - Play: triángulo (45, 56.5) (45, 71.5) (59, 64) blanco con borde redondeado
    de grosor 3.
  - Icono completo: fondo #0E0B14 (cuadrado redondeado radio 23 o círculo),
    brillo radial en (50 %, 62 %) de radio 55 % (#FF3D7F 42 % -> #8B5CFF 14 % ->
    transparente) y la A centrada al 68 %.
  - Capa adaptativa: fondo transparente con brillo radial y la A al 58 % dentro
    de la zona segura de 66 dp; variante monocroma en blanco sólido.
  - Icono de notificación: A blanca sólida sobre transparente al ~85 % del lienzo.

Genera:
  - mipmap-*/ic_launcher.png e ic_launcher_round.png (48..192 px)
  - mipmap-*/ic_launcher_foreground.png e ic_launcher_mono.png (108..432 px)
  - mipmap-anydpi-v26/ic_launcher.xml e ic_launcher_round.xml
  - values/ic_launcher_background.xml (#0E0B14)
  - drawable-*/ic_stat_aura.png (24..96 px)

Uso: python3 tool/make_app_icon.py
"""

from __future__ import annotations

import math
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.normpath(
    os.path.join(HERE, os.pardir, "android", "app", "src", "main", "res")
)

# Colores de marca (deben mantenerse alineados con AppTheme en app_theme.dart).
BRAND_INK = (14, 11, 20)        # #0E0B14
BRAND_EMBER = (255, 138, 61)    # #FF8A3D
BRAND_ROSE = (255, 61, 127)     # #FF3D7F
BRAND_VIOLET = (139, 92, 255)   # #8B5CFF
WHITE = (255, 255, 255)         # #FFFFFF

# Límites y parámetros geométricos de la A y el triángulo de play en 100 × 100.
A_RADIUS_SQ = 6.5 * 6.5
PLAY_RADIUS_SQ = 1.5 * 1.5
A_BOX_MIN_X = 20.0
A_BOX_MIN_Y = 18.0
A_DIAG_DX = 60.0
A_DIAG_DY = 64.0
A_DIAG_LEN_SQ = A_DIAG_DX * A_DIAG_DX + A_DIAG_DY * A_DIAG_DY

# Límites exactos del isotipo (A + play) en su propio espacio 100 × 100.
MARK_MIN_X = 13.5
MARK_MAX_X = 86.5
MARK_MIN_Y = 11.5
MARK_MAX_Y = 88.5

# Brillo radial premultiplicado: (r * a, g * a, b * a, a) en cada parada.
GLOW_CX = 50.0
GLOW_CY = 62.0
GLOW_RADIUS = 55.0
GLOW_S0 = (BRAND_ROSE[0] * 0.42, BRAND_ROSE[1] * 0.42, BRAND_ROSE[2] * 0.42, 0.42)
GLOW_S1 = (BRAND_VIOLET[0] * 0.14, BRAND_VIOLET[1] * 0.14, BRAND_VIOLET[2] * 0.14, 0.14)
GLOW_S2 = (0.0, 0.0, 0.0, 0.0)

PNG_DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
ADAPTIVE_DENSITIES = {  # lienzo de 108 dp con zona segura de 66 dp
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}
NOTIFICATION_DENSITIES = {
    "mdpi": 24,
    "hdpi": 36,
    "xhdpi": 48,
    "xxhdpi": 72,
    "xxxhdpi": 96,
}

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_mono"/>
</adaptive-icon>
"""

COLORS_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0E0B14</color>
</resources>
"""


# ────────────────────────────── Escritor PNG ──────────────────────────────


def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def save_png(path: str, size: int, rows: list[bytes]) -> None:
    raw = bytearray()
    for row in rows:
        raw.append(0)  # filtro: None
        raw.extend(row)
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


# ────────────────────────────── Geometría ──────────────────────────────


def _dist_sq_segment(
    px: float, py: float, ax: float, ay: float, bx: float, by: float
) -> float:
    abx = bx - ax
    aby = by - ay
    len_sq = abx * abx + aby * aby
    t = ((px - ax) * abx + (py - ay) * aby) / len_sq
    if t <= 0.0:
        dx = px - ax
        dy = py - ay
    elif t >= 1.0:
        dx = px - bx
        dy = py - by
    else:
        dx = px - (ax + t * abx)
        dy = py - (ay + t * aby)
    return dx * dx + dy * dy


def _in_a_stroke(mx: float, my: float) -> bool:
    d1 = _dist_sq_segment(mx, my, 20.0, 82.0, 50.0, 18.0)
    if d1 <= A_RADIUS_SQ:
        return True
    d2 = _dist_sq_segment(mx, my, 50.0, 18.0, 80.0, 82.0)
    return d2 <= A_RADIUS_SQ


def _in_play_triangle(mx: float, my: float) -> bool:
    # Triángulo (45, 56.5) (45, 71.5) (59, 64) con borde redondeado de radio 1.5.
    if mx < 43.5 or mx > 60.5 or my < 55.0 or my > 73.0:
        return False
    if 45.0 <= mx <= 59.0:
        half_h = 7.5 * (59.0 - mx) / 14.0
        if abs(my - 64.0) <= half_h:
            return True
    d1 = _dist_sq_segment(mx, my, 45.0, 56.5, 45.0, 71.5)
    if d1 <= PLAY_RADIUS_SQ:
        return True
    d2 = _dist_sq_segment(mx, my, 45.0, 56.5, 59.0, 64.0)
    if d2 <= PLAY_RADIUS_SQ:
        return True
    d3 = _dist_sq_segment(mx, my, 45.0, 71.5, 59.0, 64.0)
    return d3 <= PLAY_RADIUS_SQ


def _brand_gradient_at(mx: float, my: float) -> tuple[float, float, float]:
    t = ((mx - A_BOX_MIN_X) * A_DIAG_DX + (my - A_BOX_MIN_Y) * A_DIAG_DY) / A_DIAG_LEN_SQ
    if t <= 0.0:
        return (float(BRAND_EMBER[0]), float(BRAND_EMBER[1]), float(BRAND_EMBER[2]))
    if t >= 1.0:
        return (float(BRAND_VIOLET[0]), float(BRAND_VIOLET[1]), float(BRAND_VIOLET[2]))
    if t <= 0.5:
        u = t * 2.0
        return (
            BRAND_EMBER[0] + (BRAND_ROSE[0] - BRAND_EMBER[0]) * u,
            BRAND_EMBER[1] + (BRAND_ROSE[1] - BRAND_EMBER[1]) * u,
            BRAND_EMBER[2] + (BRAND_ROSE[2] - BRAND_EMBER[2]) * u,
        )
    u = (t - 0.5) * 2.0
    return (
        BRAND_ROSE[0] + (BRAND_VIOLET[0] - BRAND_ROSE[0]) * u,
        BRAND_ROSE[1] + (BRAND_VIOLET[1] - BRAND_ROSE[1]) * u,
        BRAND_ROSE[2] + (BRAND_VIOLET[2] - BRAND_ROSE[2]) * u,
    )


def _glow_premul_at(x: float, y: float) -> tuple[float, float, float, float]:
    dist = math.hypot(x - GLOW_CX, y - GLOW_CY) / GLOW_RADIUS
    if dist >= 1.0:
        return GLOW_S2
    if dist <= 0.55:
        u = dist / 0.55
        return (
            GLOW_S0[0] + (GLOW_S1[0] - GLOW_S0[0]) * u,
            GLOW_S0[1] + (GLOW_S1[1] - GLOW_S0[1]) * u,
            GLOW_S0[2] + (GLOW_S1[2] - GLOW_S0[2]) * u,
            GLOW_S0[3] + (GLOW_S1[3] - GLOW_S0[3]) * u,
        )
    u = (dist - 0.55) / 0.45
    one_minus_u = 1.0 - u
    return (
        GLOW_S1[0] * one_minus_u,
        GLOW_S1[1] * one_minus_u,
        GLOW_S1[2] * one_minus_u,
        GLOW_S1[3] * one_minus_u,
    )


def _in_rounded_rect(x: float, y: float) -> bool:
    qx = abs(x - 50.0) - 27.0
    qy = abs(y - 50.0) - 27.0
    if qx <= 0.0 and qy <= 0.0:
        return True
    if qx < 0.0:
        qx = 0.0
    if qy < 0.0:
        qy = 0.0
    return qx * qx + qy * qy <= 529.0  # 23^2


def _in_circle(x: float, y: float) -> bool:
    dx = x - 50.0
    dy = y - 50.0
    return dx * dx + dy * dy <= 2500.0  # 50^2


# ────────────────────────────── Renderizado ──────────────────────────────


def render_icon(
    size: int,
    *,
    background_shape: str,
    mark_scale: float,
    monochrome: bool,
) -> list[bytes]:
    """Renderiza un icono cuadrado de [size] px usando supermuestreo 4×4."""
    inv_scale = 1.0 / mark_scale
    offset = 50.0 * (1.0 - mark_scale)
    unit = 100.0 / size
    sub_offsets = (0.125 * unit, 0.375 * unit, 0.625 * unit, 0.875 * unit)

    # Caja envolvente del isotipo en coordenadas 100 × 100 para poda exacta.
    mark_x0 = offset + MARK_MIN_X * mark_scale
    mark_x1 = offset + MARK_MAX_X * mark_scale
    mark_y0 = offset + MARK_MIN_Y * mark_scale
    mark_y1 = offset + MARK_MAX_Y * mark_scale

    has_bg_ink = background_shape in ("rounded", "circle")
    has_glow = background_shape in ("rounded", "circle", "transparent_glow")
    shape_fn = (
        _in_rounded_rect
        if background_shape == "rounded"
        else (_in_circle if background_shape == "circle" else None)
    )

    ink_r, ink_g, ink_b = float(BRAND_INK[0]), float(BRAND_INK[1]), float(BRAND_INK[2])
    white_r, white_g, white_b = float(WHITE[0]), float(WHITE[1]), float(WHITE[2])
    rows: list[bytes] = []

    for py in range(size):
        y_base = py * unit
        y_in_mark_band = (y_base + unit) >= mark_y0 and y_base <= mark_y1
        row = bytearray(size * 4)

        for px in range(size):
            x_base = px * unit
            check_mark = (
                y_in_mark_band and (x_base + unit) >= mark_x0 and x_base <= mark_x1
            )

            # Poda exacta de píxeles completamente transparentes.
            if not has_glow and not check_mark:
                continue

            # Si el píxel está completamente dentro del fondo sólido (sin borde),
            # no necesita evaluar la máscara geométrica en las 16 submuestras.
            bg_all_inside = False
            if shape_fn is not None:
                c00 = shape_fn(x_base, y_base)
                c10 = shape_fn(x_base + unit, y_base)
                c01 = shape_fn(x_base, y_base + unit)
                c11 = shape_fn(x_base + unit, y_base + unit)
                bg_all_inside = c00 and c10 and c01 and c11
                if not bg_all_inside and not (c00 or c10 or c01 or c11):
                    # En las esquinas fuera de la máscara no hay icono ni brillo.
                    continue

            sum_ra = 0.0
            sum_ga = 0.0
            sum_ba = 0.0
            sum_a = 0.0

            for sy in range(4):
                y = y_base + sub_offsets[sy]
                my = (y - offset) * inv_scale
                for sx in range(4):
                    x = x_base + sub_offsets[sx]

                    if shape_fn is not None and not bg_all_inside:
                        if not shape_fn(x, y):
                            continue

                    if check_mark:
                        mx = (x - offset) * inv_scale
                        if _in_play_triangle(mx, my):
                            sum_ra += white_r
                            sum_ga += white_g
                            sum_ba += white_b
                            sum_a += 1.0
                            continue
                        if _in_a_stroke(mx, my):
                            if monochrome:
                                sum_ra += white_r
                                sum_ga += white_g
                                sum_ba += white_b
                            else:
                                gr, gg, gb = _brand_gradient_at(mx, my)
                                sum_ra += gr
                                sum_ga += gg
                                sum_ba += gb
                            sum_a += 1.0
                            continue

                    if has_glow:
                        glow_ra, glow_ga, glow_ba, glow_a = _glow_premul_at(x, y)
                        if has_bg_ink:
                            inv_ga = 1.0 - glow_a
                            sum_ra += glow_ra + ink_r * inv_ga
                            sum_ga += glow_ga + ink_g * inv_ga
                            sum_ba += glow_ba + ink_b * inv_ga
                            sum_a += 1.0
                        else:
                            sum_ra += glow_ra
                            sum_ga += glow_ga
                            sum_ba += glow_ba
                            sum_a += glow_a

            if sum_a <= 0.0:
                continue

            avg_a = sum_a / 16.0
            out_a = int(round(avg_a * 255.0))
            if out_a <= 0:
                continue
            out_r = min(255, int(round(sum_ra / sum_a)))
            out_g = min(255, int(round(sum_ga / sum_a)))
            out_b = min(255, int(round(sum_ba / sum_a)))
            idx = px * 4
            row[idx] = out_r
            row[idx + 1] = out_g
            row[idx + 2] = out_b
            row[idx + 3] = min(255, out_a)

        rows.append(bytes(row))

    return rows


# ────────────────────────────── Generación ──────────────────────────────


def main() -> None:
    # Iconos clásicos del lanzador (cuadrado redondeado y circular).
    for density, size in PNG_DENSITIES.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        save_png(
            os.path.join(folder, "ic_launcher.png"),
            size,
            render_icon(
                size,
                background_shape="rounded",
                mark_scale=0.68,
                monochrome=False,
            ),
        )
        save_png(
            os.path.join(folder, "ic_launcher_round.png"),
            size,
            render_icon(
                size,
                background_shape="circle",
                mark_scale=0.68,
                monochrome=False,
            ),
        )

    # Capas adaptativas (zona segura de 66/108 -> escala 0.58).
    for density, size in ADAPTIVE_DENSITIES.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        save_png(
            os.path.join(folder, "ic_launcher_foreground.png"),
            size,
            render_icon(
                size,
                background_shape="transparent_glow",
                mark_scale=0.58,
                monochrome=False,
            ),
        )
        save_png(
            os.path.join(folder, "ic_launcher_mono.png"),
            size,
            render_icon(
                size,
                background_shape="transparent",
                mark_scale=0.58,
                monochrome=True,
            ),
        )

    # Icono pequeño de notificación (blanco sólido sobre transparente, ~85 %).
    for density, size in NOTIFICATION_DENSITIES.items():
        folder = os.path.join(RES, f"drawable-{density}")
        save_png(
            os.path.join(folder, "ic_stat_aura.png"),
            size,
            render_icon(
                size,
                background_shape="transparent",
                mark_scale=1.10,
                monochrome=True,
            ),
        )

    # XML adaptativos y color de fondo de marca.
    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8") as fh:
        fh.write(ADAPTIVE_XML)
    with open(
        os.path.join(anydpi, "ic_launcher_round.xml"), "w", encoding="utf-8"
    ) as fh:
        fh.write(ADAPTIVE_XML)

    values = os.path.join(RES, "values")
    os.makedirs(values, exist_ok=True)
    with open(
        os.path.join(values, "ic_launcher_background.xml"), "w", encoding="utf-8"
    ) as fh:
        fh.write(COLORS_XML)

    print("Iconos de Aura generados en", RES)


if __name__ == "__main__":
    main()
