import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { inflateSync } from 'node:zlib';

const FRAME_WIDTH = 128;
const FRAME_HEIGHT = 128;
const FRAME_COUNT = 8;
const GUTTER = 4;

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

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}
