from __future__ import annotations

import math
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path


ENEMY_IDLE_FRAMES = 8
ENEMY_WALK_FRAMES = 12
ENEMY_ATTACK_FRAMES = 8
BOSS_FRAMES = 8
ENEMY_FRAME = (192, 384)
BOSS_FRAME = (256, 384)

ENEMY_SOURCE_KEY = Path("assets/source/enemy-ghoul-source-key.png")
BOSS_SOURCE_KEY = Path("assets/source/boss-bishop-source-key.png")
ENEMY_SOURCE_OUT = Path("assets/source/enemy-ghoul-source.png")
BOSS_SOURCE_OUT = Path("assets/source/boss-bishop-source.png")
ENEMY_IDLE_OUT = Path("assets/enemy-idle-sheet-8.png")
ENEMY_WALK_OUT = Path("assets/enemy-walk-sheet-12.png")
ENEMY_ATTACK_OUT = Path("assets/enemy-attack-sheet-8.png")
BOSS_OUT = Path("assets/boss-idle-sheet-8.png")


@dataclass(frozen=True)
class ImageData:
    width: int
    height: int
    pixels: bytearray


def main() -> None:
    enemy_source = prepare_source(ENEMY_SOURCE_KEY)
    boss_source = prepare_source(BOSS_SOURCE_KEY)
    ENEMY_SOURCE_OUT.write_bytes(encode_png(enemy_source.width, enemy_source.height, enemy_source.pixels))
    BOSS_SOURCE_OUT.write_bytes(encode_png(boss_source.width, boss_source.height, boss_source.pixels))

    enemy_actor = resize_to_height(crop_alpha(enemy_source, 20), 254)
    boss_actor = resize_to_height(crop_alpha(boss_source, 20), 332)

    write_sheet(ENEMY_IDLE_OUT, ENEMY_FRAME, ENEMY_IDLE_FRAMES, enemy_actor, "enemy_idle")
    write_sheet(ENEMY_WALK_OUT, ENEMY_FRAME, ENEMY_WALK_FRAMES, enemy_actor, "enemy_walk")
    write_sheet(ENEMY_ATTACK_OUT, ENEMY_FRAME, ENEMY_ATTACK_FRAMES, enemy_actor, "enemy_attack")
    write_sheet(BOSS_OUT, BOSS_FRAME, BOSS_FRAMES, boss_actor, "boss_idle")


def prepare_source(path: Path) -> ImageData:
    image = parse_png(path.read_bytes())
    pixels = bytearray(image.pixels)
    for index in range(0, len(pixels), 4):
        red = pixels[index]
        green = pixels[index + 1]
        blue = pixels[index + 2]
        alpha = pixels[index + 3]
        dominance = green - max(red, blue)
        key_like = (
            green > 96
            and dominance > 32
            and green > red * 1.30
            and green > blue * 1.30
        ) or (
            green > 46
            and dominance > 18
            and red < 84
            and blue < 84
        ) or (
            green > 55
            and dominance > 8
        )
        if key_like:
            pixels[index] = 0
            pixels[index + 1] = 0
            pixels[index + 2] = 0
            pixels[index + 3] = 0
            continue
        if alpha > 0 and dominance > 3:
            cap = max(red, blue) + 3
            pixels[index + 1] = max(0, min(255, cap))
    return ImageData(image.width, image.height, pixels)


def write_sheet(path: Path, frame: tuple[int, int], frame_count: int, actor: ImageData, animation: str) -> None:
    frame_width, frame_height = frame
    width = frame_width * frame_count
    pixels = bytearray(width * frame_height * 4)
    for frame_index in range(frame_count):
        frame_pixels = bytearray(frame_width * frame_height * 4)
        draw_frame(frame_pixels, frame_width, frame_height, frame_index, frame_count, actor, animation)
        blit_frame(pixels, width, frame_pixels, frame_width, frame_height, frame_index * frame_width)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(encode_png(width, frame_height, pixels))


