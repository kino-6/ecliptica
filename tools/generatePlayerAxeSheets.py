from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

from attack_motion_contract import ATTACK_MOTION_POSES


FRAME_WIDTH = 192
FRAME_HEIGHT = 384
IDLE_FRAME_COUNT = 10
WALK_FRAME_COUNT = 24
SHOOT_FRAME_COUNT = 8
ATTACK_BODY_FRAME_COUNT = 8
COMBO_STEP_COUNT = 3
GUTTER = 8

SOURCE_KEY = Path("assets/source/player-axe-source-key.png")
SOURCE_ALPHA = Path("assets/source/player-axe-source.png")
IDLE_OUTS = [Path("assets/production/player-axe-idle-sheet-10.png"), Path("assets/player-axe-idle-sheet-10.png")]
WALK_OUTS = [Path("assets/production/player-axe-walk-sheet-24.png"), Path("assets/player-axe-walk-sheet-24.png")]
SHOOT_OUTS = [Path("assets/production/player-axe-shoot-sheet-8.png"), Path("assets/player-axe-shoot-sheet-8.png")]
ATTACK_OUTS = [Path("assets/production/player-axe-attack-combo-sheet-24.png"), Path("assets/player-axe-attack-combo-sheet-24.png")]


def main() -> None:
    source_width, source_height, source_pixels = decode_png(SOURCE_KEY.read_bytes())
    keyed = chroma_key_green(source_pixels, source_width, source_height)
    bounds = opaque_bounds(keyed, source_width, source_height)
    cropped = crop_region(keyed, source_width, bounds)
    crop_width = bounds[2] - bounds[0] + 1
    crop_height = bounds[3] - bounds[1] + 1
    axe = resize_to_width(cropped, crop_width, crop_height, 166)
    attack_axe = resize_to_width(cropped, crop_width, crop_height, 188)
    SOURCE_ALPHA.write_bytes(encode_png(crop_width, crop_height, cropped))

    write_sheet_all(IDLE_OUTS, [make_idle_frame(axe, i) for i in range(IDLE_FRAME_COUNT)])
    write_sheet_all(WALK_OUTS, [make_walk_frame(axe, i) for i in range(WALK_FRAME_COUNT)])
    write_sheet_all(SHOOT_OUTS, [make_shoot_frame(axe, i) for i in range(SHOOT_FRAME_COUNT)])

    attack_frames: list[bytearray] = []
    for step in range(COMBO_STEP_COUNT):
        for local_frame in range(ATTACK_BODY_FRAME_COUNT):
            attack_frames.append(make_attack_frame(attack_axe, step, local_frame))
    write_sheet_all(ATTACK_OUTS, attack_frames)


def make_idle_frame(axe: Sprite, frame: int) -> bytearray:
    pixels = blank_frame()
    sway = math.sin(frame / IDLE_FRAME_COUNT * math.tau)
    draw_axe(pixels, axe, 104.0, 162.0 + sway * 0.7, math.radians(-2.0 + sway * 1.2), 1.0)
    return pixels


def make_walk_frame(axe: Sprite, frame: int) -> bytearray:
    pixels = blank_frame()
    cycle = frame / WALK_FRAME_COUNT * math.tau
    bob = math.sin(cycle)
    counter = math.sin(cycle + math.pi * 0.42)
    draw_axe(pixels, axe, 104.0 + counter * 1.3, 163.0 + bob * 1.4, math.radians(-2.0 + counter * 2.0), 0.99)
    return pixels


def make_shoot_frame(axe: Sprite, frame: int) -> bytearray:
    pixels = blank_frame()
    progress = frame / max(SHOOT_FRAME_COUNT - 1, 1)
    settle = math.sin(progress * math.pi)
    draw_axe(pixels, axe, 95.0 - settle * 4.0, 176.0 + settle * 5.0, math.radians(18.0 + settle * 4.0), 0.94)
    return pixels


