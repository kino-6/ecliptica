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
        progress = frame / (FRAME_COUNT - 1)
        start = math.radians(-58 + progress * 92)
        draw_swing_frame(pixels, width, x_offset, start)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(encode_png(width, height, pixels))


def draw_swing_frame(pixels: bytearray, sheet_width: int, x_offset: int, angle: float) -> None:
    cx = 42
    cy = 72
    handle_length = 58
    blade_distance = 74
    blade_angle = angle - 0.26
    arc_start = angle - 0.48
    arc_end = angle + 0.30

    draw_arc(pixels, sheet_width, x_offset, cx, cy, 56, arc_start, arc_end, 6, (214, 222, 222, 72))
    draw_arc(pixels, sheet_width, x_offset, cx, cy, 63, arc_start, arc_end, 4, (132, 145, 148, 120))

    hx0 = cx + math.cos(angle + math.pi) * 8
    hy0 = cy + math.sin(angle + math.pi) * 8
    hx1 = cx + math.cos(angle) * handle_length
    hy1 = cy + math.sin(angle) * handle_length
    draw_line(pixels, sheet_width, x_offset, hx0, hy0, hx1, hy1, 5, (58, 44, 37, 235))
    draw_line(pixels, sheet_width, x_offset, hx0, hy0, hx1, hy1, 2, (112, 83, 56, 255))

    bx = cx + math.cos(blade_angle) * blade_distance
    by = cy + math.sin(blade_angle) * blade_distance
    draw_rotated_ellipse(pixels, sheet_width, x_offset, bx, by, 18, 8, blade_angle + math.pi / 2, (185, 196, 198, 238))
    draw_rotated_ellipse(pixels, sheet_width, x_offset, bx + math.cos(blade_angle) * 4, by + math.sin(blade_angle) * 4, 10, 4, blade_angle + math.pi / 2, (238, 241, 235, 255))


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
