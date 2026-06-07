import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { inflateSync } from 'node:zlib';

const FRAME_WIDTH = 128;
const FRAME_HEIGHT = 128;
const FRAME_COUNT = 8;
const GUTTER = 4;
const ATTACK_HITBOX_WIDTH = 96;
const ATTACK_HITBOX_HEIGHT = 72;
const ARC_SCALE_X = 0.72;
const ARC_SCALE_Y = 0.56;
const ACTIVE_FRAMES = [2, 3, 4];

const png = parsePng(readFileSync('assets/axe-swing-sheet-8.png'));
assert.equal(png.width, FRAME_WIDTH * FRAME_COUNT, 'axe swing sheet should use 8 horizontal 128px frames');
assert.equal(png.height, FRAME_HEIGHT, 'axe swing sheet should be 128px tall');

for (let frame = 0; frame < FRAME_COUNT; frame += 1) {
  const x0 = frame * FRAME_WIDTH;
  assert.equal(maxAlphaInRect(png, x0, 0, GUTTER, FRAME_HEIGHT), 0, `frame ${frame} left gutter should be transparent`);
  assert.equal(maxAlphaInRect(png, x0 + FRAME_WIDTH - GUTTER, 0, GUTTER, FRAME_HEIGHT), 0, `frame ${frame} right gutter should be transparent`);
  assert.equal(maxAlphaInRect(png, x0, 0, FRAME_WIDTH, GUTTER), 0, `frame ${frame} top gutter should be transparent`);
  assert.equal(maxAlphaInRect(png, x0, FRAME_HEIGHT - GUTTER, FRAME_WIDTH, GUTTER), 0, `frame ${frame} bottom gutter should be transparent`);
  assert.ok(maxAlphaInRect(png, x0, 0, FRAME_WIDTH, FRAME_HEIGHT) > 160, `frame ${frame} should contain visible swing pixels`);
  assert.ok(countVisiblePixels(png, x0, 0, FRAME_WIDTH, FRAME_HEIGHT) > 2400, `frame ${frame} should have enough painted mass for a readable attack`);
}

assert.ok(countCrimsonPixels(png) > 900, 'axe swing should include dark crimson afterimage pixels');
assert.ok(countQuantizedColors(png) > 20, 'axe swing should use a painterly multi-tone palette instead of flat debug colors');
assert.ok(frameDifference(png, 1, 2) > frameDifference(png, 0, 1) * 1.35, 'axe swing should accelerate sharply after the wind-up frame');
assert.ok(frameDifference(png, 2, 3) > 520, 'axe swing should include a heavy impact transition');
assert.ok(countBrightMetalPixels(png, 3) < 120, 'attack VFX should not draw a second readable axe blade over the player body animation');

for (const frame of ACTIVE_FRAMES) {
  const bounds = visibleBounds(png, frame);
  assert.ok(bounds, `active frame ${frame} should have visible pixels`);
  const scaled = scaledBoundsAroundFrameOrigin(bounds);
  assert.ok(scaled.left >= -ATTACK_HITBOX_WIDTH / 2 - 2, `active frame ${frame} should not draw left of the attack hitbox`);
  assert.ok(scaled.right <= ATTACK_HITBOX_WIDTH / 2 + 2, `active frame ${frame} should not draw right of the attack hitbox`);
  assert.ok(scaled.top >= -ATTACK_HITBOX_HEIGHT / 2 - 2, `active frame ${frame} should not draw above the attack hitbox`);
  assert.ok(scaled.bottom <= ATTACK_HITBOX_HEIGHT / 2 + 2, `active frame ${frame} should not draw below the attack hitbox`);
}

function parsePng(buffer) {
  assert.equal(buffer.toString('ascii', 1, 4), 'PNG', 'expected PNG');

  let offset = 8;
  let width = 0;
  let height = 0;
  const chunks = [];

  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString('ascii', offset + 4, offset + 8);
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    chunks.push({ type, data });
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
    }
    offset += 12 + length;
    if (type === 'IEND') break;
  }

  const idat = Buffer.concat(chunks.filter((chunk) => chunk.type === 'IDAT').map((chunk) => chunk.data));
  const inflated = inflateSync(idat);
  const bytesPerPixel = 4;
  const stride = width * bytesPerPixel;
  const pixels = Buffer.alloc(stride * height);
  let source = 0;

  for (let y = 0; y < height; y += 1) {
    const filter = inflated[source];
    source += 1;
    const row = inflated.subarray(source, source + stride);
    source += stride;
    const out = pixels.subarray(y * stride, (y + 1) * stride);
    const prev = y > 0 ? pixels.subarray((y - 1) * stride, y * stride) : null;

    for (let x = 0; x < stride; x += 1) {
      const left = x >= bytesPerPixel ? out[x - bytesPerPixel] : 0;
      const up = prev ? prev[x] : 0;
      const upLeft = prev && x >= bytesPerPixel ? prev[x - bytesPerPixel] : 0;
      let value;
      if (filter === 0) value = row[x];
      else if (filter === 1) value = row[x] + left;
      else if (filter === 2) value = row[x] + up;
      else if (filter === 3) value = row[x] + Math.floor((left + up) / 2);
      else if (filter === 4) value = row[x] + paeth(left, up, upLeft);
      else throw new Error(`unsupported PNG filter ${filter}`);
      out[x] = value & 0xff;
    }
  }

  return { width, height, pixels };
}