def make_attack_frame(axe: Sprite, step: int, local_frame: int) -> bytearray:
    pixels = blank_frame()
    x, y, angle, scale = ATTACK_MOTION_POSES[step][local_frame]["axe"]

    if local_frame == 4:
        draw_motion_wake(pixels, x + 16.0, y - 10.0, step, local_frame)
        draw_axe(pixels, axe, x - 20.0, y - 10.0, math.radians(angle - 54.0), scale * 0.96, 52, 0.31, 0.58)
        draw_axe(pixels, axe, x - 9.0, y - 5.0, math.radians(angle - 26.0), scale * 0.99, 92, 0.31, 0.58)
    elif local_frame == 5:
        draw_motion_wake(pixels, x + 22.0, y - 6.0, step, local_frame)
        draw_axe(pixels, axe, x - 14.0, y - 6.0, math.radians(angle - 28.0), scale * 0.98, 86, 0.31, 0.58)
        draw_axe(pixels, axe, x + 8.0, y + 6.0, math.radians(angle + 11.0), scale * 0.94, 48, 0.31, 0.58)

    draw_axe(pixels, axe, x, y, math.radians(angle), scale, 255, 0.31, 0.58)
    if local_frame == 5:
        draw_impact_sparks(pixels, min(FRAME_WIDTH - GUTTER - 18.0, x + 54.0 + step * 3.0), y - 28.0 + step * 2.0, step)
    return pixels


def draw_motion_wake(pixels: bytearray, cx: float, cy: float, step: int, local_frame: int) -> None:
    strength = 1.0 if local_frame == 4 else 0.78
    for i in range(24):
        t = i / 23
        radius = 24.0 + step * 4.0 + t * 52.0
        angle = math.radians(-82.0 + t * 102.0 + step * 7.0)
        color = (70, 10, 14, int((42 + t * 32) * strength))
        draw_ellipse(pixels, cx + math.cos(angle) * radius, cy + math.sin(angle) * radius, 10 - int(t * 4), 2.6, angle, color)
        if i % 3 == 0:
            draw_ellipse(pixels, cx + math.cos(angle) * (radius + 8), cy + math.sin(angle) * (radius + 8), 7, 1.7, angle, (148, 139, 108, int(32 * strength)))


def draw_impact_sparks(pixels: bytearray, cx: float, cy: float, step: int) -> None:
    for i in range(9):
        angle = math.radians(-58.0 + i * 13.0)
        distance = 16 + i % 4 * 4 + step * 2
        draw_line(
            pixels,
            cx,
            cy,
            cx + math.cos(angle) * distance,
            cy + math.sin(angle) * distance,
            1,
            (177, 151, 94, 96),
        )


class Sprite:
    def __init__(self, width: int, height: int, pixels: bytearray):
        self.width = width
        self.height = height
        self.pixels = pixels


