from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


FRAME_WIDTH = 128
FRAME_HEIGHT = 128
FRAME_COUNT = 8
OUT = Path("assets/axe-swing-sheet-8.png")


def main() -> None:
    width = FRAME_WIDTH * FRAME_COUNT
    height = FRAME_HEIGHT
    pixels = bytearray(width * height * 4)

    for frame in range(FRAME_COUNT):
        x_offset = frame * FRAME_WIDTH
        draw_swing_frame(pixels, width, x_offset, frame)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(encode_png(width, height, pixels))


def draw_swing_frame(pixels: bytearray, sheet_width: int, x_offset: int, frame: int) -> None:
    cx = 42
    cy = 72
    angle_degrees = [-76, -72, -18, 31, 67, 84, 73, 58]
    arc_widths = [0.46, 0.50, 0.92, 1.10, 0.84, 0.68, 0.56, 0.48]
    intensity = [0.72, 0.74, 1.0, 1.25, 1.02, 0.88, 0.76, 0.68][frame]
    angle = math.radians(angle_degrees[frame])
    handle_length = 60
    blade_distance = 76
    blade_angle = angle - 0.26
    arc_start = angle - arc_widths[frame]
    arc_end = angle + arc_widths[frame] * (0.58 if frame < 4 else 0.42)

    draw_arc(pixels, sheet_width, x_offset, cx, cy, 47, arc_start, arc_end, 15, scale_color((33, 12, 17, 132), intensity))
    draw_arc(pixels, sheet_width, x_offset, cx, cy, 58, arc_start - 0.03, arc_end + 0.04, 14, scale_color((86, 16, 24, 156), intensity))
    draw_arc(pixels, sheet_width, x_offset, cx, cy, 69, arc_start + 0.06, arc_end - 0.01, 10, scale_color((22, 32, 38, 124), intensity))
    draw_arc(pixels, sheet_width, x_offset, cx, cy, 76, arc_start + 0.12, arc_end - 0.10, 6, scale_color((166, 143, 92, 132), intensity))
    draw_arc(pixels, sheet_width, x_offset, cx, cy, 84, arc_start + 0.20, arc_end - 0.20, 4, scale_color((224, 217, 176, 108), intensity))
    if frame in [2, 3, 4]:
        draw_impact_smear(pixels, sheet_width, x_offset, cx, cy, arc_start, arc_end, frame)
    draw_sparks(pixels, sheet_width, x_offset, cx, cy, arc_start, arc_end, frame_seed=frame * 271)

    hx0 = cx + math.cos(angle + math.pi) * 8
    hy0 = cy + math.sin(angle + math.pi) * 8
    hx1 = cx + math.cos(angle) * handle_length
    hy1 = cy + math.sin(angle) * handle_length
    draw_line(pixels, sheet_width, x_offset, hx0, hy0, hx1, hy1, 7, (20, 14, 13, 236))
    draw_line(pixels, sheet_width, x_offset, hx0, hy0, hx1, hy1, 4, (61, 42, 31, 248))
    draw_line(pixels, sheet_width, x_offset, hx0, hy0, hx1, hy1, 2, (151, 108, 69, 238))

    bx = cx + math.cos(blade_angle) * blade_distance
    by = cy + math.sin(blade_angle) * blade_distance
    blade_scale = 1.18 if frame == 3 else 1.0
    draw_rotated_ellipse(pixels, sheet_width, x_offset, bx, by, 29 * blade_scale, 13 * blade_scale, blade_angle + math.pi / 2, (29, 36, 40, 246))
    draw_rotated_ellipse(pixels, sheet_width, x_offset, bx + math.cos(blade_angle) * 1, by + math.sin(blade_angle) * 1, 24 * blade_scale, 9 * blade_scale, blade_angle + math.pi / 2, (130, 137, 134, 248))
    draw_rotated_ellipse(pixels, sheet_width, x_offset, bx + math.cos(blade_angle) * 6, by + math.sin(blade_angle) * 6, 17 * blade_scale, 5 * blade_scale, blade_angle + math.pi / 2, (226, 221, 188, 252))
    draw_rotated_ellipse(pixels, sheet_width, x_offset, bx - math.cos(blade_angle) * 9, by - math.sin(blade_angle) * 9, 18, 6, blade_angle + math.pi / 2, (89, 15, 21, 146))
    if frame == 3:
        draw_rotated_ellipse(pixels, sheet_width, x_offset, bx + 5, by - 2, 24, 6, blade_angle + math.pi / 2, (239, 229, 184, 172))


