import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { inflateSync } from 'node:zlib';

const FRAME_WIDTH = 192;
const FRAME_HEIGHT = 384;
const GUTTER = 8;
const ATTACK_SCALE = 0.46;
const ATTACK_POSITION_X = 28;
const ATTACK_POSITION_Y = -42;
const PLAYER_SCRIPT = readFileSync('scripts/player.gd', 'utf8');
const AXE_GENERATOR = readFileSync('tools/generatePlayerAxeSheets.py', 'utf8');
const ATTACK_MOTION_CONTRACT = readFileSync('tools/attack_motion_contract.py', 'utf8');
const ATTACK_HITBOXES_RIGHT = parseRuntimeAttackHitboxes(PLAYER_SCRIPT);
const AXE_ATTACK_SCALES = parseAttackPoseScales(ATTACK_MOTION_CONTRACT);

assert.match(AXE_GENERATOR, /from attack_motion_contract import ATTACK_MOTION_POSES/, 'axe attack layer should use the shared motion contract');

assert.ok(Math.min(...AXE_ATTACK_SCALES) >= 0.94, 'axe attack should not fake wind-up weight by shrinking the weapon');
assert.ok(Math.max(...AXE_ATTACK_SCALES) <= 1.06, 'axe attack should not fake impact weight by inflating the weapon');
assert.ok(
  Math.max(...AXE_ATTACK_SCALES) - Math.min(...AXE_ATTACK_SCALES) <= 0.12,
  'axe attack should keep weapon scale stable and express force through arc, timing, and body motion',
);

const contracts = [
  { file: 'assets/player-axe-idle-sheet-10.png', frames: 10, minVisible: 2100, minMetal: 220 },
  { file: 'assets/player-axe-walk-sheet-24.png', frames: 24, minVisible: 2000, minMetal: 220 },
  { file: 'assets/player-axe-shoot-sheet-8.png', frames: 8, minVisible: 1900, minMetal: 220 },
  { file: 'assets/player-axe-attack-combo-sheet-24.png', frames: 24, minVisible: 1200, minMetal: 20 },
];

for (const contract of contracts) {
  const png = parsePng(readFileSync(contract.file));
  assert.equal(png.width, FRAME_WIDTH * contract.frames, `${contract.file} should use ${contract.frames} horizontal 192px frames`);
  assert.equal(png.height, FRAME_HEIGHT, `${contract.file} should use the player 384px frame height`);
  assert.ok(countQuantizedColors(png) > 42, `${contract.file} should preserve the generated image's painterly palette`);
  assert.ok(countChromaGreen(png) < 8, `${contract.file} should not leave chroma-key green pixels around the axe`);

  for (let frame = 0; frame < contract.frames; frame += 1) {
    const x0 = frame * FRAME_WIDTH;
    assert.equal(maxAlphaInRect(png, x0, 0, GUTTER, FRAME_HEIGHT), 0, `${contract.file} frame ${frame} left gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0 + FRAME_WIDTH - GUTTER, 0, GUTTER, FRAME_HEIGHT), 0, `${contract.file} frame ${frame} right gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0, 0, FRAME_WIDTH, GUTTER), 0, `${contract.file} frame ${frame} top gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0, FRAME_HEIGHT - GUTTER, FRAME_WIDTH, GUTTER), 0, `${contract.file} frame ${frame} bottom gutter should be transparent`);
    assert.ok(countVisiblePixels(png, frame) > contract.minVisible, `${contract.file} frame ${frame} should have enough image-derived axe mass`);
    assert.ok(countMetalPixels(png, frame) > contract.minMetal, `${contract.file} frame ${frame} should include readable aged metal blade pixels`);
    assert.ok(countCrimsonPixels(png, frame) > 65, `${contract.file} frame ${frame} should include restrained crimson cloth wrap pixels`);
    assert.ok(countWoodPixels(png, frame) > 90, `${contract.file} frame ${frame} should include dark wooden handle pixels`);
    assert.ok(longestFlatOpaqueRun(png, frame) < 42, `${contract.file} frame ${frame} should not read as a script-made rectangle`);
  }
}

const idle = parsePng(readFileSync('assets/player-axe-idle-sheet-10.png'));
assert.ok(frameDifference(idle, 0, 1) < 1150, 'idle axe should breathe subtly instead of crawling as a whole image');

const attack = parsePng(readFileSync('assets/player-axe-attack-combo-sheet-24.png'));
assert.ok(frameDifference(attack, 3, 4) > frameDifference(attack, 1, 2) * 1.35, 'axe attack should snap hard after the held wind-up');
assert.ok(frameDifference(attack, 4, 5) > 1600, 'axe attack should have a readable impact transition');
for (const frame of [3, 4, 5, 11, 12, 13, 19, 20, 21]) {
  const bounds = visibleBounds(attack, frame);
  assert.ok(bounds, `attack frame ${frame} should have visible axe pixels`);
  assert.ok(bounds.maxX - bounds.minX > 74 || bounds.maxY - bounds.minY > 74, `attack frame ${frame} should read as a full weapon, not a small debug mark`);
}

for (const frame of [5, 13, 21]) {
  assert.ok(countMetalPixels(attack, frame) > 220, `attack impact frame ${frame} should clearly show the aged metal blade`);
}

for (const [combo, frame] of [5, 13, 21].entries()) {
  const overlap = attackMassInWorldHitbox(attack, frame, ATTACK_HITBOXES_RIGHT[combo][1]);
  assert.ok(overlap > 680, `attack frame ${frame} should put the image-based axe mass inside the active hitbox, got ${overlap}`);
}

for (const [combo, framePair] of [
  [4, 5],
  [12, 13],
  [20, 21],
].entries()) {
  for (const [activeIndex, frame] of framePair.entries()) {
    const frontOverlap = attackMassInWorldHitbox(attack, frame, ATTACK_HITBOXES_RIGHT[combo][activeIndex], 0.1);
    assert.ok(
      frontOverlap > 380,
      `attack frame ${frame} should put visible axe pixels in the runtime hitbox's contact band, got ${frontOverlap}`,
    );
  }
}