def draw_axe(
    dest: bytearray,
    axe: Sprite,
    anchor_x: float,
    anchor_y: float,
    angle: float,
    scale: float,
    alpha: int = 255,
    source_anchor_x_ratio: float = 0.60,
    source_anchor_y_ratio: float = 0.52,
) -> None:
    source_anchor_x = axe.width * source_anchor_x_ratio
    source_anchor_y = axe.height * source_anchor_y_ratio
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    for sy in range(axe.height):
        for sx in range(axe.width):
            source_idx = (sy * axe.width + sx) * 4
            source_alpha = axe.pixels[source_idx + 3]
            if source_alpha <= 4:
                continue
            dx = (sx - source_anchor_x) * scale
            dy = (sy - source_anchor_y) * scale
            tx = anchor_x + dx * cos_a - dy * sin_a
            ty = anchor_y + dx * sin_a + dy * cos_a
            out_alpha = int(source_alpha * alpha / 255)
            blend_pixel(
                dest,
                tx,
                ty,
                (
                    axe.pixels[source_idx],
                    axe.pixels[source_idx + 1],
                    axe.pixels[source_idx + 2],
                    out_alpha,
                ),
            )
            if source_alpha > 190 and alpha > 190 and (sx + sy) % 5 == 0:
                blend_pixel(
                    dest,
                    tx + 0.6,
                    ty + 0.2,
                    (
                        min(255, axe.pixels[source_idx] + 12),
                        min(255, axe.pixels[source_idx + 1] + 12),
                        min(255, axe.pixels[source_idx + 2] + 10),
                        max(24, out_alpha // 3),
                    ),
                )


def resize_to_width(pixels: bytearray, width: int, height: int, target_width: int) -> Sprite:
    target_height = max(1, round(height * (target_width / width)))
    resized = bytearray(target_width * target_height * 4)
    for y in range(target_height):
        source_y = (y + 0.5) * height / target_height - 0.5
        for x in range(target_width):
            source_x = (x + 0.5) * width / target_width - 0.5
            color = sample_bilinear(pixels, width, height, source_x, source_y)
            idx = (y * target_width + x) * 4
            resized[idx : idx + 4] = bytes(color)
    return Sprite(target_width, target_height, resized)


def flip_horizontal(sprite: Sprite) -> Sprite:
    flipped = bytearray(sprite.width * sprite.height * 4)
    for y in range(sprite.height):
        for x in range(sprite.width):
            src = (y * sprite.width + x) * 4
            dst = (y * sprite.width + (sprite.width - 1 - x)) * 4
            flipped[dst : dst + 4] = sprite.pixels[src : src + 4]
    return Sprite(sprite.width, sprite.height, flipped)


def sample_bilinear(pixels: bytearray, width: int, height: int, x: float, y: float) -> tuple[int, int, int, int]:
    x0 = max(0, min(width - 1, math.floor(x)))
    y0 = max(0, min(height - 1, math.floor(y)))
    x1 = max(0, min(width - 1, x0 + 1))
    y1 = max(0, min(height - 1, y0 + 1))
    tx = x - x0
    ty = y - y0
    return tuple(
        round(
            channel_at(pixels, width, x0, y0, channel) * (1 - tx) * (1 - ty)
            + channel_at(pixels, width, x1, y0, channel) * tx * (1 - ty)
            + channel_at(pixels, width, x0, y1, channel) * (1 - tx) * ty
            + channel_at(pixels, width, x1, y1, channel) * tx * ty
        )
        for channel in range(4)
    )


def channel_at(pixels: bytearray, width: int, x: int, y: int, channel: int) -> int:
    return pixels[(y * width + x) * 4 + channel]


def chroma_key_green(pixels: bytearray, width: int, height: int) -> bytearray:
    keyed = bytearray(pixels)
    for y in range(height):
        for x in range(width):
            idx = (y * width + x) * 4
            r, g, b = keyed[idx], keyed[idx + 1], keyed[idx + 2]
            green_score = g - max(r, b)
            if g > 132 and green_score > 34:
                keyed[idx + 3] = 0
            elif g > 90 and green_score > 14:
                keyed[idx + 3] = int(keyed[idx + 3] * clamp((34 - green_score) / 20, 0.0, 1.0))
            if keyed[idx + 3] == 0:
                keyed[idx : idx + 3] = b"\x00\x00\x00"
    return keyed


def opaque_bounds(pixels: bytearray, width: int, height: int) -> tuple[int, int, int, int]:
    left, top = width, height
    right, bottom = 0, 0
    for y in range(height):
        for x in range(width):
            if pixels[(y * width + x) * 4 + 3] > 12:
                left = min(left, x)
                top = min(top, y)
                right = max(right, x)
                bottom = max(bottom, y)
    if left > right or top > bottom:
        raise ValueError("No opaque source axe pixels found after chroma key")
    pad = 8
    return (max(0, left - pad), max(0, top - pad), min(width - 1, right + pad), min(height - 1, bottom + pad))


def crop_region(pixels: bytearray, source_width: int, bounds: tuple[int, int, int, int]) -> bytearray:
    left, top, right, bottom = bounds
    width = right - left + 1
    height = bottom - top + 1
    cropped = bytearray(width * height * 4)
    for y in range(height):
        src = ((top + y) * source_width + left) * 4
        dst = y * width * 4
        cropped[dst : dst + width * 4] = pixels[src : src + width * 4]
    return cropped


def blank_frame() -> bytearray:
    return bytearray(FRAME_WIDTH * FRAME_HEIGHT * 4)


def write_sheet(path: Path, frames: list[bytearray]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    width = FRAME_WIDTH * len(frames)
    pixels = bytearray(width * FRAME_HEIGHT * 4)
    for frame, frame_pixels in enumerate(frames):
        for y in range(FRAME_HEIGHT):
            dst = (y * width + frame * FRAME_WIDTH) * 4
            src = y * FRAME_WIDTH * 4
            pixels[dst : dst + FRAME_WIDTH * 4] = frame_pixels[src : src + FRAME_WIDTH * 4]
    path.write_bytes(encode_png(width, FRAME_HEIGHT, pixels))


def write_sheet_all(paths: list[Path], frames: list[bytearray]) -> None:
    for path in paths:
        write_sheet(path, frames)


def draw_line(pixels: bytearray, x0: float, y0: float, x1: float, y1: float, radius: int, color: tuple[int, int, int, int]) -> None:
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(steps):
        t = i / max(steps - 1, 1)
        draw_circle(pixels, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, radius, color)


def draw_circle(pixels: bytearray, cx: float, cy: float, radius: int, color: tuple[int, int, int, int]) -> None:
    for y in range(int(cy - radius), int(cy + radius) + 1):
        for x in range(int(cx - radius), int(cx + radius) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius**2:
                blend_pixel(pixels, x, y, color)


def draw_ellipse(pixels: bytearray, cx: float, cy: float, rx: float, ry: float, angle: float, color: tuple[int, int, int, int]) -> None:
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    radius = max(rx, ry) + 2
    for y in range(int(cy - radius), int(cy + radius) + 1):
        for x in range(int(cx - radius), int(cx + radius) + 1):
            dx = x - cx
            dy = y - cy
            local_x = dx * cos_a + dy * sin_a
            local_y = -dx * sin_a + dy * cos_a
            if (local_x / max(rx, 0.1)) ** 2 + (local_y / max(ry, 0.1)) ** 2 <= 1.0:
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


def decode_png(buffer: bytes) -> tuple[int, int, bytearray]:
    if buffer[1:4] != b"PNG":
        raise ValueError("Expected PNG")
    offset = 8
    width = 0
    height = 0
    bit_depth = 0
    color_type = 0
    idat_parts: list[bytes] = []

    while offset < len(buffer):
        length = struct.unpack(">I", buffer[offset : offset + 4])[0]
        kind = buffer[offset + 4 : offset + 8]
        data = buffer[offset + 8 : offset + 8 + length]
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", data)
            if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
                raise ValueError("Only non-interlaced 8-bit RGB/RGBA PNG files are supported")
        elif kind == b"IDAT":
            idat_parts.append(data)
        elif kind == b"IEND":
            break
        offset += length + 12

    source_bpp = 4 if color_type == 6 else 3
    source_stride = width * source_bpp
    inflated = zlib.decompress(b"".join(idat_parts))
    raw = bytearray(source_stride * height)
    source = 0
    for y in range(height):
        filter_type = inflated[source]
        source += 1
        row = inflated[source : source + source_stride]
        source += source_stride
        previous_start = (y - 1) * source_stride if y > 0 else None
        out_start = y * source_stride
        for x in range(source_stride):
            left = raw[out_start + x - source_bpp] if x >= source_bpp else 0
            up = raw[previous_start + x] if previous_start is not None else 0
            up_left = raw[previous_start + x - source_bpp] if previous_start is not None and x >= source_bpp else 0
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
            raw[out_start + x] = value & 0xFF

    pixels = bytearray(width * height * 4)
    for y in range(height):
        for x in range(width):
            src = (y * width + x) * source_bpp
            dst = (y * width + x) * 4
            pixels[dst : dst + 3] = raw[src : src + 3]
            pixels[dst + 3] = raw[src + 3] if color_type == 6 else 255
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
