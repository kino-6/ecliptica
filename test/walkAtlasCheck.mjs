import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { inflateSync } from 'node:zlib';

const FRAME_WIDTH = 192;
const FRAME_HEIGHT = 384;
const GUTTER = 12;

const sheets = [
  { file: 'assets/player-idle-sheet-10.png', frames: 10, label: 'idle' },
  { file: 'assets/player-walk-sheet-24.png', frames: 24, label: 'walk' },
];

for (const sheet of sheets) {
  const png = parsePng(readFileSync(sheet.file));
  assert.equal(png.width, FRAME_WIDTH * sheet.frames, `${sheet.label} sheet should use ${sheet.frames} ${FRAME_WIDTH}px frames`);
  assert.equal(png.height, FRAME_HEIGHT, `${sheet.label} sheet should be ${FRAME_HEIGHT}px tall`);

  const centers = [];
  const frameWidths = [];
  const frameTopY = [];
  const frameFootY = [];

  for (let frame = 0; frame < sheet.frames; frame += 1) {
    const x0 = frame * FRAME_WIDTH;
    const leftAlpha = maxAlphaInRect(png, x0, 0, GUTTER, png.height);
    const rightAlpha = maxAlphaInRect(png, x0 + FRAME_WIDTH - GUTTER, 0, GUTTER, png.height);
    const topAlpha = maxAlphaInRect(png, x0, 0, FRAME_WIDTH, GUTTER);
    const bottomAlpha = maxAlphaInRect(png, x0, png.height - GUTTER, FRAME_WIDTH, GUTTER);

    assert.equal(leftAlpha, 0, `${sheet.label} frame ${frame} left gutter should be transparent`);
    assert.equal(rightAlpha, 0, `${sheet.label} frame ${frame} right gutter should be transparent`);
    assert.equal(topAlpha, 0, `${sheet.label} frame ${frame} top gutter should be transparent`);
    assert.equal(bottomAlpha, 0, `${sheet.label} frame ${frame} bottom gutter should be transparent`);
    centers.push(alphaCenterX(png, x0, FRAME_WIDTH));
    const bounds = alphaBounds(png, x0, FRAME_WIDTH);
    frameWidths.push(bounds.width);
    frameTopY.push(bounds.minY);
    frameFootY.push(bounds.maxY);
  }

  const centerDrift = Math.max(...centers) - Math.min(...centers);
  const widthDrift = Math.max(...frameWidths) - Math.min(...frameWidths);
  const topDrift = Math.max(...frameTopY) - Math.min(...frameTopY);
  const footDrift = Math.max(...frameFootY) - Math.min(...frameFootY);
  assert.ok(centerDrift <= 5, `${sheet.label} frame alpha center drift should stay under 5px, got ${centerDrift.toFixed(2)}px`);
  assert.ok(widthDrift <= 34, `${sheet.label} frame visible-width drift should stay under 34px, got ${widthDrift}px`);
  assert.ok(topDrift <= 6, `${sheet.label} frame head/top drift should stay under 6px, got ${topDrift}px`);
  assert.ok(footDrift <= 2, `${sheet.label} frame foot baseline drift should stay under 2px, got ${footDrift}px`);
  if (sheet.label === 'idle') {
    const coreDrift = maxCorePixelDrift(png, sheet.frames);
    assert.ok(coreDrift <= 0.02, `idle core pixels should stay mostly fixed, got ${(coreDrift * 100).toFixed(2)}% changed pixels`);
  }
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

function alphaCenterX(png, x, width) {
  let weightedX = 0;
  let alphaTotal = 0;
  for (let yy = 0; yy < png.height; yy += 1) {
    for (let xx = 0; xx < width; xx += 1) {
      const alpha = png.pixels[(yy * png.width + x + xx) * 4 + 3];
      if (alpha > 8) {
        weightedX += xx * alpha;
        alphaTotal += alpha;
      }
    }
  }
  return weightedX / alphaTotal;
}

function alphaBounds(png, x, width) {
  let minX = width;
  let maxX = 0;
  let minY = png.height;
  let maxY = 0;
  for (let yy = 0; yy < png.height; yy += 1) {
    for (let xx = 0; xx < width; xx += 1) {
      const alpha = png.pixels[(yy * png.width + x + xx) * 4 + 3];
      if (alpha > 8) {
        minX = Math.min(minX, xx);
        maxX = Math.max(maxX, xx);
        minY = Math.min(minY, yy);
        maxY = Math.max(maxY, yy);
      }
    }
  }
  return {
    minY,
    maxY,
    width: maxX - minX + 1,
  };
}

function maxCorePixelDrift(png, frameCount) {
  const baseX = 0;
  let maxDrift = 0;
  for (let frame = 1; frame < frameCount; frame += 1) {
    const x0 = frame * FRAME_WIDTH;
    let changed = 0;
    let measured = 0;
    for (let yy = 54; yy < 332; yy += 1) {
      for (let xx = 70; xx < 145; xx += 1) {
        if (isAllowedIdleMotionPixel(xx, yy)) continue;
        const a = png.pixels[(yy * png.width + baseX + xx) * 4 + 3];
        if (a <= 8) continue;
        measured += 1;
        const base = (yy * png.width + baseX + xx) * 4;
        const current = (yy * png.width + x0 + xx) * 4;
        const delta =
          Math.abs(png.pixels[base] - png.pixels[current]) +
          Math.abs(png.pixels[base + 1] - png.pixels[current + 1]) +
          Math.abs(png.pixels[base + 2] - png.pixels[current + 2]) +
          Math.abs(png.pixels[base + 3] - png.pixels[current + 3]);
        if (delta > 28) changed += 1;
      }
    }
    maxDrift = Math.max(maxDrift, changed / measured);
  }
  return maxDrift;
}

function isAllowedIdleMotionPixel(x, y) {
  return x < 82 || (x < 104 && y > 190);
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
