from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


FRAME_WIDTH = 192
FRAME_HEIGHT = 384
IDLE_FRAME_COUNT = 10
ATTACK_BODY_FRAME_COUNT = 8
COMBO_STEP_COUNT = 3
SHOOT_FRAME_COUNT = 8
GUTTER = 8

IDLE_IN = Path("assets/player-idle-sheet-10.png")
ATTACK_OUT = Path("assets/player-attack-combo-sheet-24.png")
SHOOT_OUT = Path("assets/player-shoot-sheet-8.png")


def main() -> None:
    idle_width, idle_height, idle_pixels = decode_png(IDLE_IN.read_bytes())
    if idle_width != FRAME_WIDTH * IDLE_FRAME_COUNT or idle_height != FRAME_HEIGHT:
        raise ValueError("Idle sheet does not match the 192x384x10 player contract")

    idle_frames = [
        crop_frame(idle_pixels, idle_width, frame * FRAME_WIDTH, FRAME_WIDTH, FRAME_HEIGHT)
        for frame in range(IDLE_FRAME_COUNT)
    ]

    attack_pixels = bytearray(FRAME_WIDTH * COMBO_STEP_COUNT * ATTACK_BODY_FRAME_COUNT * FRAME_HEIGHT * 4)
    for step in range(COMBO_STEP_COUNT):
        for local_frame in range(ATTACK_BODY_FRAME_COUNT):
            sheet_frame = step * ATTACK_BODY_FRAME_COUNT + local_frame
            source = idle_frames[(2 + local_frame) % IDLE_FRAME_COUNT]
            action = make_attack_frame(source, step, local_frame)
            paste_frame(attack_pixels, FRAME_WIDTH * COMBO_STEP_COUNT * ATTACK_BODY_FRAME_COUNT, sheet_frame, action)

    shoot_pixels = bytearray(FRAME_WIDTH * SHOOT_FRAME_COUNT * FRAME_HEIGHT * 4)
    for frame in range(SHOOT_FRAME_COUNT):
        progress = frame / (SHOOT_FRAME_COUNT - 1)
        source = idle_frames[(1 + frame) % IDLE_FRAME_COUNT]
        action = make_shoot_frame(source, progress)
        paste_frame(shoot_pixels, FRAME_WIDTH * SHOOT_FRAME_COUNT, frame, action)

    ATTACK_OUT.write_bytes(encode_png(FRAME_WIDTH * COMBO_STEP_COUNT * ATTACK_BODY_FRAME_COUNT, FRAME_HEIGHT, attack_pixels))
    SHOOT_OUT.write_bytes(encode_png(FRAME_WIDTH * SHOOT_FRAME_COUNT, FRAME_HEIGHT, shoot_pixels))


def make_attack_frame(source: bytearray, step: int, local_frame: int) -> bytearray:
    timing = [0.00, 0.05, 0.12, 0.15, 0.68, 1.00, 0.88, 0.72][local_frame]
    windup = 1.0 if local_frame in [1, 2, 3] else max(0.0, 1.0 - timing)
    snap = 1.0 if local_frame in [4, 5] else math.sin(min(timing * 1.2, 1.0) * math.pi)
    impact = 1.0 if local_frame == 5 else 0.0
    follow = 1.0 if local_frame >= 6 else 0.0
    step_biases = [
        {"lean": 14.0, "shear": 9.0, "lift": -1.0, "start": -1.28, "end": 0.28},
        {"lean": 18.0, "shear": 12.0, "lift": -5.0, "start": -1.68, "end": 0.12},
        {"lean": 22.0, "shear": 14.0, "lift": -8.0, "start": -2.02, "end": -0.06},
    ][step]

    held_weight = 1.0 if local_frame == 3 else 0.0
    lean = -9.0 * windup + step_biases["lean"] * timing + impact * 9.0 + follow * 3.0
    shear = -6.0 * windup + (timing - 0.32) * step_biases["shear"] + impact * 5.0
    upper_lift = step_biases["lift"] * (windup * 0.8 + impact * 0.35)
    lean -= held_weight * 2.0
    upper_lift -= held_weight * 1.5
    dest = warp_body(source, lean, upper_lift, shear)

    clear_gutters(dest)
    return dest


