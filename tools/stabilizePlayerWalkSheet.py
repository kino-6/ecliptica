from __future__ import annotations

import sys
from pathlib import Path

from generatePlayerActionSheets import decode_png, encode_png


FRAME_WIDTH = 192
FRAME_HEIGHT = 384
FRAME_COUNT = 24
WALK_SHEET = Path("assets/player-walk-sheet-24.png")
TARGET_CENTER_X = 96.7
MAX_FRAME_SHIFT = 3

STABLE_CORE = {
    "x0": 84,
    "x1": 136,
    "y0": 42,
    "y1": 240,
}


def main() -> None:
    width, height, pixels = decode_png(WALK_SHEET.read_bytes())
    expected_width = FRAME_WIDTH * FRAME_COUNT
    if width != expected_width or height != FRAME_HEIGHT:
        raise ValueError(f"{WALK_SHEET} must be {expected_width}x{FRAME_HEIGHT}, got {width}x{height}")

    shifts = choose_alignment_shifts(pixels, width)
    for frame, shift in enumerate(shifts):
        if shift != 0:
            shift_frame(pixels, width, frame, shift)

    for frame in range(1, FRAME_COUNT):
        stabilize_frame_core(pixels, width, frame)

    WALK_SHEET.write_bytes(encode_png(width, height, pixels))


def choose_alignment_shifts(pixels: bytearray, sheet_width: int) -> list[int]:
    shifts: list[int] = []
    previous_center: float | None = None
    for frame in range(FRAME_COUNT):
        center = alpha_center_x(pixels, sheet_width, frame)
        bounds = alpha_bounds(pixels, sheet_width, frame)
        candidates: list[tuple[float, int, float]] = []
        for shift in range(-MAX_FRAME_SHIFT, MAX_FRAME_SHIFT + 1):
            shifted_center = center + shift
            if bounds["min_x"] + shift < 12 or bounds["max_x"] + shift >= FRAME_WIDTH - 12:
                continue
            center_cost = abs(shifted_center - TARGET_CENTER_X)
            smooth_cost = 0.0 if previous_center is None else abs(shifted_center - previous_center) * 2.0
            move_cost = abs(shift) * 0.02
            candidates.append((center_cost + smooth_cost + move_cost, shift, shifted_center))
        if not candidates:
            shifts.append(0)
            previous_center = center
            continue
        _, shift, previous_center = min(candidates, key=lambda candidate: candidate[0])
        shifts.append(shift)
    return shifts


def alpha_center_x(pixels: bytearray, sheet_width: int, frame: int) -> float:
    x_offset = frame * FRAME_WIDTH
    weighted = 0.0
    total = 0.0
    for y in range(FRAME_HEIGHT):
        for x in range(FRAME_WIDTH):
            alpha = pixels[(y * sheet_width + x_offset + x) * 4 + 3]
            if alpha <= 8:
                continue
            weighted += x * alpha
            total += alpha
    return weighted / total


def alpha_bounds(pixels: bytearray, sheet_width: int, frame: int) -> dict[str, int]:
    x_offset = frame * FRAME_WIDTH
    min_x = FRAME_WIDTH
    max_x = 0
    for y in range(FRAME_HEIGHT):
        for x in range(FRAME_WIDTH):
            alpha = pixels[(y * sheet_width + x_offset + x) * 4 + 3]
            if alpha <= 8:
                continue
            min_x = min(min_x, x)
            max_x = max(max_x, x)
    return {"min_x": min_x, "max_x": max_x}


def shift_frame(pixels: bytearray, sheet_width: int, frame: int, shift: int) -> None:
    x_offset = frame * FRAME_WIDTH
    source = bytearray(FRAME_WIDTH * FRAME_HEIGHT * 4)
    for y in range(FRAME_HEIGHT):
        src_start = (y * sheet_width + x_offset) * 4
        row = y * FRAME_WIDTH * 4
        source[row : row + FRAME_WIDTH * 4] = pixels[src_start : src_start + FRAME_WIDTH * 4]
        pixels[src_start : src_start + FRAME_WIDTH * 4] = bytes(FRAME_WIDTH * 4)

    for y in range(FRAME_HEIGHT):
        for x in range(FRAME_WIDTH):
            target_x = x + shift
            if target_x < 0 or target_x >= FRAME_WIDTH:
                continue
            source_idx = (y * FRAME_WIDTH + x) * 4
            if source[source_idx + 3] <= 0:
                continue
            target_idx = (y * sheet_width + x_offset + target_x) * 4
            pixels[target_idx : target_idx + 4] = source[source_idx : source_idx + 4]


def stabilize_frame_core(pixels: bytearray, sheet_width: int, frame: int) -> None:
    source_x0 = 0
    target_x0 = frame * FRAME_WIDTH
    for y in range(STABLE_CORE["y0"], STABLE_CORE["y1"]):
        for x in range(STABLE_CORE["x0"], STABLE_CORE["x1"]):
            source = (y * sheet_width + source_x0 + x) * 4
            if pixels[source + 3] <= 8:
                continue
            target = (y * sheet_width + target_x0 + x) * 4
            pixels[target : target + 4] = pixels[source : source + 4]


if __name__ == "__main__":
    sys.exit(main())