function parseRuntimeAttackHitboxes(script) {
  const offsets = parseVector2PairArray(script, 'ATTACK_HITBOX_OFFSETS');
  const sizes = parseVector2PairArray(script, 'ATTACK_HITBOX_SIZES');
  assert.equal(offsets.length, 3, 'player.gd should define three attack hitbox offset profiles');
  assert.equal(sizes.length, 3, 'player.gd should define three attack hitbox size profiles');
  return offsets.map((profile, combo) =>
    profile.map((offset, activeIndex) => ({
      x: offset.x,
      y: offset.y,
      w: sizes[combo][activeIndex].x,
      h: sizes[combo][activeIndex].y,
    })),
  );
}

function parseAttackPoseScales(contract) {
  const axePoseDeclaration = contract.match(/AXE_POSE_SETS = \[([\s\S]*?)\]\n\nSTEP_BIASES/)?.[1] ?? '';
  const scales = [...axePoseDeclaration.matchAll(/\(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)/g)].map((match) => Number(match[4]));
  assert.equal(scales.length, 24, 'axe attack generator should define 24 explicit pose scales');
  return scales;
}

function parseVector2PairArray(script, constantName) {
  const declaration = script.match(new RegExp(`const ${constantName} := \\[([\\s\\S]*?)\\n\\]`));
  assert.ok(declaration, `${constantName} should exist in player.gd`);
  return [...declaration[1].matchAll(/\[Vector2\(([-\d.]+), ([-\d.]+)\), Vector2\(([-\d.]+), ([-\d.]+)\)\]/g)].map((match) => [
    { x: Number(match[1]), y: Number(match[2]) },
    { x: Number(match[3]), y: Number(match[4]) },
  ]);
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

function countVisiblePixels(png, frame) {
  let count = 0;
  const x0 = frame * FRAME_WIDTH;
  for (let yy = 0; yy < FRAME_HEIGHT; yy += 1) {
    for (let xx = x0; xx < x0 + FRAME_WIDTH; xx += 1) {
      if (png.pixels[(yy * png.width + xx) * 4 + 3] > 16) count += 1;
    }
  }
  return count;
}

function countMetalPixels(png, frame) {
  let count = 0;
  const x0 = frame * FRAME_WIDTH;
  for (let yy = 0; yy < FRAME_HEIGHT; yy += 1) {
    for (let xx = x0; xx < x0 + FRAME_WIDTH; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      const r = png.pixels[i];
      const g = png.pixels[i + 1];
      const b = png.pixels[i + 2];
      const a = png.pixels[i + 3];
      if (a > 80 && r > 74 && g > 70 && b > 68 && Math.abs(r - g) < 46 && Math.abs(g - b) < 48) count += 1;
    }
  }
  return count;
}

function countCrimsonPixels(png, frame) {
  let count = 0;
  const x0 = frame * FRAME_WIDTH;
  for (let yy = 0; yy < FRAME_HEIGHT; yy += 1) {
    for (let xx = x0; xx < x0 + FRAME_WIDTH; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      const r = png.pixels[i];
      const g = png.pixels[i + 1];
      const b = png.pixels[i + 2];
      const a = png.pixels[i + 3];
      if (a > 40 && r > 48 && r > g * 1.35 && r > b * 1.12) count += 1;
    }
  }
  return count;
}

function countWoodPixels(png, frame) {
  let count = 0;
  const x0 = frame * FRAME_WIDTH;
  for (let yy = 0; yy < FRAME_HEIGHT; yy += 1) {
    for (let xx = x0; xx < x0 + FRAME_WIDTH; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      const r = png.pixels[i];
      const g = png.pixels[i + 1];
      const b = png.pixels[i + 2];
      const a = png.pixels[i + 3];
      if (a > 70 && r > 24 && r < 96 && g > 16 && g < 70 && b < 62 && r >= g) count += 1;
    }
  }
  return count;
}

function countChromaGreen(png) {
  let count = 0;
  for (let yy = 0; yy < png.height; yy += 1) {
    for (let xx = 0; xx < png.width; xx += 1) {
      const i = (yy * png.width + xx) * 4;
      const r = png.pixels[i];
      const g = png.pixels[i + 1];
      const b = png.pixels[i + 2];
      const a = png.pixels[i + 3];
      if (a > 20 && g > 120 && g > r * 1.45 && g > b * 1.45) count += 1;
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
      if (alpha <= 32) continue;
      colors.add(`${png.pixels[i] >> 4},${png.pixels[i + 1] >> 4},${png.pixels[i + 2] >> 4}`);
    }
  }
  return colors.size;
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

function longestFlatOpaqueRun(png, frame) {
  const x0 = frame * FRAME_WIDTH;
  let longest = 0;
  for (let yy = 0; yy < FRAME_HEIGHT; yy += 1) {
    let run = 0;
    let last = null;
    for (let xx = 0; xx < FRAME_WIDTH; xx += 1) {
      const i = (yy * png.width + x0 + xx) * 4;
      const a = png.pixels[i + 3];
      const key = a > 120 ? `${png.pixels[i] >> 4},${png.pixels[i + 1] >> 4},${png.pixels[i + 2] >> 4}` : null;
      if (key && key === last) run += 1;
      else run = key ? 1 : 0;
      last = key;
      longest = Math.max(longest, run);
    }
  }
  return longest;
}

function attackMassInWorldHitbox(png, frame, hitbox, frontBand = 0.0) {
  const x0 = frame * FRAME_WIDTH;
  const left = hitbox.x - hitbox.w / 2;
  const right = hitbox.x + hitbox.w / 2;
  const top = hitbox.y - hitbox.h / 2;
  const bottom = hitbox.y + hitbox.h / 2;
  const front = frontBand > 0.0 ? hitbox.x + hitbox.w * frontBand : left;
  let count = 0;

  for (let yy = 0; yy < FRAME_HEIGHT; yy += 1) {
    const worldY = (yy - FRAME_HEIGHT / 2) * ATTACK_SCALE + ATTACK_POSITION_Y;
    if (worldY < top || worldY > bottom) continue;
    for (let xx = 0; xx < FRAME_WIDTH; xx += 1) {
      const worldX = (xx - FRAME_WIDTH / 2) * ATTACK_SCALE + ATTACK_POSITION_X;
      if (worldX < left || worldX > right || worldX < front) continue;
      const alpha = png.pixels[(yy * png.width + x0 + xx) * 4 + 3];
      if (alpha > 32) count += 1;
    }
  }
  return count;
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
