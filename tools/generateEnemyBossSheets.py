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
    bob = math.sin(phase) * 1.2 + crouch
    cx = fw * 0.5 + attack_reach * 3.0
    cy = fh * 0.60 + bob
    shoulder_x = cx - 1.0
    shoulder_y = cy - 20.0

    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 1, cy + 31, 34, 8, 0.0, SHADOW, fw, fh)

    fixed_cx = fw * 0.5
    back_cloak_points = [
        (fixed_cx - 25, cy - 25),
        (fixed_cx + 25, cy - 25),
        (fixed_cx + 34, cy + 15),
        (fixed_cx + 29, cy + 38),
        (fixed_cx + 10, cy + 34),
        (fixed_cx - 5, cy + 43),
        (fixed_cx - 22, cy + 37),
        (fixed_cx - 35, cy + 14),
    ]
    draw_polygon(pixels, sheet_width, x_offset, back_cloak_points, (10, 12, 16, 238), fw, fh)

    mantle_points = [
        (cx - 25, cy - 24),
        (cx + 25, cy - 24),
        (cx + 36, cy + 17),
        (cx + 26, cy + 43),
        (cx + 3, cy + 41),
        (cx - 13, cy + 45),
        (cx - 31, cy + 40),
        (cx - 38, cy + 16),
    ]
    draw_polygon(pixels, sheet_width, x_offset, mantle_points, (13, 16, 20, 236), fw, fh)

    rear_leg = stride * -8.0
    front_leg = stride * 8.0
    draw_limb(pixels, sheet_width, x_offset, cx - 10, cy + 20, cx - 19 + rear_leg, cy + 36, 5, COAT_EDGE, fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx + 7, cy + 20, cx + 15 + front_leg, cy + 36, 5, INK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 21 + rear_leg, cy + 37, 8, 3, -0.2, BONE_DARK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 17 + front_leg, cy + 37, 8, 3, 0.1, BONE_DARK, fw, fh)

    cloak_points = [
        (cx - 27, cy - 17),
        (cx + 24, cy - 18),
        (cx + 31 + stride * 2, cy + 20),
        (cx + 20, cy + 39),
        (cx + 5, cy + 35),
        (cx - 7, cy + 42),
        (cx - 22, cy + 37),
        (cx - 34 - stride * 2, cy + 21),
    ]
    draw_polygon(pixels, sheet_width, x_offset, cloak_points, INK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 2, cy + 4, 29, 38, -0.06, COAT, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 5, cy + 11, 18, 32, -0.17, DEEP_CRIMSON, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 13, cy + 6, 14, 30, 0.16, INK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 16, cy - 2, 10, 22, -0.28, CRIMSON, fw, fh)

    for i in range(10):
        tail_x = cx - 31 + i * 7 + math.sin(phase + i) * 1.1
        tail_y = cy + 17 + (i % 4) * 4
        draw_limb(pixels, sheet_width, x_offset, tail_x, tail_y, tail_x - 4 + stride * 1.2, tail_y + 20, 3, (24, 27, 31, 178), fw, fh)

    head_x = shoulder_x - 1 + attack_reach * 1.5
    head_y = shoulder_y - 6 + math.sin(phase + 0.6) * 0.7
    hood_points = [
        (head_x - 21, head_y - 4),
        (head_x - 10, head_y - 17),
        (head_x + 14, head_y - 16),
        (head_x + 25, head_y - 2),
        (head_x + 17, head_y + 13),
        (head_x - 15, head_y + 14),
    ]
    draw_polygon(pixels, sheet_width, x_offset, hood_points, INK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, head_x + 2, head_y, 17, 13, -0.12, COAT, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, head_x + 4, head_y + 1, 13, 9, -0.14, BONE, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, head_x + 7, head_y, 8, 5, -0.12, (206, 184, 126, 204), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, head_x + 9, head_y + 2, head_x + 23, head_y + 4, 3, BONE_DARK, fw, fh)
    draw_circle(pixels, sheet_width, x_offset, head_x + 8, head_y - 2, 2, (126, 11, 18, 230), fw, fh)

    arm_swing = stride * 5.0
    reach = attack_reach * 24.0
    draw_limb(pixels, sheet_width, x_offset, shoulder_x - 15, shoulder_y + 8, shoulder_x - 32 - arm_swing, shoulder_y + 23, 6, COAT_EDGE, fw, fh)
    draw_claw(pixels, sheet_width, x_offset, shoulder_x - 35 - arm_swing, shoulder_y + 25, -1.0, fw, fh)
    draw_limb(pixels, sheet_width, x_offset, shoulder_x + 14, shoulder_y + 5, shoulder_x + 31 + arm_swing + reach, shoulder_y + 15 - abs(attack_reach) * 4, 6, COAT_EDGE, fw, fh)
    draw_claw(pixels, sheet_width, x_offset, shoulder_x + 34 + arm_swing + reach, shoulder_y + 17 - abs(attack_reach) * 4, 1.0, fw, fh)

    if smear > 0.0:
        draw_limb(pixels, sheet_width, x_offset, shoulder_x + 23, shoulder_y + 12, shoulder_x + 62, shoulder_y + 6, 7, (SMEAR[0], SMEAR[1], SMEAR[2], int(SMEAR[3] * smear)), fw, fh)
        draw_limb(pixels, sheet_width, x_offset, shoulder_x + 31, shoulder_y + 21, shoulder_x + 72, shoulder_y + 16, 4, (BONE[0], BONE[1], BONE[2], int(170 * smear)), fw, fh)

    for i in range(18):
        angle = -2.5 + i * 0.28 + phase * 0.04
        radius = 22 + (i % 4) * 4
        color = (106, 15, 24, 58) if i % 2 == 0 else (42, 48, 52, 46)
        draw_circle(
            pixels,
            sheet_width,
            x_offset,
            cx + math.cos(angle) * radius,
            cy - 4 + math.sin(angle) * radius * 0.60,
            1 + (i % 3 == 0),
            color,
            fw,
            fh,
        )

    draw_limb(pixels, sheet_width, x_offset, cx - 10, cy - 14, cx + 14, cy - 15, 2, BRASS, fw, fh)
    draw_circle(pixels, sheet_width, x_offset, cx + 18, cy - 16, 3, BRASS, fw, fh)


