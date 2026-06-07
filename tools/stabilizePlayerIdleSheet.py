from __future__ import annotations

import sys
from pathlib import Path

from generatePlayerActionSheets import decode_png, encode_png


FRAME_WIDTH = 192
FRAME_HEIGHT = 384
FRAME_COUNT = 10
IDLE_SHEET = Path("assets/player-idle-sheet-10.png")

STABLE_PLANTED_BODY = {
    "x0": 84,
    "x1": 145,
    "y0": 178,
    "y1": 346,
}


def main() -> None:
    width, height, pixels = decode_png(IDLE_SHEET.read_bytes())
    expected_width = FRAME_WIDTH * FRAME_COUNT
    if width != expected_width or height != FRAME_HEIGHT:
        raise ValueError(f"{IDLE_SHEET} must be {expected_width}x{FRAME_HEIGHT}, got {width}x{height}")

    for frame in range(1, FRAME_COUNT):
        stabilize_planted_body(pixels, width, frame)

    IDLE_SHEET.write_bytes(encode_png(width, height, pixels))


def stabilize_planted_body(pixels: bytearray, sheet_width: int, frame: int) -> None:
    source_x0 = 0
    target_x0 = frame * FRAME_WIDTH
    for y in range(STABLE_PLANTED_BODY["y0"], STABLE_PLANTED_BODY["y1"]):
        for x in range(STABLE_PLANTED_BODY["x0"], STABLE_PLANTED_BODY["x1"]):
            source = (y * sheet_width + source_x0 + x) * 4
            target = (y * sheet_width + target_x0 + x) * 4
            pixels[target : target + 4] = pixels[source : source + 4]


if __name__ == "__main__":
    sys.exit(main())