function maxAlphaInRect(png, x, y, width, height) {
  let max = 0;
  for (let yy = y; yy < y + height; yy += 1) {
    for (let xx = x; xx < x + width; xx += 1) {
      const alpha = png.pixels[(yy * png.width + xx) * 4 + 3];
      if (alpha > max) max = alpha;
    }
  }
  return max;
}

function countVisiblePixels(png, x, y, width, height) {
  let count = 0;
  for (let yy = y; yy < y + height; yy += 1) {
    for (let xx = x; xx < x + width; xx += 1) {
      if (png.pixels[(yy * png.width + xx) * 4 + 3] > 16) count += 1;
    }
  }
  return count;
}

function countCrimsonPixels(png) {
  let count = 0;
  for (let yy = 0; yy < png.height; yy += 1) {
    for (let xx = 0; xx < png.width; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      const [r, g, b, a] = [png.pixels[i], png.pixels[i + 1], png.pixels[i + 2], png.pixels[i + 3]];
      if (a > 24 && r > 70 && r > g * 1.45 && r > b * 1.2) count += 1;
    }
  }
  return count;
}

function countQuantizedColors(png) {
  const colors = new Set();
  for (let yy = 0; yy < png.height; yy += 1) {
    for (let xx = 0; xx < png.width; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      const alpha = png.pixels[i + 3];
      if (alpha <= 24) continue;
      colors.add(`${png.pixels[i] >> 4},${png.pixels[i + 1] >> 4},${png.pixels[i + 2] >> 4}`);
    }
  }
  return colors.size;
}

function countBrightMetalPixels(png, frame) {
  let count = 0;
  const x0 = frame * FRAME_WIDTH;
  for (let yy = 0; yy < png.height; yy += 1) {
    for (let xx = x0; xx < x0 + FRAME_WIDTH; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      const [r, g, b, a] = [png.pixels[i], png.pixels[i + 1], png.pixels[i + 2], png.pixels[i + 3]];
      if (a > 80 && r > 150 && g > 140 && b > 110 && Math.abs(r - g) < 75) count += 1;
    }
  }
  return count;
}

function frameDifference(png, frameA, frameB) {
  let difference = 0;
  const ax = frameA * FRAME_WIDTH;
  const bx = frameB * FRAME_WIDTH;
  for (let y = 0; y < FRAME_HEIGHT; y += 2) {
    for (let x = 0; x < FRAME_WIDTH; x += 2) {
      const ai = (y * png.width + ax + x) * 4;
      const bi = (y * png.width + bx + x) * 4;
      const alphaDiff = Math.abs(png.pixels[ai + 3] - png.pixels[bi + 3]);
      const colorDiff = Math.abs(png.pixels[ai] - png.pixels[bi]) + Math.abs(png.pixels[ai + 1] - png.pixels[bi + 1]) + Math.abs(png.pixels[ai + 2] - png.pixels[bi + 2]);
      if (alphaDiff > 18 || colorDiff > 76) difference += 1;
    }
  }
  return difference;
}

function visibleBounds(png, frame) {
  const x0 = frame * FRAME_WIDTH;
  let minX = FRAME_WIDTH;
  let minY = FRAME_HEIGHT;
  let maxX = -1;
  let maxY = -1;

  for (let yy = 0; yy < FRAME_HEIGHT; yy += 1) {
    for (let xx = 0; xx < FRAME_WIDTH; xx += 1) {
      const alpha = png.pixels[(yy * png.width + x0 + xx) * 4 + 3];
      if (alpha <= 24) continue;
      minX = Math.min(minX, xx);
      minY = Math.min(minY, yy);
      maxX = Math.max(maxX, xx);
      maxY = Math.max(maxY, yy);
    }
  }

  if (maxX < 0) return null;
  return { minX, minY, maxX, maxY };
}

function scaledBoundsAroundFrameOrigin(bounds) {
  return {
    left: (bounds.minX - FRAME_WIDTH / 2) * ARC_SCALE_X,
    right: (bounds.maxX - FRAME_WIDTH / 2) * ARC_SCALE_X,
    top: (bounds.minY - FRAME_HEIGHT / 2) * ARC_SCALE_Y,
    bottom: (bounds.maxY - FRAME_HEIGHT / 2) * ARC_SCALE_Y,
  };
}

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}
