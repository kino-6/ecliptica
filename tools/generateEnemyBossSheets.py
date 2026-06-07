from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


FRAME_COUNT = 8
ENEMY_FRAME = (96, 96)
BOSS_FRAME = (192, 160)
ENEMY_OUT = Path("assets/enemy-idle-sheet-8.png")
BOSS_OUT = Path("assets/boss-idle-sheet-8.png")


def main() -> None:
    write_sheet(ENEMY_OUT, ENEMY_FRAME[0], ENEMY_FRAME[1], draw_enemy_frame)
    write_sheet(BOSS_OUT, BOSS_FRAME[0], BOSS_FRAME[1], draw_boss_frame)


def write_sheet(path: Path, frame_width: int, frame_height: int, draw_func) -> None:
    width = frame_width * FRAME_COUNT
    pixels = bytearray(width * frame_height * 4)
    for frame in range(FRAME_COUNT):
        draw_func(pixels, width, frame * frame_width, frame_width, frame_height, frame)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(encode_png(width, frame_height, pixels))


def draw_enemy_frame(pixels: bytearray, sheet_width: int, x_offset: int, fw: int, fh: int, frame: int) -> None:
    bob = math.sin(frame / FRAME_COUNT * math.tau) * 2.0
    cx = fw * 0.5
    cy = fh * 0.56 + bob

    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy + 11, 28, 15, 0.0, (18, 20, 24, 150), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy + 3, 24, 30, -0.08, (31, 11, 17, 228), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 2, cy - 6, 17, 22, 0.18, (73, 16, 25, 232), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 9, cy - 10, 11, 16, -0.25, (105, 27, 31, 194), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 12, cy - 4, 8, 18, 0.55, (20, 29, 33, 188), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 2, cy - 24, 15, 10, 0.0, (24, 26, 29, 218), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 5, cy - 27, 8, 5, 0.0, (178, 152, 97, 190), fw, fh)

    for i in range(9):
        angle = -2.7 + i * 0.34 + frame * 0.05
        radius = 31 + (i % 3) * 4
        draw_circle(
            pixels,
            sheet_width,
            x_offset,
            cx + math.cos(angle) * radius,
            cy + math.sin(angle) * (radius * 0.65),
            2 + (i % 2),
            (88, 12, 22, 82) if i % 2 == 0 else (42, 51, 55, 74),
            fw,
            fh,
        )

    for i in range(18):
        px = cx - 24 + ((i * 13 + frame * 7) % 49)
        py = cy - 24 + ((i * 19 + frame * 5) % 52)
        tone = i % 6
        colors = [
            (139, 31, 35, 78),
            (102, 18, 29, 94),
            (57, 64, 66, 72),
            (151, 117, 69, 62),
            (26, 17, 22, 92),
            (196, 164, 93, 56),
        ]
        draw_circle(pixels, sheet_width, x_offset, px, py, 1 + (i % 2), colors[tone], fw, fh)

    draw_line(pixels, sheet_width, x_offset, cx - 17, cy - 28, cx - 30, cy - 40, 3, (35, 39, 41, 210), fw, fh)
    draw_line(pixels, sheet_width, x_offset, cx + 13, cy - 29, cx + 23, cy - 43, 3, (35, 39, 41, 210), fw, fh)


def draw_boss_frame(pixels: bytearray, sheet_width: int, x_offset: int, fw: int, fh: int, frame: int) -> None:
    pulse = math.sin(frame / FRAME_COUNT * math.tau)
    cx = fw * 0.5
    cy = fh * 0.55 + pulse * 2.0

    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy + 35, 62, 18, 0.0, (10, 11, 13, 150), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy + 4, 50, 56, -0.04, (26, 10, 15, 236), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 9, cy - 4, 38, 49, 0.1, (78, 13, 24, 232), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 18, cy - 11, 23, 42, -0.25, (116, 26, 31, 210), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 35, cy + 7, 18, 45, 0.46, (20, 29, 33, 202), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 41, cy + 5, 18, 43, -0.48, (19, 27, 31, 204), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy - 48, 32, 21, 0.0, (22, 24, 26, 238), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 10, cy - 51, 13, 8, 0.0, (184, 155, 91, 198), fw, fh)

    draw_line(pixels, sheet_width, x_offset, cx - 25, cy - 62, cx - 62, cy - 91, 5, (32, 35, 36, 225), fw, fh)
    draw_line(pixels, sheet_width, x_offset, cx + 25, cy - 62, cx + 62, cy - 91, 5, (32, 35, 36, 225), fw, fh)
    draw_line(pixels, sheet_width, x_offset, cx - 38, cy - 54, cx - 78, cy - 65, 4, (92, 18, 26, 164), fw, fh)
    draw_line(pixels, sheet_width, x_offset, cx + 38, cy - 54, cx + 78, cy - 65, 4, (92, 18, 26, 164), fw, fh)

    for i in range(26):
        angle = -2.8 + i * 0.22 + frame * 0.035
        radius = 58 + (i * 7 % 31)
        color = (126, 19, 29, 92) if i % 3 == 0 else (42, 51, 56, 78)
        draw_circle(
            pixels,
            sheet_width,
            x_offset,
            cx + math.cos(angle) * radius,
            cy + math.sin(angle) * radius * 0.62,
            3 + (i % 3),
            color,
            fw,
            fh,
        )


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
    fw: int,
    fh: int,
) -> None:
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(steps):
        t = i / max(steps - 1, 1)
        draw_circle(pixels, sheet_width, x_offset, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, radius, color, fw, fh)


def draw_circle(
    pixels: bytearray,
    sheet_width: int,
    x_offset: int,
    cx: float,
    cy: float,
    radius: int,
    color: tuple[int, int, int, int],
    fw: int,
    fh: int,
) -> None:
    for y in range(int(cy - radius), int(cy + radius) + 1):
        for x in range(int(cx - radius), int(cx + radius) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius**2:
                blend_pixel(pixels, sheet_width, x_offset + x, y, color, fw, fh)


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
    fw: int,
    fh: int,
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
                blend_pixel(pixels, sheet_width, x_offset + x, y, color, fw, fh)


def blend_pixel(pixels: bytearray, sheet_width: int, x: int, y: int, color: tuple[int, int, int, int], fw: int, fh: int) -> None:
    if y < 4 or y >= fh - 4:
        return
    local_x = x % fw
    if local_x < 4 or local_x >= fw - 4:
        return
    if x < 0 or x >= sheet_width:
        return
    idx = (y * sheet_width + x) * 4
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
