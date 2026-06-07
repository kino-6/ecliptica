from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path
from typing import Callable


ENEMY_IDLE_FRAMES = 8
ENEMY_WALK_FRAMES = 12
ENEMY_ATTACK_FRAMES = 8
BOSS_FRAMES = 8
ENEMY_FRAME = (96, 96)
BOSS_FRAME = (192, 160)
ENEMY_IDLE_OUT = Path("assets/enemy-idle-sheet-8.png")
ENEMY_WALK_OUT = Path("assets/enemy-walk-sheet-12.png")
ENEMY_ATTACK_OUT = Path("assets/enemy-attack-sheet-8.png")
BOSS_OUT = Path("assets/boss-idle-sheet-8.png")

INK = (9, 10, 13, 238)
COAT = (19, 22, 27, 235)
COAT_EDGE = (39, 43, 47, 192)
CRIMSON = (105, 17, 28, 228)
DEEP_CRIMSON = (56, 9, 18, 222)
BONE = (169, 143, 92, 220)
BONE_DARK = (112, 92, 61, 190)
BRASS = (195, 157, 83, 172)
SMEAR = (140, 18, 29, 128)
SHADOW = (8, 9, 12, 130)


def main() -> None:
    write_sheet(ENEMY_IDLE_OUT, ENEMY_FRAME[0], ENEMY_FRAME[1], ENEMY_IDLE_FRAMES, draw_enemy_idle_frame)
    write_sheet(ENEMY_WALK_OUT, ENEMY_FRAME[0], ENEMY_FRAME[1], ENEMY_WALK_FRAMES, draw_enemy_walk_frame)
    write_sheet(ENEMY_ATTACK_OUT, ENEMY_FRAME[0], ENEMY_FRAME[1], ENEMY_ATTACK_FRAMES, draw_enemy_attack_frame)
    write_sheet(BOSS_OUT, BOSS_FRAME[0], BOSS_FRAME[1], BOSS_FRAMES, draw_boss_frame)


def write_sheet(
    path: Path,
    frame_width: int,
    frame_height: int,
    frame_count: int,
    draw_func: Callable[[bytearray, int, int, int, int, int], None],
) -> None:
    width = frame_width * frame_count
    pixels = bytearray(width * frame_height * 4)
    for frame in range(frame_count):
        draw_func(pixels, width, frame * frame_width, frame_width, frame_height, frame)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(encode_png(width, frame_height, pixels))


def draw_enemy_idle_frame(pixels: bytearray, sheet_width: int, x_offset: int, fw: int, fh: int, frame: int) -> None:
    phase = frame / ENEMY_IDLE_FRAMES * math.tau
    draw_cathedral_ghoul(pixels, sheet_width, x_offset, fw, fh, phase, 0.0, 0.0, 0.0)


def draw_enemy_walk_frame(pixels: bytearray, sheet_width: int, x_offset: int, fw: int, fh: int, frame: int) -> None:
    phase = frame / ENEMY_WALK_FRAMES * math.tau
    stride = math.sin(phase)
    draw_cathedral_ghoul(pixels, sheet_width, x_offset, fw, fh, phase, stride, 0.0, 0.0)


def draw_enemy_attack_frame(pixels: bytearray, sheet_width: int, x_offset: int, fw: int, fh: int, frame: int) -> None:
    windup = [-0.45, -0.60, -0.48, 0.10, 0.92, 1.15, 0.58, 0.0][frame]
    smear = [0.0, 0.0, 0.0, 0.24, 1.0, 0.58, 0.0, 0.0][frame]
    crouch = [2.0, 4.0, 3.0, 1.0, -2.0, -1.0, 0.0, 1.0][frame]
    draw_cathedral_ghoul(pixels, sheet_width, x_offset, fw, fh, frame / ENEMY_ATTACK_FRAMES * math.tau, 0.0, windup, smear, crouch)


