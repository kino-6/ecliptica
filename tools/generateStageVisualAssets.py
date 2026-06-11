from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


PLATFORM_OUTS = [Path("assets/production/platform-stone-tile.png"), Path("assets/platform-stone-tile.png")]
SHOT_OUTS = [Path("assets/production/player-shot.png"), Path("assets/player-shot.png")]
SHOT_SHEET_OUTS = [Path("assets/production/player-shot-sheet-6.png"), Path("assets/player-shot-sheet-6.png")]
SIGIL_OUTS = [Path("assets/production/sigil-relic.png"), Path("assets/sigil-relic.png")]
GATE_SEALED_OUTS = [Path("assets/production/gate-sealed.png"), Path("assets/gate-sealed.png")]
GATE_OPEN_OUTS = [Path("assets/production/gate-open.png"), Path("assets/gate-open.png")]
TRAINING_DUMMY_OUTS = [Path("assets/production/training-reliquary.png"), Path("assets/training-reliquary.png")]
HIT_SPARK_OUTS = [Path("assets/production/hit-spark-sheet-4.png")]
SHOWCASE_BACKDROP_OUTS = [Path("assets/production/showcase-room-backdrop.png")]
SHOT_FRAME_WIDTH = 160
SHOT_FRAME_HEIGHT = 72
SHOT_FRAME_COUNT = 6
HIT_SPARK_FRAME_WIDTH = 64
HIT_SPARK_FRAME_HEIGHT = 64
HIT_SPARK_FRAME_COUNT = 4


def main() -> None:
    write_all(PLATFORM_OUTS, encode_png(96, 64, platform_pixels()))
    write_all(SHOT_OUTS, encode_png(96, 40, shot_pixels()))
    write_all(SHOT_SHEET_OUTS, encode_png(SHOT_FRAME_WIDTH * SHOT_FRAME_COUNT, SHOT_FRAME_HEIGHT, shot_sheet_pixels()))
    write_all(SIGIL_OUTS, encode_png(48, 64, sigil_pixels()))
    write_all(GATE_SEALED_OUTS, encode_png(96, 160, gate_pixels(opened=False)))
    write_all(GATE_OPEN_OUTS, encode_png(96, 160, gate_pixels(opened=True)))
    write_all(TRAINING_DUMMY_OUTS, encode_png(64, 96, training_reliquary_pixels()))
    write_all(HIT_SPARK_OUTS, encode_png(HIT_SPARK_FRAME_WIDTH * HIT_SPARK_FRAME_COUNT, HIT_SPARK_FRAME_HEIGHT, hit_spark_sheet_pixels()))
    write_all(SHOWCASE_BACKDROP_OUTS, encode_png(620, 420, showcase_backdrop_pixels()))


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
    width = 96
    height = 40
    pixels = bytearray(width * height * 4)
    cy = 20

    for i in range(22):
        x = 8 + i * 2.55
        y = cy + math.sin(i * 0.62) * 4.2 + (hash_noise(i, 3, 11) % 5 - 2)
        rx = 10.5 - i * 0.20
        ry = 5.8 - i * 0.09
        alpha = 118 - i * 2
        draw_ellipse(pixels, width, x, y, rx, ry, (18 + i, 22 + i, 28 + i, alpha))

    for i in range(16):
        x = 6 + hash_noise(i, 2, 17) % 52
        y = 8 + hash_noise(i, 9, 23) % 24
        draw_ellipse(pixels, width, x, y, 3 + (i % 4), 1.5 + (i % 3), (58, 65, 70, 66))

    for i in range(10):
        x = 22 + i * 4.2
        y = cy - 6 + (i % 4) * 3
        draw_ellipse(pixels, width, x, y, 6, 2.0, (126, 16, 24, 78))

    draw_ellipse(pixels, width, 52, cy, 29, 8.2, (44, 38, 30, 190))
    draw_ellipse(pixels, width, 61, cy, 24, 6.5, (137, 91, 39, 228))
    draw_ellipse(pixels, width, 71, cy, 17, 4.8, (224, 179, 77, 244))
    draw_ellipse(pixels, width, 82, cy, 9, 3.0, (251, 226, 137, 250))
    draw_ellipse(pixels, width, 88, cy, 4.2, 1.5, (255, 246, 186, 252))

    for i in range(18):
        x = 58 + hash_noise(i, 5, 31) % 30
        y = 7 + hash_noise(i, 8, 47) % 26
        color = (190, 42, 33, 90) if i % 3 == 0 else (196, 143, 72, 74)
        draw_ellipse(pixels, width, x, y, 1.8 + (i % 2), 1.2, color)

    draw_line(pixels, width, 34, cy - 8, 83, cy - 1, (78, 26, 24, 118))
    draw_line(pixels, width, 36, cy + 7, 78, cy + 2, (30, 36, 42, 132))
    return pixels