def make_shoot_frame(source: bytearray, progress: float) -> bytearray:
    settle = math.sin(progress * math.pi)
    recoil = math.sin(min(progress * 1.8, 1.0) * math.pi)
    cooldown = progress
    lean = 4.0 + settle * 3.0 - recoil * 5.5 - cooldown * 2.5
    dest = warp_body(source, lean, -2.5 * settle, -3.0 * recoil)

    shoulder_x = 105 + settle * 3
    shoulder_y = 151 - settle * 2 + cooldown * 4
    hand_x = 154 + settle * 8 - recoil * 5 - cooldown * 10
    hand_y = 144 - recoil * 3 + cooldown * 8
    muzzle_x = hand_x + 20
    muzzle_y = hand_y - 1

    draw_line(dest, shoulder_x, shoulder_y, hand_x, hand_y, 9, (17, 15, 16, 218))
    draw_line(dest, shoulder_x + 2, shoulder_y - 1, hand_x, hand_y, 5, (77, 55, 45, 208))
    draw_line(dest, hand_x - 2, hand_y, muzzle_x, muzzle_y, 5, (19, 21, 23, 238))
    draw_line(dest, hand_x + 1, hand_y - 2, muzzle_x + 4, muzzle_y - 2, 2, (145, 137, 104, 190))

    flash = max(0.0, 1.0 - abs(progress - 0.32) * 5.0)
    if flash > 0:
        draw_rotated_ellipse(dest, muzzle_x + 12, muzzle_y, 13, 4, 0.0, (206, 167, 92, int(140 * flash)))
        draw_rotated_ellipse(dest, muzzle_x + 18, muzzle_y - 1, 8, 3, 0.0, (223, 213, 170, int(110 * flash)))
        draw_circle(dest, muzzle_x + 22, muzzle_y + 1, 3, (105, 29, 26, int(105 * flash)))

    smoke = min(1.0, progress * 1.4)
    for i in range(9):
        drift = i * 5 + progress * 18
        draw_circle(dest, muzzle_x + 18 + drift, muzzle_y - 8 + math.sin(i + progress * 5) * 5, 3 + i % 3, (54, 63, 67, int((54 + progress * 38) * smoke)))

    draw_cloth_pull(dest, 1, progress * 0.5)
    clear_gutters(dest)
    return dest


def warp_body(source: bytearray, upper_shift: float, upper_y: float, shear: float) -> bytearray:
    dest = bytearray(FRAME_WIDTH * FRAME_HEIGHT * 4)
    for y in range(FRAME_HEIGHT):
        upper_weight = clamp((286 - y) / 170, 0.0, 1.0)
        foot_weight = clamp((y - 286) / 52, 0.0, 1.0)
        x_shift = upper_shift * upper_weight + upper_shift * 0.12 * foot_weight
        x_shift += shear * upper_weight * ((210 - y) / 190)
        y_shift = upper_y * upper_weight
        for x in range(FRAME_WIDTH):
            idx = (y * FRAME_WIDTH + x) * 4
            alpha = source[idx + 3]
            if alpha <= 8:
                continue
            nx = int(round(x + x_shift))
            ny = int(round(y + y_shift))
            if nx < GUTTER or nx >= FRAME_WIDTH - GUTTER or ny < GUTTER or ny >= FRAME_HEIGHT - GUTTER:
                continue
            color = (source[idx], source[idx + 1], source[idx + 2], alpha)
            blend_pixel(dest, nx, ny, color)
            if alpha > 160 and upper_weight > 0.45:
                blend_pixel(dest, nx - 1, ny, color)
                blend_pixel(dest, nx, ny + 1, color)
    return dest


def draw_cloth_pull(pixels: bytearray, step: int, progress: float) -> None:
    wave = math.sin(progress * math.pi)
    base_x = 68 - step * 2 - wave * 7
    base_y = 166 + step * 4
    for strand in range(4):
        x0 = base_x - strand * 6
        y0 = base_y + strand * 19
        x1 = x0 - 16 - wave * (8 + step * 2)
        y1 = y0 + 35 + strand * 7
        draw_line(pixels, x0, y0, x1, y1, 5 - min(strand, 3), (71, 19, 23, 126))
        draw_line(pixels, x0 + 2, y0, x1 + 2, y1, 2, (126, 78, 49, 78))


