import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { inflateSync } from 'node:zlib';

test('stage and ranged attack assets are production gothic sprites instead of flat debug blocks', () => {
  const platform = parsePng(readFileSync('assets/platform-stone-tile.png'));
  const shot = parsePng(readFileSync('assets/player-shot-sheet-6.png'));
  const sigil = parsePng(readFileSync('assets/sigil-relic.png'));
  const gateSealed = parsePng(readFileSync('assets/gate-sealed.png'));
  const gateOpen = parsePng(readFileSync('assets/gate-open.png'));
  const dummy = parsePng(readFileSync('assets/training-reliquary.png'));

  assert.equal(platform.width, 96, 'platform tile should be a 96px gothic stone module');
  assert.equal(platform.height, 64, 'platform tile should be 64px tall');
  assert.ok(countVisiblePixels(platform) > 5200, 'platform tile should be fully painted');
  assert.ok(countQuantizedColors(platform) > 28, 'platform tile should have painterly stone variation');
  assert.ok(countStonePixels(platform) > 2400, 'platform tile should read as dark wet stone');
  assert.ok(countCrimsonPixels(platform) > 20, 'platform tile should include restrained crimson staining');
  assert.ok(longestFlatRun(platform) < 44, 'platform tile should not be a flat rectangle fill');

  assert.equal(shot.width, 960, 'shot VFX should be a 6 frame 160px sheet');
  assert.equal(shot.height, 72, 'shot VFX should have enough height for muzzle smoke, sparks, and recoil flash');
  assert.ok(countVisiblePixels(shot) > 12000, 'shot VFX sheet should have readable smoke-and-flash silhouettes');
  assert.ok(countQuantizedColors(shot) > 120, 'shot VFX should use a painterly brass/smoke palette');
  assert.ok(countBrassPixels(shot) > 900, 'shot VFX should include a bright brass muzzle core in the early frames');
  assert.ok(countSmokePixels(shot) > 9000, 'shot VFX should include dark smoke instead of a plain line');
  assert.ok(visibleHeight(shot) >= 44, 'shot VFX should not collapse into a one-pixel laser line');
  assert.ok(longestFlatRun(shot) < 32, 'shot VFX should not be a flat debug bar');
  const shotFrames = Array.from({ length: 6 }, (_, index) => extractFrame(shot, index, 160, 72));
  assert.ok(countBrassPixels(shotFrames[0]) > countBrassPixels(shotFrames[3]), 'muzzle flash should be strongest at the first impact frames');
  assert.ok(countSmokePixels(shotFrames[5]) > countBrassPixels(shotFrames[5]) * 20, 'late shot frames should decay into smoke rather than stay as a glowing rectangle');
  assert.ok(shotFrames.every((frame) => longestFlatRun(frame) < 32), 'no shot frame should contain a long flat rectangular run');

  assert.equal(sigil.width, 48, 'sigil relic should use a compact 48px sprite');
  assert.equal(sigil.height, 64, 'sigil relic should be 64px tall');
  assert.ok(countVisiblePixels(sigil) > 900, 'sigil relic should have a readable painted body');
  assert.ok(countCrimsonPixels(sigil) > 360, 'sigil relic should carry the blood-red objective color');
  assert.ok(countBrassPixels(sigil) > 35, 'sigil relic should include brass/ember detail');
  assert.ok(longestFlatRun(sigil) < 12, 'sigil relic should not be a red rectangle');

  assert.equal(gateSealed.width, 96, 'sealed gate should use a 96px sprite');
  assert.equal(gateSealed.height, 160, 'sealed gate should be 160px tall');
  assert.equal(gateOpen.width, 96, 'open gate should use a matching 96px sprite');
  assert.equal(gateOpen.height, 160, 'open gate should be 160px tall');
  assert.ok(countVisiblePixels(gateSealed) > 5600, 'sealed gate should read as a full gothic gate');
  assert.ok(countVisiblePixels(gateOpen) > 5600, 'open gate should read as a full gothic gate');
  assert.ok(countCrimsonPixels(gateOpen) > countCrimsonPixels(gateSealed), 'open gate should visibly glow red');
  assert.ok(countQuantizedColors(gateOpen) > 18, 'open gate should have painterly variation');

  assert.equal(dummy.width, 64, 'training reliquary should use a 64px sprite');
  assert.equal(dummy.height, 96, 'training reliquary should be 96px tall');
  assert.ok(countVisiblePixels(dummy) > 1400, 'training reliquary should replace the flat dummy block');
  assert.ok(countBrassPixels(dummy) > 70, 'training reliquary should include aged metal focal detail');
  assert.ok(longestFlatRun(dummy) < 18, 'training reliquary should not be a plain rectangle');
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

function extractFrame(png, frameIndex, frameWidth, frameHeight) {
  const pixels = Buffer.alloc(frameWidth * frameHeight * 4);
  for (let y = 0; y < frameHeight; y += 1) {
    const sourceStart = (y * png.width + frameIndex * frameWidth) * 4;
    const targetStart = y * frameWidth * 4;
    png.pixels.copy(pixels, targetStart, sourceStart, sourceStart + frameWidth * 4);
  }
  return { width: frameWidth, height: frameHeight, pixels };
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

function visibleHeight(png) {
  let minY = png.height;
  let maxY = -1;
  for (let y = 0; y < png.height; y += 1) {
    for (let x = 0; x < png.width; x += 1) {
      const i = (y * png.width + x) * 4;
      if (png.pixels[i + 3] <= 24) continue;
      minY = Math.min(minY, y);
      maxY = Math.max(maxY, y);
    }
  }
  return maxY < 0 ? 0 : maxY - minY + 1;
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
