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
    minBone: 120,
    minCentralMass: 3580,
    minDark: 2100,
    maxTopNoise: 8,
    maxMaskArea: 360,
    maxHorizontalRedBar: 24,
  },
  {
    file: 'assets/enemy-walk-sheet-12.png',
    frameWidth: 96,
    frameHeight: 96,
    frameCount: 12,
    minVisible: 1650,
    minCrimson: 620,
    minBone: 130,
    minCentralMass: 3580,
    minDark: 2100,
    maxTopNoise: 8,
    maxMaskArea: 360,
    maxHorizontalRedBar: 24,
  },
  {
    file: 'assets/enemy-attack-sheet-8.png',
    frameWidth: 96,
    frameHeight: 96,
    frameCount: 8,
    minVisible: 1700,
    minCrimson: 680,
    minBone: 140,
    minCentralMass: 3400,
    minDark: 2050,
    maxTopNoise: 8,
    maxMaskArea: 390,
    maxHorizontalRedBar: 170,
  },
  {
    file: 'assets/boss-idle-sheet-8.png',
    frameWidth: 192,
    frameHeight: 160,
    frameCount: 8,
    minVisible: 5200,
    minCrimson: 1800,
    minBone: 300,
    minCentralMass: 7800,
    minDark: 7200,
    maxTopNoise: 120,
    maxMaskArea: 950,
    maxHorizontalRedBar: 640,
  },
];

for (const contract of contracts) {
  const png = parsePng(readFileSync(contract.file));
  assert.equal(png.width, contract.frameWidth * contract.frameCount, `${contract.file} should use 8 horizontal frames`);
  assert.equal(png.height, contract.frameHeight, `${contract.file} should have the expected frame height`);
  assert.ok(countCrimsonPixels(png) > contract.minCrimson, `${contract.file} should include gothic crimson forms`);
  assert.ok(countBonePixels(png) > contract.minBone, `${contract.file} should include bone or aged brass highlights`);
  assert.ok(countQuantizedColors(png) > 16, `${contract.file} should use a multi-tone painterly palette`);

  for (let frame = 0; frame < contract.frameCount; frame += 1) {
    const x0 = frame * contract.frameWidth;
    assert.equal(maxAlphaInRect(png, x0, 0, 4, contract.frameHeight), 0, `${contract.file} frame ${frame} left gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0 + contract.frameWidth - 4, 0, 4, contract.frameHeight), 0, `${contract.file} frame ${frame} right gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0, 0, contract.frameWidth, 4), 0, `${contract.file} frame ${frame} top gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0, contract.frameHeight - 4, contract.frameWidth, 4), 0, `${contract.file} frame ${frame} bottom gutter should be transparent`);
    assert.ok(countVisiblePixels(png, x0, 0, contract.frameWidth, contract.frameHeight) > contract.minVisible, `${contract.file} frame ${frame} should have readable mass`);
    assert.ok(countVisiblePixels(png, x0 + contract.frameWidth * 0.22, contract.frameHeight * 0.18, contract.frameWidth * 0.56, contract.frameHeight * 0.76) > contract.minCentralMass, `${contract.file} frame ${frame} should carry a readable central gothic silhouette`);
    assert.ok(countDarkPixels(png, x0, 0, contract.frameWidth, contract.frameHeight) > contract.minDark, `${contract.file} frame ${frame} should have enough dark cloak mass to read against the stage`);
    assert.ok(countVisiblePixels(png, x0, 0, contract.frameWidth, contract.frameHeight * 0.08) <= contract.maxTopNoise, `${contract.file} frame ${frame} should avoid toy-like antenna pixels at the top edge`);
    assert.ok(countMaskFocalPixels(png, x0, contract.frameWidth, contract.frameHeight) <= contract.maxMaskArea, `${contract.file} frame ${frame} should use a mask focal point, not a toy-like oversized face`);
    assert.ok(countHorizontalRedBarPixels(png, x0, contract.frameWidth, contract.frameHeight) <= contract.maxHorizontalRedBar, `${contract.file} frame ${frame} should avoid flat horizontal red placeholder limbs`);
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
  const x0 = Math.floor(x);
  const y0 = Math.floor(y);
  const x1 = Math.floor(x + width);
  const y1 = Math.floor(y + height);
  for (let yy = y0; yy < y1; yy += 1) {
    for (let xx = x0; xx < x1; xx += 1) {
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

function countBonePixels(png) {
  let count = 0;
  for (let yy = 0; yy < png.height; yy += 1) {
    for (let xx = 0; xx < png.width; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      const [r, g, b, a] = [png.pixels[i], png.pixels[i + 1], png.pixels[i + 2], png.pixels[i + 3]];
      if (a > 24 && r > 110 && g > 88 && b > 50 && r > b * 1.35) count += 1;
    }
  }
  return count;
}

function countDarkPixels(png, x, y, width, height) {
  let count = 0;
  const x1 = Math.floor(x + width);
  const y1 = Math.floor(y + height);
  for (let yy = Math.floor(y); yy < y1; yy += 1) {
    for (let xx = Math.floor(x); xx < x1; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      const [r, g, b, a] = [png.pixels[i], png.pixels[i + 1], png.pixels[i + 2], png.pixels[i + 3]];
      if (a > 80 && r < 42 && g < 48 && b < 54) count += 1;
    }
  }
  return count;
}

function countMaskFocalPixels(png, x, width, height) {
  let count = 0;
  const minX = x + Math.floor(width * 0.22);
  const maxX = x + Math.floor(width * 0.78);
  const minY = Math.floor(height * 0.10);
  const maxY = Math.floor(height * 0.46);
  for (let yy = minY; yy < maxY; yy += 1) {
    for (let xx = minX; xx < maxX; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      const [r, g, b, a] = [png.pixels[i], png.pixels[i + 1], png.pixels[i + 2], png.pixels[i + 3]];
      if (a > 24 && r > 110 && g > 88 && b > 50 && r > b * 1.35) count += 1;
    }
  }
  return count;
}

function countHorizontalRedBarPixels(png, x, width, height) {
  let count = 0;
  const minY = Math.floor(height * 0.28);
  const maxY = Math.floor(height * 0.48);
  for (let yy = minY; yy < maxY; yy += 1) {
    for (let localX = 0; localX < width; localX += 1) {
      if (localX >= width * 0.20 && localX <= width * 0.80) continue;
      const i = (yy * png.width + x + localX) * 4;
      const [r, g, b, a] = [png.pixels[i], png.pixels[i + 1], png.pixels[i + 2], png.pixels[i + 3]];
      if (a > 40 && r > 85 && r > g * 1.5 && r > b * 1.2) count += 1;
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