def draw_frame(
    pixels: bytearray,
    frame_width: int,
    frame_height: int,
    frame_index: int,
    frame_count: int,
    actor: ImageData,
    animation: str,
) -> None:
    phase = frame_index / frame_count * math.tau
    if animation == "enemy_idle":
        baseline = 350
        draw_shadow(pixels, frame_width, frame_height, frame_width * 0.50, baseline + 2, 34, 8)
        compose_actor(
            pixels,
            frame_width,
            frame_height,
            actor,
            frame_width * 0.52,
            baseline,
            phase,
            cloth_sway=3.2,
            lean=0.0,
            lower_motion=0.5,
        )
    elif animation == "enemy_walk":
        baseline = 350
        stride = math.sin(phase)
        draw_shadow(pixels, frame_width, frame_height, frame_width * 0.50, baseline + 2, 36, 8)
        compose_actor(
            pixels,
            frame_width,
            frame_height,
            actor,
            frame_width * 0.52,
            baseline,
            phase,
            cloth_sway=5.0,
            lean=stride * 1.8,
            lower_motion=3.8,
            stride=stride,
        )
    elif animation == "enemy_attack":
        baseline = 350
        windups = [-5.0, -9.0, -7.0, 0.5, 13.0, 9.0, 2.0, 0.0]
        smear = [0.0, 0.0, 0.1, 0.45, 0.9, 0.45, 0.08, 0.0][frame_index]
        draw_shadow(pixels, frame_width, frame_height, frame_width * 0.52, baseline + 2, 40, 8)
        if smear > 0.0:
            compose_actor(
                pixels,
                frame_width,
                frame_height,
                tint_actor(actor, (112, 18, 28), int(74 * smear)),
                frame_width * 0.55 + smear * 13.0,
                baseline,
                phase,
                cloth_sway=8.0 * smear,
                lean=windups[frame_index] + 11.0 * smear,
                lower_motion=1.0,
                alpha_scale=0.62 * smear,
            )
        compose_actor(
            pixels,
            frame_width,
            frame_height,
            actor,
            frame_width * 0.52 + max(0.0, windups[frame_index]) * 0.6,
            baseline,
            phase,
            cloth_sway=5.0 + smear * 5.0,
            lean=windups[frame_index],
            lower_motion=1.0,
        )
    elif animation == "boss_idle":
        baseline = 356
        pulse = math.sin(phase)
        draw_shadow(pixels, frame_width, frame_height, frame_width * 0.50, baseline + 2, 58, 12)
        compose_actor(
            pixels,
            frame_width,
            frame_height,
            actor,
            frame_width * 0.50,
            baseline,
            phase,
            cloth_sway=4.2,
            lean=pulse * 0.8,
            lower_motion=0.9,
        )
    else:
        raise ValueError(animation)


def compose_actor(
    dest: bytearray,
    frame_width: int,
    frame_height: int,
    actor: ImageData,
    center_x: float,
    baseline: float,
    phase: float,
    *,
    cloth_sway: float,
    lean: float,
    lower_motion: float,
    stride: float = 0.0,
    alpha_scale: float = 1.0,
) -> None:
    left = center_x - actor.width * 0.5
    top = baseline - actor.height
    for y in range(actor.height):
        yn = y / max(actor.height - 1, 1)
        cloak_zone = max(0.0, (yn - 0.42) / 0.58)
        foot_zone = max(0.0, (yn - 0.70) / 0.30)
        row_sway = math.sin(phase + yn * 3.8) * cloth_sway * cloak_zone
        row_sway += stride * lower_motion * math.sin(yn * math.pi) * foot_zone
        row_sway += lean * (0.18 + yn * 0.82)
        row_y = int(round(top + y + abs(stride) * math.sin(yn * math.pi) * 1.2 * foot_zone))
        if row_y < 4 or row_y >= frame_height - 4:
            continue
        for x in range(actor.width):
            source_index = (y * actor.width + x) * 4
            alpha = actor.pixels[source_index + 3]
            if alpha <= 8:
                continue
            row_x = int(round(left + x + row_sway))
            if row_x < 4 or row_x >= frame_width - 4:
                continue
            blend_pixel(
                dest,
                frame_width,
                row_x,
                row_y,
                (
                    actor.pixels[source_index],
                    actor.pixels[source_index + 1],
                    actor.pixels[source_index + 2],
                    int(alpha * alpha_scale),
                ),
            )


def tint_actor(actor: ImageData, tint: tuple[int, int, int], alpha: int) -> ImageData:
    pixels = bytearray(actor.pixels)
    for index in range(0, len(pixels), 4):
        source_alpha = pixels[index + 3]
        if source_alpha <= 8:
            continue
        pixels[index] = int(pixels[index] * 0.45 + tint[0] * 0.55)
        pixels[index + 1] = int(pixels[index + 1] * 0.35 + tint[1] * 0.65)
        pixels[index + 2] = int(pixels[index + 2] * 0.35 + tint[2] * 0.65)
        pixels[index + 3] = min(source_alpha, alpha)
    return ImageData(actor.width, actor.height, pixels)


def draw_shadow(pixels: bytearray, width: int, height: int, cx: float, cy: float, rx: float, ry: float) -> None:
    for y in range(int(cy - ry), int(cy + ry) + 1):
        if y < 4 or y >= height - 4:
            continue
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if x < 4 or x >= width - 4:
                continue
            local_x = (x - cx) / rx
            local_y = (y - cy) / ry
            if local_x * local_x + local_y * local_y <= 1.0:
                blend_pixel(pixels, width, x, y, (3, 4, 6, 92))


def blit_frame(sheet: bytearray, sheet_width: int, frame: bytearray, frame_width: int, frame_height: int, x_offset: int) -> None:
    for y in range(frame_height):
        source_start = y * frame_width * 4
        target_start = (y * sheet_width + x_offset) * 4
        sheet[target_start : target_start + frame_width * 4] = frame[source_start : source_start + frame_width * 4]