def draw_claw(pixels: bytearray, sheet_width: int, x_offset: int, cx: float, cy: float, sign: float, fw: int, fh: int) -> None:
    draw_circle(pixels, sheet_width, x_offset, cx, cy, 4, BONE_DARK, fw, fh)
    for i in range(3):
        draw_limb(pixels, sheet_width, x_offset, cx + sign * 2, cy - 2 + i * 3, cx + sign * (11 + i * 2), cy - 6 + i * 2, 2, BONE, fw, fh)


def draw_boss_frame(pixels: bytearray, sheet_width: int, x_offset: int, fw: int, fh: int, frame: int) -> None:
    pulse = math.sin(frame / BOSS_FRAMES * math.tau)
    cx = fw * 0.5
    cy = fh * 0.58 + pulse * 1.6

    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy + 39, 66, 18, 0.0, (10, 11, 13, 160), fw, fh)
    robe_points = [
        (cx - 55, cy - 39),
        (cx - 35, cy - 58),
        (cx + 34, cy - 59),
        (cx + 58, cy - 37),
        (cx + 70, cy + 51),
        (cx + 38, cy + 68),
        (cx + 12, cy + 58),
        (cx - 15, cy + 70),
        (cx - 43, cy + 58),
        (cx - 72, cy + 49),
    ]
    draw_polygon(pixels, sheet_width, x_offset, robe_points, INK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy + 8, 58, 63, -0.04, (22, 14, 19, 244), fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 12, cy + 1, 42, 54, 0.08, DEEP_CRIMSON, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 20, cy - 5, 26, 48, -0.22, CRIMSON, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 42, cy + 10, 22, 50, 0.42, COAT, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 47, cy + 8, 21, 48, -0.46, COAT, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx, cy - 44, 35, 25, 0.0, INK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 2, cy - 39, 25, 15, -0.08, BONE, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 13, cy - 43, 12, 7, 0.0, (210, 181, 112, 214), fw, fh)

    draw_limb(pixels, sheet_width, x_offset, cx - 31, cy - 49, cx - 64, cy - 47, 5, (31, 35, 37, 218), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx + 31, cy - 49, cx + 64, cy - 47, 5, (31, 35, 37, 218), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx - 45, cy - 41, cx - 83, cy - 40, 5, (92, 18, 26, 176), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx + 45, cy - 41, cx + 83, cy - 40, 5, (92, 18, 26, 176), fw, fh)

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