def draw_impact_smear(
    pixels: bytearray,
    sheet_width: int,
    x_offset: int,
    cx: float,
    cy: float,
    start: float,
    end: float,
    frame: int,
) -> None:
    colors = [
        (111, 20, 26, 98),
        (29, 38, 44, 104),
        (192, 158, 91, 94),
    ]
    for band in range(3):
        radius = 50 + band * 13 + frame * 2
        thickness = 8 - band
        draw_arc(pixels, sheet_width, x_offset, cx, cy, radius, start + band * 0.07, end - band * 0.04, thickness, colors[band])


def scale_color(color: tuple[int, int, int, int], intensity: float) -> tuple[int, int, int, int]:
    return (
        min(255, int(color[0] * intensity)),
        min(255, int(color[1] * intensity)),
        min(255, int(color[2] * intensity)),
        min(255, int(color[3] * min(1.25, intensity))),
    )


def draw_sparks(
    pixels: bytearray,
    sheet_width: int,
    x_offset: int,
    cx: float,
    cy: float,
    start: float,
    end: float,
    frame_seed: int,
) -> None:
    for i in range(18):
        t = (i + 0.35) / 18
        angle = start + (end - start) * t
        radius = 56 + ((i * 17 + frame_seed) % 28)
        jitter = math.sin(i * 12.989 + frame_seed * 0.017) * 5.5
        x = cx + math.cos(angle) * radius + jitter
        y = cy + math.sin(angle) * radius - jitter * 0.35
        if i % 3 == 0:
            color = (184, 34, 33, 104)
        elif i % 3 == 1:
            color = (196, 151, 82, 88)
        else:
            color = (49, 58, 64, 74)
        draw_circle(pixels, sheet_width, x_offset, x, y, 2 + (i % 2), color)


def draw_arc(
    pixels: bytearray,
    sheet_width: int,
    x_offset: int,
    cx: float,
    cy: float,
    radius: float,
    start: float,
    end: float,
    thickness: int,
    color: tuple[int, int, int, int],
) -> None:
    steps = 42
    for i in range(steps):
        t = i / max(steps - 1, 1)
        angle = start + (end - start) * t
        x = cx + math.cos(angle) * radius
        y = cy + math.sin(angle) * radius
        draw_circle(pixels, sheet_width, x_offset, x, y, thickness, color)


def draw_line(
    pixels: bytearray,
    sheet_width: int,
    x_offset: int,
    x0: float,
    y0: float,
    x1: float,
    y1: float,
    radius: int,
    color: tuple[int, int, int, int],
) -> None:
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(steps):
        t = i / max(steps - 1, 1)
        draw_circle(pixels, sheet_width, x_offset, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, radius, color)


def draw_circle(
    pixels: bytearray,
    sheet_width: int,
    x_offset: int,
    cx: float,
    cy: float,
    radius: int,
    color: tuple[int, int, int, int],
) -> None:
    for y in range(int(cy - radius), int(cy + radius) + 1):
        for x in range(int(cx - radius), int(cx + radius) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius**2:
                blend_pixel(pixels, sheet_width, x_offset + x, y, color)


def draw_rotated_ellipse(
    pixels: bytearray,
    sheet_width: int,
    x_offset: int,
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    angle: float,
    color: tuple[int, int, int, int],
) -> None:
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    for y in range(int(cy - rx), int(cy + rx) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            dx = x - cx
            dy = y - cy
            local_x = dx * cos_a + dy * sin_a
            local_y = -dx * sin_a + dy * cos_a
            if (local_x / rx) ** 2 + (local_y / ry) ** 2 <= 1:
                blend_pixel(pixels, sheet_width, x_offset + x, y, color)


def blend_pixel(pixels: bytearray, width: int, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if x < 4 or y < 4 or x >= width - 4 or y >= FRAME_HEIGHT - 4:
        return
    if x % FRAME_WIDTH < 4 or x % FRAME_WIDTH >= FRAME_WIDTH - 4:
        return
    idx = (y * width + x) * 4
    src_a = color[3] / 255
    dst_a = pixels[idx + 3] / 255
    out_a = src_a + dst_a * (1 - src_a)
    if out_a <= 0:
        return
    for channel in range(3):
        src = color[channel] / 255
        dst = pixels[idx + channel] / 255
        pixels[idx + channel] = round(((src * src_a) + (dst * dst_a * (1 - src_a))) / out_a * 255)
    pixels[idx + 3] = round(out_a * 255)


def encode_png(width: int, height: int, pixels: bytearray) -> bytes:
    rows = bytearray()
    stride = width * 4
    for y in range(height):
        rows.append(0)
        rows.extend(pixels[y * stride : (y + 1) * stride])

    return b"".join(
        [
            b"\x89PNG\r\n\x1a\n",
            chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
            chunk(b"IDAT", zlib.compress(bytes(rows), 9)),
            chunk(b"IEND", b""),
        ]
    )


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


if __name__ == "__main__":
    main()