def crop_alpha(image: ImageData, threshold: int) -> ImageData:
    min_x = image.width
    min_y = image.height
    max_x = -1
    max_y = -1
    for y in range(image.height):
        for x in range(image.width):
            alpha = image.pixels[(y * image.width + x) * 4 + 3]
            if alpha > threshold:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if max_x < min_x or max_y < min_y:
        raise ValueError("source image has no visible pixels")
    pad = 6
    min_x = max(0, min_x - pad)
    min_y = max(0, min_y - pad)
    max_x = min(image.width - 1, max_x + pad)
    max_y = min(image.height - 1, max_y + pad)
    width = max_x - min_x + 1
    height = max_y - min_y + 1
    pixels = bytearray(width * height * 4)
    for y in range(height):
        source_start = ((min_y + y) * image.width + min_x) * 4
        target_start = y * width * 4
        pixels[target_start : target_start + width * 4] = image.pixels[source_start : source_start + width * 4]
    return ImageData(width, height, pixels)


def resize_to_height(image: ImageData, target_height: int) -> ImageData:
    scale = target_height / image.height
    target_width = max(1, int(round(image.width * scale)))
    pixels = bytearray(target_width * target_height * 4)
    for y in range(target_height):
        src_y = (y + 0.5) / scale - 0.5
        y0 = max(0, min(image.height - 1, int(math.floor(src_y))))
        y1 = max(0, min(image.height - 1, y0 + 1))
        fy = src_y - y0
        for x in range(target_width):
            src_x = (x + 0.5) / scale - 0.5
            x0 = max(0, min(image.width - 1, int(math.floor(src_x))))
            x1 = max(0, min(image.width - 1, x0 + 1))
            fx = src_x - x0
            color = bilinear(image, x0, y0, x1, y1, fx, fy)
            target_index = (y * target_width + x) * 4
            pixels[target_index : target_index + 4] = bytes(color)
    return ImageData(target_width, target_height, pixels)


def bilinear(image: ImageData, x0: int, y0: int, x1: int, y1: int, fx: float, fy: float) -> tuple[int, int, int, int]:
    out = []
    for channel in range(4):
        c00 = image.pixels[(y0 * image.width + x0) * 4 + channel]
        c10 = image.pixels[(y0 * image.width + x1) * 4 + channel]
        c01 = image.pixels[(y1 * image.width + x0) * 4 + channel]
        c11 = image.pixels[(y1 * image.width + x1) * 4 + channel]
        top = c00 * (1.0 - fx) + c10 * fx
        bottom = c01 * (1.0 - fx) + c11 * fx
        out.append(max(0, min(255, int(round(top * (1.0 - fy) + bottom * fy)))))
    return tuple(out)  # type: ignore[return-value]


def blend_pixel(pixels: bytearray, width: int, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    index = (y * width + x) * 4
    source_alpha = color[3] / 255.0
    if source_alpha <= 0:
        return
    target_alpha = pixels[index + 3] / 255.0
    out_alpha = source_alpha + target_alpha * (1.0 - source_alpha)
    if out_alpha <= 0:
        return
    for channel in range(3):
        source = color[channel] / 255.0
        target = pixels[index + channel] / 255.0
        pixels[index + channel] = round(((source * source_alpha) + (target * target_alpha * (1.0 - source_alpha))) / out_alpha * 255)
    pixels[index + 3] = round(out_alpha * 255)


def parse_png(buffer: bytes) -> ImageData:
    if not buffer.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("expected PNG")
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
            width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", data)
        elif kind == b"IDAT":
            idat_parts.append(data)
        elif kind == b"IEND":
            break
        offset += 12 + length
    if bit_depth != 8 or color_type not in {2, 6}:
        raise ValueError(f"unsupported PNG format: bit_depth={bit_depth} color_type={color_type}")

    channels = 4 if color_type == 6 else 3
    stride = width * channels
    inflated = zlib.decompress(b"".join(idat_parts))
    raw = bytearray(stride * height)
    source = 0
    for y in range(height):
        filter_type = inflated[source]
        source += 1
        row = inflated[source : source + stride]
        source += stride
        out = raw[y * stride : (y + 1) * stride]
        prev = raw[(y - 1) * stride : y * stride] if y > 0 else None
        for x in range(stride):
            left = out[x - channels] if x >= channels else 0
            up = prev[x] if prev is not None else 0
            up_left = prev[x - channels] if prev is not None and x >= channels else 0
            if filter_type == 0:
                value = row[x]
            elif filter_type == 1:
                value = row[x] + left
            elif filter_type == 2:
                value = row[x] + up
            elif filter_type == 3:
                value = row[x] + math.floor((left + up) / 2)
            elif filter_type == 4:
                value = row[x] + paeth(left, up, up_left)
            else:
                raise ValueError(f"unsupported PNG filter {filter_type}")
            out[x] = value & 0xFF
        raw[y * stride : (y + 1) * stride] = out

    pixels = bytearray(width * height * 4)
    for y in range(height):
        for x in range(width):
            source_index = (y * width + x) * channels
            target_index = (y * width + x) * 4
            pixels[target_index] = raw[source_index]
            pixels[target_index + 1] = raw[source_index + 1]
            pixels[target_index + 2] = raw[source_index + 2]
            pixels[target_index + 3] = raw[source_index + 3] if color_type == 6 else 255
    return ImageData(width, height, pixels)


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


if __name__ == "__main__":
    main()
