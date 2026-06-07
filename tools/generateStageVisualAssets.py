from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


PLATFORM_OUT = Path("assets/platform-stone-tile.png")
SHOT_OUT = Path("assets/player-shot.png")


def main() -> None:
    PLATFORM_OUT.parent.mkdir(parents=True, exist_ok=True)
    PLATFORM_OUT.write_bytes(encode_png(96, 64, platform_pixels()))
    SHOT_OUT.write_bytes(encode_png(64, 24, shot_pixels()))


def platform_pixels() -> bytearray:
    width = 96
    height = 64
    pixels = bytearray(width * height * 4)
    blocks = [
        (0, 0, 30, 22),
        (30, 0, 63, 22),
        (63, 0, 96, 22),
        (0, 22, 47, 43),
        (47, 22, 96, 43),
        (0, 43, 34, 64),
        (34, 43, 70, 64),
        (70, 43, 96, 64),
    ]
    block_shades = [-7, 4, -3, 8, -10, 2, -5, 6]

    for y in range(height):
        for x in range(width):
            shade = block_shades[block_index(blocks, x, y)]
            noise = hash_noise(x, y, 9) % 17 - 8
            wet = int(8 * math.sin((x * 0.13) + (y * 0.19)))
            top_light = max(0, 16 - y) if y < 16 else 0
            crack_dark = -22 if is_mortar_or_crack(x, y) else 0
            r = clamp(37 + shade + noise + top_light // 2 + crack_dark)
            g = clamp(43 + shade + noise + top_light // 2 + wet // 2 + crack_dark)
            b = clamp(53 + shade + noise + top_light + wet + crack_dark)
            set_pixel(pixels, width, x, y, (r, g, b, 255))

    for x in range(width):
        if x % 3 != 1:
            blend_pixel(pixels, width, x, 0, (148, 146, 126, 138))
            blend_pixel(pixels, width, x, 1, (96, 101, 103, 108))
        if hash_noise(x, 3, 41) % 5 == 0:
            blend_pixel(pixels, width, x, 5 + hash_noise(x, 4, 3) % 5, (172, 170, 145, 70))

    draw_crack(pixels, width, [(18, 14), (22, 24), (20, 33), (28, 42)], (13, 15, 19, 194))
    draw_crack(pixels, width, [(67, 8), (61, 18), (66, 29), (58, 40), (62, 55)], (14, 16, 20, 182))
    draw_crack(pixels, width, [(40, 49), (47, 52), (52, 60)], (12, 12, 15, 164))

    for x in range(9, 27):
        for y in range(47, 55):
            if (x - 16) ** 2 * 0.25 + (y - 51) ** 2 < 18:
                blend_pixel(pixels, width, x, y, (128, 9, 14, 168))
    for x in range(72, 86):
        for y in range(30, 36):
            if (hash_noise(x, y, 17) % 4) != 0:
                blend_pixel(pixels, width, x, y, (112, 8, 15, 118))

    for x in range(width):
        for y in range(height - 10, height):
            blend_pixel(pixels, width, x, y, (6, 8, 12, 64 + (height - y) * 2))

    return pixels


def shot_pixels() -> bytearray:
    width = 64
    height = 24
    pixels = bytearray(width * height * 4)
    for i in range(14):
        x = 10 + i * 3.0
        y = 12 + math.sin(i * 0.9) * 2.2
        radius = 6 - i * 0.18
        color = (19 + i * 2, 24 + i * 2, 30 + i * 2, 86 - i * 2)
        draw_ellipse(pixels, width, x, y, radius * 1.35, radius * 0.48, color)
    draw_ellipse(pixels, width, 43, 12, 15, 4.6, (47, 41, 31, 172))
    draw_ellipse(pixels, width, 48, 12, 13, 4.0, (142, 98, 45, 226))
    draw_ellipse(pixels, width, 53, 12, 9, 3.0, (224, 184, 92, 242))
    draw_ellipse(pixels, width, 57, 12, 4.6, 1.8, (248, 228, 148, 248))
    for i in range(17):
        x = 4 + hash_noise(i, 2, 17) % 38
        y = 6 + hash_noise(i, 9, 23) % 12
        blend_pixel(pixels, width, x, y, (63, 67, 69, 58))
    for i in range(8):
        x = 33 + i * 3
        y = 10 + (i % 3)
        blend_pixel(pixels, width, x, y, (115, 19, 24, 66))
    return pixels


def block_index(blocks: list[tuple[int, int, int, int]], x: int, y: int) -> int:
    for index, (left, top, right, bottom) in enumerate(blocks):
        if left <= x < right and top <= y < bottom:
            return index
    return 0


def is_mortar_or_crack(x: int, y: int) -> bool:
    mortar = (
        y in (21, 22, 42, 43)
        or (x in (29, 30, 62, 63) and y < 22)
        or (x in (46, 47) and 22 <= y < 43)
        or (x in (33, 34, 69, 70) and y >= 43)
    )
    if mortar:
        return True
    return (x + y * 2) % 37 == 0 and y > 10


def draw_crack(pixels: bytearray, width: int, points: list[tuple[int, int]], color: tuple[int, int, int, int]) -> None:
    for start, end in zip(points, points[1:]):
        draw_line(pixels, width, start[0], start[1], end[0], end[1], color)


def draw_line(pixels: bytearray, width: int, x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int, int]) -> None:
    steps = max(abs(x1 - x0), abs(y1 - y0)) + 1
    for step in range(steps):
        t = step / max(steps - 1, 1)
        x = round(x0 + (x1 - x0) * t)
        y = round(y0 + (y1 - y0) * t)
        blend_pixel(pixels, width, x, y, color)
        if step % 3 == 0:
            blend_pixel(pixels, width, x + 1, y, color)


def draw_ellipse(pixels: bytearray, width: int, cx: float, cy: float, rx: float, ry: float, color: tuple[int, int, int, int]) -> None:
    height = len(pixels) // (width * 4)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if x < 0 or y < 0 or x >= width or y >= height:
                continue
            value = ((x - cx) / max(rx, 0.1)) ** 2 + ((y - cy) / max(ry, 0.1)) ** 2
            if value <= 1.0:
                edge = 1.0 - min(1.0, value)
                blend_pixel(pixels, width, x, y, (color[0], color[1], color[2], int(color[3] * (0.45 + edge * 0.55))))


def set_pixel(pixels: bytearray, width: int, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    idx = (y * width + x) * 4
    pixels[idx : idx + 4] = bytes(color)


def blend_pixel(pixels: bytearray, width: int, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    height = len(pixels) // (width * 4)
    if x < 0 or y < 0 or x >= width or y >= height:
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


def hash_noise(x: int, y: int, seed: int) -> int:
    value = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    value = (value ^ (value >> 13)) * 1274126177
    return (value ^ (value >> 16)) & 0x7FFFFFFF


def clamp(value: int) -> int:
    return max(0, min(255, value))


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