def draw_cathedral_ghoul(
    pixels: bytearray,
    sheet_width: int,
    x_offset: int,
    fw: int,
    fh: int,
    phase: float,
    stride: float,
    attack_reach: float,
    smear: float,
    crouch: float = 0.0,
) -> None:
    bob = math.sin(phase) * 0.7 + crouch
    cx = fw * 0.5 + attack_reach * 1.2
    cy = fh * 0.58 + bob
    fixed_cx = fw * 0.5
    cloth_sway = math.sin(phase + 0.5) * 1.2 + stride * 1.4

    draw_rotated_ellipse(pixels, sheet_width, x_offset, fixed_cx, cy + 34, 32, 8, 0.0, SHADOW, fw, fh)

    back_cloak = [
        (fixed_cx - 30, cy - 24),
        (fixed_cx - 18, cy - 37),
        (fixed_cx + 18, cy - 37),
        (fixed_cx + 31, cy - 23),
        (fixed_cx + 35, cy + 30),
        (fixed_cx + 22, cy + 43),
        (fixed_cx + 5, cy + 38),
        (fixed_cx - 7, cy + 44),
        (fixed_cx - 24, cy + 40),
        (fixed_cx - 36, cy + 29),
    ]
    draw_polygon(pixels, sheet_width, x_offset, back_cloak, (7, 8, 11, 246), fw, fh)

    hood = [
        (cx - 23, cy - 29),
        (cx - 9, cy - 43),
        (cx + 14, cy - 42),
        (cx + 25, cy - 28),
        (cx + 17, cy - 12),
        (cx - 15, cy - 12),
    ]
    draw_polygon(pixels, sheet_width, x_offset, hood, INK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy + 1, 30, 39, -0.05, COAT, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 12, cy + 8, 15, 33, 0.12, (8, 10, 13, 238), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 10, cy + 11, 15, 31, -0.18, (30, 14, 18, 228), fw, fh)

    crimson_fold = [
        (cx + 5, cy - 12),
        (cx + 18, cy - 8),
        (cx + 14 + cloth_sway, cy + 34),
        (cx + 3 + cloth_sway * 0.5, cy + 40),
        (cx - 2, cy + 1),
    ]
    draw_polygon(pixels, sheet_width, x_offset, crimson_fold, DEEP_CRIMSON, fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx + 9, cy - 5, cx + 8 + cloth_sway, cy + 35, 2, (127, 28, 33, 124), fw, fh)

    for i in range(12):
        tail_x = cx - 28 + i * 5.2 + math.sin(phase + i * 0.7) * 0.9
        tail_y = cy + 15 + (i % 5) * 4
        tail_len = 18 + (i % 4) * 4
        color = (13, 15, 19, 186) if i % 2 else (23, 26, 30, 154)
        draw_limb(pixels, sheet_width, x_offset, tail_x, tail_y, tail_x - 3 + cloth_sway * 0.7, tail_y + tail_len, 2 + (i % 3 == 0), color, fw, fh)

    mask_x = cx + 3 + attack_reach * 0.8
    mask_y = cy - 25 + math.sin(phase + 0.2) * 0.35
    draw_rotated_ellipse(pixels, sheet_width, x_offset, mask_x, mask_y, 9, 7, -0.08, BONE, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, mask_x + 3, mask_y - 1, 5, 3, -0.1, (214, 192, 134, 196), fw, fh)
    draw_circle(pixels, sheet_width, x_offset, mask_x + 3, mask_y - 1, 1, (118, 9, 15, 224), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, mask_x + 6, mask_y + 2, mask_x + 14, mask_y + 4, 1, BONE_DARK, fw, fh)

    arm_sway = stride * 4.0
    draw_limb(pixels, sheet_width, x_offset, cx - 14, cy - 5, cx - 24 - arm_sway * 0.2, cy + 16, 4, COAT_EDGE, fw, fh)
    draw_claw(pixels, sheet_width, x_offset, cx - 25 - arm_sway * 0.2, cy + 18, -1.0, fw, fh)
    reach = max(0.0, attack_reach) * 18.0
    draw_limb(pixels, sheet_width, x_offset, cx + 13, cy - 4, cx + 22 + arm_sway * 0.25 + reach, cy + 14 - reach * 0.18, 4, COAT_EDGE, fw, fh)
    draw_claw(pixels, sheet_width, x_offset, cx + 24 + arm_sway * 0.25 + reach, cy + 16 - reach * 0.18, 1.0, fw, fh)

    if smear > 0.0:
        draw_limb(pixels, sheet_width, x_offset, cx + 19, cy + 3, cx + 48, cy + 20, 6, (30, 12, 16, int(142 * smear)), fw, fh)
        draw_limb(pixels, sheet_width, x_offset, cx + 27, cy + 10, cx + 56, cy + 31, 3, (132, 29, 34, int(96 * smear)), fw, fh)
        draw_limb(pixels, sheet_width, x_offset, cx + 36, cy + 15, cx + 58, cy + 23, 2, (BONE[0], BONE[1], BONE[2], int(142 * smear)), fw, fh)

    for i in range(14):
        angle = -2.5 + i * 0.32 + phase * 0.03
        radius = 20 + (i % 4) * 4
        color = (92, 17, 24, 44) if i % 2 == 0 else (44, 49, 52, 44)
        draw_circle(pixels, sheet_width, x_offset, cx + math.cos(angle) * radius, cy + 5 + math.sin(angle) * radius * 0.58, 1 + (i % 5 == 0), color, fw, fh)

    draw_limb(pixels, sheet_width, x_offset, cx - 8, cy - 17, cx + 12, cy - 18, 1, BRASS, fw, fh)


