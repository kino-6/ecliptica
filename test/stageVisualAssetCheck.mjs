import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { inflateSync } from 'node:zlib';

test('stage and ranged attack assets are production gothic sprites instead of flat debug blocks', () => {
  const platform = parsePng(readFileSync('assets/platform-stone-tile.png'));
  const shot = parsePng(readFileSync('assets/player-shot.png'));

  assert.equal(platform.width, 96, 'platform tile should be a 96px gothic stone module');
  assert.equal(platform.height, 64, 'platform tile should be 64px tall');
  assert.ok(countVisiblePixels(platform) > 5200, 'platform tile should be fully painted');
  assert.ok(countQuantizedColors(platform) > 28, 'platform tile should have painterly stone variation');
  assert.ok(countStonePixels(platform) > 2400, 'platform tile should read as dark wet stone');
  assert.ok(countCrimsonPixels(platform) > 20, 'platform tile should include restrained crimson staining');
  assert.ok(longestFlatRun(platform) < 44, 'platform tile should not be a flat rectangle fill');

  assert.equal(shot.width, 64, 'shot sprite should be 64px wide');
  assert.equal(shot.height, 24, 'shot sprite should be 24px tall');
  assert.ok(countVisiblePixels(shot) > 260, 'shot should have a readable silhouette');
  assert.ok(countQuantizedColors(shot) > 12, 'shot should use a multi-tone brass/smoke palette');
  assert.ok(countBrassPixels(shot) > 60, 'shot should include a bright brass muzzle core');
  assert.ok(countSmokePixels(shot) > 100, 'shot should include dark smoke instead of a plain line');
  assert.ok(longestFlatRun(shot) < 18, 'shot should not be a flat debug bar');
});

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
  const pixels = Buffer.alloc(width * height * 4);
  let source = 0;
  const stride = width * 4;

  for (let y = 0; y < height; y += 1) {
    const filter = inflated[source];
    source += 1;
    const row = inflated.subarray(source, source + stride);
    source += stride;
    const out = pixels.subarray(y * stride, (y + 1) * stride);
    const prev = y > 0 ? pixels.subarray((y - 1) * stride, y * stride) : null;
    for (let x = 0; x < stride; x += 1) {
      const left = x >= 4 ? out[x - 4] : 0;
      const up = prev ? prev[x] : 0;
      const upLeft = prev && x >= 4 ? prev[x - 4] : 0;
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

function countVisiblePixels(png) {
  let count = 0;
  forEachPixel(png, (r, g, b, a) => {
    if (a > 24) count += 1;
  });
  return count;
}

function countQuantizedColors(png) {
  const colors = new Set();
  forEachPixel(png, (r, g, b, a) => {
    if (a > 24) colors.add(`${r >> 4},${g >> 4},${b >> 4}`);
  });
  return colors.size;
}

function countStonePixels(png) {
  let count = 0;
  forEachPixel(png, (r, g, b, a) => {
    if (a > 80 && b >= r * 0.9 && b >= g * 0.8 && r >= 18 && r <= 95 && g <= 105 && b <= 125) count += 1;
  });
  return count;
}

function countCrimsonPixels(png) {
  let count = 0;
  forEachPixel(png, (r, g, b, a) => {
    if (a > 32 && r > 70 && r > g * 1.45 && r > b * 1.2) count += 1;
  });
  return count;
}

function countBrassPixels(png) {
  let count = 0;
  forEachPixel(png, (r, g, b, a) => {
    if (a > 70 && r > 150 && g > 118 && b > 58 && r > b * 1.8) count += 1;
  });
  return count;
}

function countSmokePixels(png) {
  let count = 0;
  forEachPixel(png, (r, g, b, a) => {
    if (a > 28 && r < 82 && g < 90 && b < 102) count += 1;
  });
  return count;
}

function longestFlatRun(png) {
  let longest = 0;
  for (let y = 0; y < png.height; y += 1) {
    let run = 0;
    let previous = null;
    for (let x = 0; x < png.width; x += 1) {
      const i = (y * png.width + x) * 4;
      if (png.pixels[i + 3] <= 24) {
        run = 0;
        previous = null;
        continue;
      }
      const key = `${png.pixels[i] >> 3},${png.pixels[i + 1] >> 3},${png.pixels[i + 2] >> 3},${png.pixels[i + 3] >> 5}`;
      if (key === previous) run += 1;
      else run = 1;
      previous = key;
      longest = Math.max(longest, run);
    }
  }
  return longest;
}

function forEachPixel(png, callback) {
  for (let y = 0; y < png.height; y += 1) {
    for (let x = 0; x < png.width; x += 1) {
      const i = (y * png.width + x) * 4;
      callback(png.pixels[i], png.pixels[i + 1], png.pixels[i + 2], png.pixels[i + 3]);
    }
  }
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
