import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { inflateSync } from 'node:zlib';

const contracts = [
  {
    file: 'assets/enemy-idle-sheet-8.png',
    frameWidth: 96,
    frameHeight: 96,
    frameCount: 8,
    minVisible: 1600,
    minCrimson: 550,
  },
  {
    file: 'assets/boss-idle-sheet-8.png',
    frameWidth: 192,
    frameHeight: 160,
    frameCount: 8,
    minVisible: 5200,
    minCrimson: 1800,
  },
];

for (const contract of contracts) {
  const png = parsePng(readFileSync(contract.file));
  assert.equal(png.width, contract.frameWidth * contract.frameCount, `${contract.file} should use 8 horizontal frames`);
  assert.equal(png.height, contract.frameHeight, `${contract.file} should have the expected frame height`);
  assert.ok(countCrimsonPixels(png) > contract.minCrimson, `${contract.file} should include gothic crimson forms`);
  assert.ok(countQuantizedColors(png) > 16, `${contract.file} should use a multi-tone painterly palette`);

  for (let frame = 0; frame < contract.frameCount; frame += 1) {
    const x0 = frame * contract.frameWidth;
    assert.equal(maxAlphaInRect(png, x0, 0, 4, contract.frameHeight), 0, `${contract.file} frame ${frame} left gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0 + contract.frameWidth - 4, 0, 4, contract.frameHeight), 0, `${contract.file} frame ${frame} right gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0, 0, contract.frameWidth, 4), 0, `${contract.file} frame ${frame} top gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0, contract.frameHeight - 4, contract.frameWidth, 4), 0, `${contract.file} frame ${frame} bottom gutter should be transparent`);
    assert.ok(countVisiblePixels(png, x0, 0, contract.frameWidth, contract.frameHeight) > contract.minVisible, `${contract.file} frame ${frame} should have readable mass`);
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
  const stride = width * 4;
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
      if (a > 24 && r > 55 && r > g * 1.35 && r > b * 1.15) count += 1;
    }
  }
  return count;
}

function countQuantizedColors(png) {
  const colors = new Set();
  for (let yy = 0; yy < png.height; yy += 1) {
    for (let xx = 0; xx < png.width; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      if (png.pixels[i + 3] <= 24) continue;
      colors.add(`${png.pixels[i] >> 4},${png.pixels[i + 1] >> 4},${png.pixels[i + 2] >> 4}`);
    }
  }
  return colors.size;
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