def shot_sheet_pixels() -> bytearray:
    sheet = bytearray(SHOT_FRAME_WIDTH * SHOT_FRAME_COUNT * SHOT_FRAME_HEIGHT * 4)
    for frame in range(SHOT_FRAME_COUNT):
        frame_pixels = gunshot_frame_pixels(frame)
        paste_frame(sheet, SHOT_FRAME_WIDTH * SHOT_FRAME_COUNT, frame, frame_pixels, SHOT_FRAME_WIDTH, SHOT_FRAME_HEIGHT)
    return sheet


def hit_spark_sheet_pixels() -> bytearray:
    sheet = bytearray(HIT_SPARK_FRAME_WIDTH * HIT_SPARK_FRAME_COUNT * HIT_SPARK_FRAME_HEIGHT * 4)
    for frame in range(HIT_SPARK_FRAME_COUNT):
        frame_pixels = hit_spark_frame_pixels(frame)
        paste_frame(sheet, HIT_SPARK_FRAME_WIDTH * HIT_SPARK_FRAME_COUNT, frame, frame_pixels, HIT_SPARK_FRAME_WIDTH, HIT_SPARK_FRAME_HEIGHT)
    return sheet


def hit_spark_frame_pixels(frame: int) -> bytearray:
    width = HIT_SPARK_FRAME_WIDTH
    height = HIT_SPARK_FRAME_HEIGHT
    pixels = bytearray(width * height * 4)
    cx = width * 0.5
    cy = height * 0.48
    strength = [1.0, 0.76, 0.42, 0.14][frame]
    radius = 9 + frame * 8

    draw_ellipse(pixels, width, cx, cy, 10 + frame * 3, 5 + frame, (118, 23, 20, int(132 * strength)))
    draw_line(pixels, width, round(cx - radius), round(cy), round(cx + radius * 0.9), round(cy - 3), 2, (247, 210, 126, int(218 * strength)))
    draw_line(pixels, width, round(cx - radius * 0.38), round(cy - radius * 0.42), round(cx + radius * 0.52), round(cy + radius * 0.36), 2, (189, 67, 43, int(176 * strength)))
    draw_line(pixels, width, round(cx - radius * 0.28), round(cy + radius * 0.38), round(cx + radius * 0.56), round(cy - radius * 0.34), 1, (255, 238, 176, int(155 * strength)))
    for i in range(10):
        angle = (i / 10.0) * math.tau + frame * 0.18
        distance = 8 + frame * 5 + (hash_noise(i, frame, 313) % 8)
        x = cx + math.cos(angle) * distance
        y = cy + math.sin(angle) * distance * 0.72
        draw_ellipse(pixels, width, x, y, 2.2 - frame * 0.25, 1.3, (226, 143, 70, int(116 * strength)))
    return pixels