def crop_frame(pixels: bytearray, sheet_width: int, x0: int, width: int, height: int) -> bytearray:
    frame = bytearray(width * height * 4)
    for y in range(height):
        src_start = (y * sheet_width + x0) * 4
        dst_start = y * width * 4
        frame[dst_start : dst_start + width * 4] = pixels[src_start : src_start + width * 4]
    return frame


def paste_frame(sheet: bytearray, sheet_width: int, frame: int, frame_pixels: bytearray) -> None:
    x0 = frame * FRAME_WIDTH
    for y in range(FRAME_HEIGHT):
        dst_start = (y * sheet_width + x0) * 4
        src_start = y * FRAME_WIDTH * 4
        sheet[dst_start : dst_start + FRAME_WIDTH * 4] = frame_pixels[src_start : src_start + FRAME_WIDTH * 4]


def draw_arc(
    pixels: bytearray,
    cx: float,
    cy: float,
    radius: float,
    start: float,
    end: float,
    thickness: int,
    color: tuple[int, int, int, int],
) -> None:
    for i in range(48):
        t = i / 47
        angle = start + (end - start) * t
        draw_circle(pixels, cx + math.cos(angle) * radius, cy + math.sin(angle) * radius, thickness, color)


def draw_line(
    pixels: bytearray,
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
        draw_circle(pixels, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, radius, color)


def draw_circle(pixels: bytearray, cx: float, cy: float, radius: int, color: tuple[int, int, int, int]) -> None:
    for y in range(int(cy - radius), int(cy + radius) + 1):
        for x in range(int(cx - radius), int(cx + radius) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius**2:
                blend_pixel(pixels, x, y, color)


def draw_rotated_ellipse(
    pixels: bytearray,
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
                blend_pixel(pixels, x, y, color)


def blend_pixel(pixels: bytearray, x: float, y: float, color: tuple[int, int, int, int]) -> None:
    ix = int(round(x))
    iy = int(round(y))
    if ix < GUTTER or ix >= FRAME_WIDTH - GUTTER or iy < GUTTER or iy >= FRAME_HEIGHT - GUTTER:
        return
    idx = (iy * FRAME_WIDTH + ix) * 4
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


def clear_gutters(pixels: bytearray) -> None:
    for y in range(FRAME_HEIGHT):
        for x in range(FRAME_WIDTH):
            if x < GUTTER or x >= FRAME_WIDTH - GUTTER or y < GUTTER or y >= FRAME_HEIGHT - GUTTER:
                idx = (y * FRAME_WIDTH + x) * 4
                pixels[idx : idx + 4] = b"\x00\x00\x00\x00"


def decode_png(buffer: bytes) -> tuple[int, int, bytearray]:
    if buffer[1:4] != b"PNG":
        raise ValueError("Expected PNG")
    offset = 8
    width = 0
    height = 0
    idat_parts: list[bytes] = []

    while offset < len(buffer):
        length = struct.unpack(">I", buffer[offset : offset + 4])[0]
        kind = buffer[offset + 4 : offset + 8]
        data = buffer[offset + 8 : offset + 8 + length]
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", data)
            if bit_depth != 8 or color_type != 6:
                raise ValueError("Only 8-bit RGBA PNG files are supported")
        elif kind == b"IDAT":
            idat_parts.append(data)
        elif kind == b"IEND":
            break
        offset += length + 12

    inflated = zlib.decompress(b"".join(idat_parts))
    stride = width * 4
    pixels = bytearray(stride * height)
    source = 0
    for y in range(height):
        filter_type = inflated[source]
        source += 1
        row = inflated[source : source + stride]
        source += stride
        previous_start = (y - 1) * stride if y > 0 else None
        out_start = y * stride
        for x in range(stride):
            left = pixels[out_start + x - 4] if x >= 4 else 0
            up = pixels[previous_start + x] if previous_start is not None else 0
            up_left = pixels[previous_start + x - 4] if previous_start is not None and x >= 4 else 0
            if filter_type == 0:
                value = row[x]
            elif filter_type == 1:
                value = row[x] + left
            elif filter_type == 2:
                value = row[x] + up
            elif filter_type == 3:
                value = row[x] + ((left + up) // 2)
            elif filter_type == 4:
                value = row[x] + paeth(left, up, up_left)
            else:
                raise ValueError(f"Unsupported PNG filter {filter_type}")
            pixels[out_start + x] = value & 0xFF
    return width, height, pixels


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


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


if __name__ == "__main__":
    main()