def draw_claw(pixels: bytearray, sheet_width: int, x_offset: int, cx: float, cy: float, sign: float, fw: int, fh: int) -> None:
    draw_circle(pixels, sheet_width, x_offset, cx, cy, 2, BONE_DARK, fw, fh)
    for i in range(3):
        draw_limb(pixels, sheet_width, x_offset, cx + sign * 1, cy - 1 + i * 2, cx + sign * (7 + i), cy - 4 + i * 2, 1, BONE, fw, fh)


def draw_boss_frame(pixels: bytearray, sheet_width: int, x_offset: int, fw: int, fh: int, frame: int) -> None:
    pulse = math.sin(frame / BOSS_FRAMES * math.tau)
    cx = fw * 0.5
    cy = fh * 0.58 + pulse * 1.0
    sway = math.sin(frame / BOSS_FRAMES * math.tau + 0.7) * 2.0

    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy + 44, 66, 18, 0.0, (7, 8, 10, 172), fw, fh)
    back_robe = [
        (cx - 62, cy - 45),
        (cx - 40, cy - 67),
        (cx + 36, cy - 68),
        (cx + 62, cy - 45),
        (cx + 73, cy + 49),
        (cx + 45, cy + 70),
        (cx + 10, cy + 60),
        (cx - 14, cy + 72),
        (cx - 48, cy + 66),
        (cx - 76, cy + 47),
    ]
    draw_polygon(pixels, sheet_width, x_offset, back_robe, (6, 7, 10, 248), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy + 8, 58, 64, -0.03, COAT, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 31, cy + 14, 25, 52, 0.32, (8, 10, 13, 240), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 35, cy + 13, 25, 52, -0.34, (8, 10, 13, 240), fw, fh)

    crimson_fold = [
        (cx - 16, cy - 33),
        (cx + 21, cy - 22),
        (cx + 16 + sway, cy + 42),
        (cx + 8, cy + 64),
        (cx - 8, cy + 50),
        (cx - 13, cy + 8),
    ]
    draw_polygon(pixels, sheet_width, x_offset, crimson_fold, DEEP_CRIMSON, fw, fh)
    draw_polygon(
        pixels,
        sheet_width,
        x_offset,
        [(cx - 28, cy - 17), (cx - 15, cy - 10), (cx - 20 + sway * 0.3, cy + 45), (cx - 30, cy + 54)],
        (46, 7, 15, 190),
        fw,
        fh,
    )
    draw_polygon(
        pixels,
        sheet_width,
        x_offset,
        [(cx + 20, cy - 10), (cx + 33, cy - 5), (cx + 31 + sway * 0.4, cy + 38), (cx + 21, cy + 52)],
        (82, 10, 20, 174),
        fw,
        fh,
    )
    draw_limb(pixels, sheet_width, x_offset, cx + 7, cy - 15, cx + 4 + sway, cy + 56, 2, (132, 27, 34, 118), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx - 7, cy - 7, cx - 1 + sway * 0.5, cy + 58, 2, (19, 9, 13, 150), fw, fh)
    for tear in range(5):
        tear_x = cx - 18 + tear * 9 + math.sin(frame * 0.4 + tear) * 1.1
        draw_limb(pixels, sheet_width, x_offset, tear_x, cy + 34, tear_x - 3 + sway * 0.25, cy + 62 + (tear % 2) * 7, 2, (104, 15, 27, 116), fw, fh)

    hood = [
        (cx - 35, cy - 47),
        (cx - 16, cy - 67),
        (cx + 18, cy - 67),
        (cx + 37, cy - 47),
        (cx + 26, cy - 25),
        (cx - 25, cy - 25),
    ]
    draw_polygon(pixels, sheet_width, x_offset, hood, INK, fw, fh)
    mask_y = cy - 46 + pulse * 0.35
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 2, mask_y, 18, 11, -0.06, BONE, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 9, mask_y - 1, 8, 4, -0.08, (218, 192, 126, 202), fw, fh)
    draw_circle(pixels, sheet_width, x_offset, cx + 8, mask_y - 1, 2, (122, 11, 18, 230), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx + 13, mask_y + 3, cx + 27, mask_y + 8, 2, BONE_DARK, fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx - 26, mask_y + 17, cx - 6, mask_y + 23, 2, BONE_DARK, fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx + 3, mask_y + 23, cx + 31, mask_y + 18, 2, BRASS, fw, fh)
    for bead in range(6):
        bead_x = cx - 23 + bead * 9
        bead_y = mask_y + 20 + math.sin(frame * 0.5 + bead) * 1.4
        draw_circle(pixels, sheet_width, x_offset, bead_x, bead_y, 2, BRASS if bead % 2 else BONE_DARK, fw, fh)

    for i in range(24):
        tail_x = cx - 58 + i * 5.0 + math.sin(frame * 0.4 + i) * 1.4
        tail_y = cy + 20 + (i % 6) * 5
        color = (13, 16, 19, 168) if i % 2 else (33, 38, 40, 112)
        draw_limb(pixels, sheet_width, x_offset, tail_x, tail_y, tail_x - 4 + sway * 0.7, tail_y + 27 + (i % 4) * 4, 3, color, fw, fh)

    draw_limb(pixels, sheet_width, x_offset, cx - 33, cy - 28, cx - 55, cy - 2, 5, COAT_EDGE, fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx + 33, cy - 28, cx + 55, cy - 2, 5, COAT_EDGE, fw, fh)
    draw_claw(pixels, sheet_width, x_offset, cx - 58, cy + 1, -1.0, fw, fh)
    draw_claw(pixels, sheet_width, x_offset, cx + 58, cy + 1, 1.0, fw, fh)

    for i in range(28):
        angle = -2.7 + i * 0.22 + frame * 0.035
        radius = 55 + (i * 7 % 29)
        color = (96, 18, 27, 74) if i % 3 == 0 else (44, 51, 56, 62)
        draw_circle(pixels, sheet_width, x_offset, cx + math.cos(angle) * radius, cy + 7 + math.sin(angle) * radius * 0.62, 2 + (i % 3), color, fw, fh)


def draw_limb(
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


def draw_polygon(
    pixels: bytearray,
    sheet_width: int,
    x_offset: int,
    points: list[tuple[float, float]],
    color: tuple[int, int, int, int],
    fw: int,
    fh: int,
) -> None:
    min_x = int(min(point[0] for point in points))
    max_x = int(max(point[0] for point in points)) + 1
    min_y = int(min(point[1] for point in points))
    max_y = int(max(point[1] for point in points)) + 1
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            if point_in_polygon(x + 0.5, y + 0.5, points):
                blend_pixel(pixels, sheet_width, x_offset + x, y, color, fw, fh)


def point_in_polygon(x: float, y: float, points: list[tuple[float, float]]) -> bool:
    inside = False
    j = len(points) - 1
    for i, point in enumerate(points):
        xi, yi = point
        xj, yj = points[j]
        intersects = (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-6) + xi
        if intersects:
            inside = not inside
        j = i
    return inside


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
