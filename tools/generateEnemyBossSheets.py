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
    bob = math.sin(phase) * 1.5 + crouch
    cx = fw * 0.5 + attack_reach * 4.0
    cy = fh * 0.62 + bob
    shoulder_x = cx - 3.0
    shoulder_y = cy - 24.0

    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 2, cy + 27, 30, 7, 0.0, SHADOW, fw, fh)

    rear_leg = stride * -7.5
    front_leg = stride * 7.5
    draw_limb(pixels, sheet_width, x_offset, cx - 10, cy + 14, cx - 18 + rear_leg, cy + 30, 5, COAT_EDGE, fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx + 6, cy + 13, cx + 12 + front_leg, cy + 30, 5, INK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 21 + rear_leg, cy + 32, 8, 3, -0.2, BONE_DARK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 15 + front_leg, cy + 32, 8, 3, 0.1, BONE_DARK, fw, fh)

    coat_points = [
        (cx - 20, cy - 22),
        (cx + 14, cy - 22),
        (cx + 24 + stride * 2, cy + 21),
        (cx + 8, cy + 34),
        (cx - 28 - stride * 2, cy + 24),
    ]
    draw_polygon(pixels, sheet_width, x_offset, coat_points, COAT, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 4, cy - 5, 23, 31, -0.08, COAT, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 4, cy + 1, 15, 26, -0.22, CRIMSON, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 11, cy - 5, 12, 24, 0.24, INK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx + 10, cy - 11, 9, 18, -0.34, (124, 22, 31, 198), fw, fh)

    for i in range(8):
        tail_x = cx - 24 + i * 6 + math.sin(phase + i) * 1.5
        tail_y = cy + 15 + (i % 3) * 4
        draw_limb(pixels, sheet_width, x_offset, tail_x, tail_y, tail_x - 6 + stride * 2, tail_y + 18, 2, COAT_EDGE, fw, fh)

    head_x = shoulder_x - 2 + attack_reach * 2.0
    head_y = shoulder_y - 10 + math.sin(phase + 0.6) * 0.8
    draw_rotated_ellipse(pixels, sheet_width, x_offset, head_x, head_y, 15, 10, -0.2, INK, fw, fh)
    draw_rotated_ellipse(pixels, sheet_width, x_offset, head_x + 4, head_y - 1, 10, 7, -0.18, BONE, fw, fh)
    draw_limb(pixels, sheet_width, x_offset, head_x + 11, head_y, head_x + 25, head_y - 3, 3, BONE_DARK, fw, fh)
    draw_circle(pixels, sheet_width, x_offset, head_x + 8, head_y - 2, 2, (92, 8, 15, 220), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, head_x - 7, head_y - 7, head_x - 21, head_y - 17, 3, COAT_EDGE, fw, fh)
    draw_limb(pixels, sheet_width, x_offset, head_x + 8, head_y - 8, head_x + 17, head_y - 20, 3, COAT_EDGE, fw, fh)

    arm_swing = stride * 5.0
    reach = attack_reach * 24.0
    draw_limb(pixels, sheet_width, x_offset, shoulder_x - 11, shoulder_y + 5, shoulder_x - 28 - arm_swing, shoulder_y + 20, 5, COAT_EDGE, fw, fh)
    draw_claw(pixels, sheet_width, x_offset, shoulder_x - 30 - arm_swing, shoulder_y + 22, -1.0, fw, fh)
    draw_limb(pixels, sheet_width, x_offset, shoulder_x + 10, shoulder_y + 3, shoulder_x + 28 + arm_swing + reach, shoulder_y + 13 - abs(attack_reach) * 5, 5, COAT_EDGE, fw, fh)
    draw_claw(pixels, sheet_width, x_offset, shoulder_x + 31 + arm_swing + reach, shoulder_y + 14 - abs(attack_reach) * 5, 1.0, fw, fh)

    if smear > 0.0:
        draw_limb(pixels, sheet_width, x_offset, shoulder_x + 21, shoulder_y + 11, shoulder_x + 58, shoulder_y + 3, 7, (SMEAR[0], SMEAR[1], SMEAR[2], int(SMEAR[3] * smear)), fw, fh)
        draw_limb(pixels, sheet_width, x_offset, shoulder_x + 30, shoulder_y + 19, shoulder_x + 69, shoulder_y + 13, 4, (BONE[0], BONE[1], BONE[2], int(170 * smear)), fw, fh)

    for i in range(20):
        angle = -2.5 + i * 0.28 + phase * 0.05
        radius = 23 + (i % 4) * 4
        color = (116, 16, 25, 64) if i % 2 == 0 else (53, 58, 61, 54)
        draw_circle(
            pixels,
            sheet_width,
            x_offset,
            cx + math.cos(angle) * radius,
            cy - 7 + math.sin(angle) * radius * 0.72,
            1 + (i % 3 == 0),
            color,
            fw,
            fh,
        )

    draw_limb(pixels, sheet_width, x_offset, cx - 7, cy - 18, cx + 13, cy - 20, 2, BRASS, fw, fh)
    draw_circle(pixels, sheet_width, x_offset, cx + 16, cy - 21, 3, BRASS, fw, fh)


def draw_claw(pixels: bytearray, sheet_width: int, x_offset: int, cx: float, cy: float, sign: float, fw: int, fh: int) -> None:
    draw_circle(pixels, sheet_width, x_offset, cx, cy, 4, BONE_DARK, fw, fh)
    for i in range(3):
        draw_limb(pixels, sheet_width, x_offset, cx + sign * 2, cy - 2 + i * 3, cx + sign * (11 + i * 2), cy - 6 + i * 2, 2, BONE, fw, fh)


def draw_boss_frame(pixels: bytearray, sheet_width: int, x_offset: int, fw: int, fh: int, frame: int) -> None:
    pulse = math.sin(frame / BOSS_FRAMES * math.tau)
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
    draw_rotated_ellipse(pixels, sheet_width, x_offset, cx - 3, cy - 43, 18, 11, -0.1, BONE, fw, fh)

    draw_limb(pixels, sheet_width, x_offset, cx - 25, cy - 62, cx - 62, cy - 91, 5, (32, 35, 36, 225), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx + 25, cy - 62, cx + 62, cy - 91, 5, (32, 35, 36, 225), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx - 38, cy - 54, cx - 78, cy - 65, 4, (92, 18, 26, 164), fw, fh)
    draw_limb(pixels, sheet_width, x_offset, cx + 38, cy - 54, cx + 78, cy - 65, 4, (92, 18, 26, 164), fw, fh)

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