def showcase_backdrop_pixels() -> bytearray:
    width = 620
    height = 420
    pixels = bytearray(width * height * 4)

    for y in range(height):
        for x in range(width):
            depth = y / height
            noise = hash_noise(x, y, 401) % 13 - 6
            r = clamp(int(13 + depth * 12 + noise))
            g = clamp(int(17 + depth * 14 + noise))
            b = clamp(int(23 + depth * 18 + noise))
            set_pixel(pixels, width, x, y, (r, g, b, 235))

    for column_x, column_w, shade in [(60, 34, -8), (206, 28, 2), (386, 32, -4), (544, 38, -10)]:
        for y in range(36, height):
            for x in range(column_x - column_w // 2, column_x + column_w // 2):
                if 0 <= x < width:
                    noise = hash_noise(x, y, 419) % 16 - 8
                    color = (clamp(33 + shade + noise), clamp(38 + shade + noise), clamp(46 + shade + noise), 212)
                    blend_pixel(pixels, width, x, y, color)
        draw_line(pixels, width, column_x - column_w // 2 - 5, 42, column_x + column_w // 2 + 5, 42, 3, (82, 78, 65, 126))

    for arch_x, arch_w, arch_h in [(142, 116, 170), (304, 142, 196), (478, 124, 178)]:
        for y in range(90, 315):
            for x in range(arch_x - arch_w // 2, arch_x + arch_w // 2):
                dx = (x - arch_x) / (arch_w * 0.5)
                dy = (y - 212) / arch_h
                arch = dx * dx + dy * dy
                if arch < 1.0 and y > 114:
                    blend_pixel(pixels, width, x, y, (5, 7, 10, 92))
                elif abs(arch - 1.0) < 0.035 and y > 100:
                    blend_pixel(pixels, width, x, y, (74, 75, 72, 132))

    for i in range(34):
        x = 22 + hash_noise(i, 4, 443) % 560
        y = 56 + hash_noise(i, 7, 443) % 210
        draw_line(pixels, width, x, y, x + (hash_noise(i, 9, 443) % 36 - 18), y + 70 + hash_noise(i, 11, 443) % 62, 1, (13, 17, 20, 86))

    for lamp_x, lamp_y in [(92, 122), (512, 142)]:
        draw_line(pixels, width, lamp_x, lamp_y - 42, lamp_x, lamp_y - 4, 2, (34, 28, 24, 170))
        draw_ellipse(pixels, width, lamp_x, lamp_y, 10, 16, (132, 91, 48, 92))
        draw_ellipse(pixels, width, lamp_x, lamp_y, 4, 8, (240, 182, 99, 115))
        draw_ellipse(pixels, width, lamp_x, lamp_y + 20, 28, 34, (92, 55, 34, 35))

    for x in range(width):
        for y in range(height - 70, height):
            blend_pixel(pixels, width, x, y, (3, 5, 8, 84 + (y - (height - 70))))

    return pixels


def gunshot_frame_pixels(frame: int) -> bytearray:
    width = SHOT_FRAME_WIDTH
    height = SHOT_FRAME_HEIGHT
    pixels = bytearray(width * height * 4)
    cy = height // 2
    progress = frame / max(SHOT_FRAME_COUNT - 1, 1)

    flash_strengths = [1.0, 0.76, 0.28, 0.06, 0.0, 0.0]
    smoke_strengths = [0.10, 0.34, 0.66, 0.86, 0.76, 0.54]
    trail_strengths = [0.58, 0.74, 0.45, 0.20, 0.08, 0.0]
    flash = flash_strengths[frame]
    smoke = smoke_strengths[frame]
    trail = trail_strengths[frame]

    # Rear smoke expands and cools after the first flash; it should read as a burst, not a solid bar.
    for i in range(32):
        drift = i * 2.4 + progress * 18.0
        x = 12 + drift + (hash_noise(i, frame, 31) % 9 - 4)
        y = cy + math.sin(i * 0.7 + frame * 0.8) * (3.4 + frame * 0.75) + (hash_noise(i, 7, frame + 13) % 7 - 3)
        rx = 5.5 + (i % 5) * 1.2 + frame * 1.85
        ry = 3.2 + (i % 4) * 0.7 + frame * 0.86
        alpha = int((80 - i * 1.3) * smoke)
        color_bias = hash_noise(i, frame, 71) % 14
        draw_ellipse(pixels, width, x, y, rx, ry, (30 + color_bias, 36 + color_bias, 42 + color_bias, max(0, alpha)))

    # A short heated pressure wave and ember line carries the bullet direction for two frames.
    if trail > 0:
        for i in range(16):
            x = 42 + i * 5.0 + frame * 7.0
            y = cy + math.sin(i * 0.9) * 2.1
            draw_ellipse(pixels, width, x, y, 5.8 - i * 0.14, 1.7, (105, 58, 35, int(76 * trail)))
            if i % 3 == 0:
                draw_ellipse(pixels, width, x + 5, y - 3, 1.7, 1.0, (226, 139, 65, int(90 * trail)))
        draw_line(pixels, width, 42, cy - 3, 126, cy - 1, 1, (70, 35, 29, int(92 * trail)))
        draw_line(pixels, width, 50, cy + 4, 116, cy + 2, 1, (20, 26, 31, int(84 * trail)))

    # Classic 16-bit readability: a single violent flash, then it collapses into smoke.
    if flash > 0:
        draw_muzzle_bloom(pixels, width, 58 + frame * 6, cy, flash)
        draw_ellipse(pixels, width, 70 + frame * 7, cy, 24 - frame * 3.0, 6.8 - frame * 0.8, (218, 160, 72, int(214 * flash)))
        draw_ellipse(pixels, width, 80 + frame * 7, cy - 1, 14 - frame * 1.8, 4.4, (252, 224, 128, int(230 * flash)))
        draw_ellipse(pixels, width, 90 + frame * 7, cy, 5.2, 2.0, (255, 247, 194, int(238 * flash)))

    for i in range(13):
        spark_life = max(0.0, flash + trail * 0.5 - i * 0.025)
        if spark_life <= 0:
            continue
        x = 73 + hash_noise(i, frame, 101) % 58 + frame * 7
        y = 16 + hash_noise(i, frame, 109) % 38
        draw_ellipse(pixels, width, x, y, 1.8 + i % 2, 1.0, (195, 52 + i * 3, 40, int(84 * spark_life)))
        draw_ellipse(pixels, width, x + 2, y, 1.0, 0.8, (235, 168, 82, int(76 * spark_life)))

    # Smoke should fade out at the tail but still keep a painterly silhouette.
    if frame >= 3:
        for i in range(12):
            x = 31 + hash_noise(i, frame, 137) % 62 + frame * 3
            y = 14 + hash_noise(i, frame, 149) % 40
            draw_ellipse(pixels, width, x, y, 5 + (i % 4), 3 + (i % 3), (24, 30, 36, 64 - frame * 6))

    return pixels


def draw_muzzle_bloom(pixels: bytearray, width: int, cx: float, cy: float, strength: float) -> None:
    alpha = int(170 * strength)
    draw_ellipse(pixels, width, cx - 10, cy, 18, 8, (86, 31, 24, int(alpha * 0.52)))
    draw_ellipse(pixels, width, cx, cy, 22, 7, (208, 133, 55, int(alpha * 0.84)))
    draw_ellipse(pixels, width, cx + 11, cy - 1, 13, 4.2, (255, 228, 149, int(alpha * 0.96)))
    draw_ellipse(pixels, width, cx + 17, cy, 7, 2.4, (255, 240, 162, int(alpha * 0.88)))
    draw_line(pixels, width, round(cx - 15), round(cy - 4), round(cx + 26), round(cy - 1), 1, (242, 190, 91, int(alpha * 0.62)))
    draw_line(pixels, width, round(cx - 9), round(cy + 5), round(cx + 22), round(cy + 2), 1, (132, 48, 34, int(alpha * 0.54)))


def paste_frame(sheet: bytearray, sheet_width: int, frame: int, frame_pixels: bytearray, frame_width: int, frame_height: int) -> None:
    x0 = frame * frame_width
    for y in range(frame_height):
        dst_start = (y * sheet_width + x0) * 4
        src_start = y * frame_width * 4
        sheet[dst_start : dst_start + frame_width * 4] = frame_pixels[src_start : src_start + frame_width * 4]


def write_all(paths: list[Path], data: bytes) -> None:
    for path in paths:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def sigil_pixels() -> bytearray:
    width = 48
    height = 64
    pixels = bytearray(width * height * 4)
    cx = width * 0.5
    cy = height * 0.48

    draw_ellipse(pixels, width, cx, cy + 19, 15, 5, (4, 5, 7, 96))
    draw_ellipse(pixels, width, cx, cy, 18, 24, (26, 7, 11, 148))
    draw_ellipse(pixels, width, cx, cy, 13, 19, (112, 10, 18, 210))
    draw_ellipse(pixels, width, cx, cy, 7, 11, (208, 44, 41, 230))
    draw_ellipse(pixels, width, cx, cy - 2, 3, 5, (250, 166, 104, 214))
    draw_line(pixels, width, 22, 17, 19, 45, 1, (54, 6, 10, 118))
    draw_line(pixels, width, 29, 18, 32, 44, 1, (235, 126, 72, 102))
    for i in range(14):
        angle = i / 14 * math.tau
        radius = 18 + (hash_noise(i, 6, 77) % 4)
        x = cx + math.cos(angle) * radius
        y = cy + math.sin(angle) * radius * 1.25
        draw_ellipse(pixels, width, x, y, 2.1, 3.0, (89, 8, 14, 124))
    for i in range(13):
        x = 8 + i * 3
        y = 11 + hash_noise(i, 2, 8) % 40
        draw_line(pixels, width, x, y, x + 4, y + 7, 2, (188, 132, 62, 112))
    for i in range(8):
        x = 13 + hash_noise(i, 4, 93) % 23
        y = 20 + hash_noise(i, 8, 93) % 28
        draw_ellipse(pixels, width, x, y, 1.8, 2.4, (226, 173, 88, 132))
    return pixels


def gate_pixels(opened: bool) -> bytearray:
    width = 96
    height = 160
    pixels = bytearray(width * height * 4)
    arch_color = (20, 25, 32, 244)
    stone_color = (42, 48, 58, 238)
    inner_color = (8, 9, 13, 238) if not opened else (84, 10, 18, 228)
    glow_color = (112, 14, 24, 124) if not opened else (222, 64, 46, 164)

    for y in range(height):
        for x in range(width):
            dx = x - width * 0.5
            arch = (dx / 44.0) ** 2 + ((y - 82) / 72.0) ** 2
            if y > 48 and arch <= 1.0:
                noise = hash_noise(x, y, 119) % 21 - 10
                set_pixel(pixels, width, x, y, tuple(clamp(c + noise) for c in stone_color[:3]) + (stone_color[3],))
            inner = (dx / 28.0) ** 2 + ((y - 88) / 56.0) ** 2
            if y > 54 and inner <= 1.0:
                blend_pixel(pixels, width, x, y, inner_color)

    for x in range(9, 87):
        blend_pixel(pixels, width, x, 54, (132, 124, 101, 120))
        blend_pixel(pixels, width, x, 55, arch_color)
    for column in [18, 32, 48, 64, 80]:
        draw_line(pixels, width, column, 62, column + (2 if opened else 0), 145, 2, (8, 10, 13, 218))
        draw_line(pixels, width, column + 1, 62, column + 3, 145, 1, (99, 91, 65, 96))
    for y in [84, 112, 138]:
        draw_line(pixels, width, 17, y, 82, y + (3 if opened else 0), 2, (12, 13, 17, 208))
        draw_line(pixels, width, 20, y - 1, 80, y + 2, 1, (118, 101, 62, 92))
    for i in range(28):
        x = 20 + hash_noise(i, 3, 211) % 58
        y = 68 + hash_noise(i, 7, 211) % 72
        draw_ellipse(pixels, width, x, y, 2 + i % 3, 1.6, glow_color)
    if opened:
        draw_ellipse(pixels, width, 48, 96, 20, 50, (172, 28, 30, 92))
        draw_ellipse(pixels, width, 48, 96, 10, 36, (244, 116, 73, 82))
    return pixels


def training_reliquary_pixels() -> bytearray:
    width = 64
    height = 96
    pixels = bytearray(width * height * 4)
    cx = width * 0.5
    draw_ellipse(pixels, width, cx, 87, 22, 6, (4, 5, 7, 120))
    for y in range(24, 83):
        for x in range(13, 51):
            edge = abs(x - cx) / 21
            if edge <= 1.0:
                shade = hash_noise(x, y, 51) % 19 - 9
                color = (clamp(31 + shade), clamp(23 + shade), clamp(24 + shade), 230)
                set_pixel(pixels, width, x, y, color)
    draw_ellipse(pixels, width, cx, 25, 19, 14, (42, 35, 30, 238))
    draw_ellipse(pixels, width, cx, 25, 11, 7, (148, 119, 70, 210))
    draw_ellipse(pixels, width, cx, 25, 4, 3, (210, 174, 104, 220))
    draw_ellipse(pixels, width, cx, 51, 8, 11, (151, 111, 62, 168))
    draw_ellipse(pixels, width, cx, 51, 5, 7, (226, 176, 82, 202))
    draw_ellipse(pixels, width, cx + 9, 36, 3.4, 4.2, (228, 174, 82, 172))
    draw_ellipse(pixels, width, cx - 10, 36, 3.4, 4.2, (228, 174, 82, 172))
    draw_line(pixels, width, 16, 40, 48, 40, 2, (104, 19, 25, 152))
    draw_line(pixels, width, 20, 57, 44, 58, 2, (126, 94, 50, 130))
    draw_line(pixels, width, 15, 66, 50, 63, 1, (15, 12, 14, 170))
    draw_line(pixels, width, 29, 32, 34, 81, 1, (71, 8, 13, 122))
    draw_line(pixels, width, 38, 34, 31, 80, 1, (110, 78, 42, 96))
    draw_line(pixels, width, 24, 30, 20, 78, 2, (7, 8, 11, 190))
    draw_line(pixels, width, 41, 31, 46, 79, 2, (7, 8, 11, 190))
    for i in range(18):
        x = 16 + hash_noise(i, 5, 47) % 32
        y = 36 + hash_noise(i, 9, 47) % 44
        draw_ellipse(pixels, width, x, y, 1.6, 1.6, (142, 22, 24, 94))
    for i in range(10):
        x = 18 + i * 3
        y = 42 + (i % 4) * 10
        draw_ellipse(pixels, width, x, y, 2.0, 2.0, (189, 142, 72, 116))
    for i in range(18):
        x = 10 + i * 3
        y = 84 + (hash_noise(i, 2, 131) % 8)
        draw_ellipse(pixels, width, x, y, 2.2, 1.4, (12 + i % 5, 13 + i % 4, 16 + i % 6, 78))
    for x in range(12, 54, 5):
        for y in range(84, 92):
            if (x - cx) ** 2 * 0.05 + (y - 88) ** 2 < 26:
                set_pixel(pixels, width, x, y, (10 + x % 9, 11 + y % 7, 14 + (x + y) % 8, 82 + (x * y) % 24))
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


def draw_line(
    pixels: bytearray,
    width: int,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    radius_or_color: int | tuple[int, int, int, int],
    color: tuple[int, int, int, int] | None = None,
) -> None:
    radius = 1 if color is None else int(radius_or_color)
    draw_color = radius_or_color if color is None else color
    steps = max(abs(x1 - x0), abs(y1 - y0)) + 1
    for step in range(steps):
        t = step / max(steps - 1, 1)
        x = round(x0 + (x1 - x0) * t)
        y = round(y0 + (y1 - y0) * t)
        draw_ellipse(pixels, width, x, y, radius, radius, draw_color)
        if step % 3 == 0:
            draw_ellipse(pixels, width, x + 1, y, radius, radius, draw_color)


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
