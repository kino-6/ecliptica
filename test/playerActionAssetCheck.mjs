import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { inflateSync } from 'node:zlib';

const FRAME_WIDTH = 192;
const FRAME_HEIGHT = 384;
const GUTTER = 8;
const MAX_BAKED_AXE_PIXELS = 650;
const MIN_ATTACK_UPPER_BODY_SHIFT = 7.0;
const MIN_ATTACK_IMPACT_SILHOUETTE_DIFF = 1350;

const actionGenerator = readFileSync('tools/generatePlayerActionSheets.py', 'utf8');
const axeGenerator = readFileSync('tools/generatePlayerAxeSheets.py', 'utf8');
const motionContract = readFileSync('tools/attack_motion_contract.py', 'utf8');
const attackFrameGenerator = actionGenerator.match(/def make_attack_frame[\s\S]*?def make_shoot_frame/)?.[0] ?? '';
assert.match(actionGenerator, /from attack_motion_contract import ATTACK_MOTION_POSES/, 'player body attack should use the shared axe motion contract');
assert.match(axeGenerator, /from attack_motion_contract import ATTACK_MOTION_POSES/, 'axe attack layer should use the shared axe motion contract');
assert.match(motionContract, /kinetic_chain/, 'shared axe motion contract should document the human kinetic chain intent');
assert.doesNotMatch(attackFrameGenerator, /draw_line\(/, 'player body attack generator should not draw a script-made axe or handle');
assert.doesNotMatch(attackFrameGenerator, /draw_circle\(/, 'player body attack generator should not draw a script-made axe grip');
assert.match(attackFrameGenerator, /draw_cloth_pull/, 'player body attack should include cloth follow-through so the heavy swing reads in-game');
assert.match(attackFrameGenerator, /draw_attack_hand_bridge/, 'player body attack should visibly connect shoulder, hands, and axe grip during active frames');
assert.match(
  attackFrameGenerator,
  /local_frame in \[4, 5, 6\]/,
  'player body attack should keep shoulder, hands, and grip connected into frame 6 follow-through',
);

const contracts = [
  { file: 'assets/player-attack-combo-sheet-24.png', frameCount: 24, minVisible: 12500, minFrameDiff: 900, heavyAttack: true },
  { file: 'assets/player-shoot-sheet-8.png', frameCount: 8, minVisible: 11800, minFrameDiff: 500 },
];

for (const contract of contracts) {
  const png = parsePng(readFileSync(contract.file));
  assert.equal(png.width, FRAME_WIDTH * contract.frameCount, `${contract.file} width should match 192px frames`);
  assert.equal(png.height, FRAME_HEIGHT, `${contract.file} height should match the player body contract`);

  for (let frame = 0; frame < contract.frameCount; frame += 1) {
    const x0 = frame * FRAME_WIDTH;
    assert.equal(maxAlphaInRect(png, x0, 0, GUTTER, FRAME_HEIGHT), 0, `${contract.file} frame ${frame} left gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0 + FRAME_WIDTH - GUTTER, 0, GUTTER, FRAME_HEIGHT), 0, `${contract.file} frame ${frame} right gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0, 0, FRAME_WIDTH, GUTTER), 0, `${contract.file} frame ${frame} top gutter should be transparent`);
    assert.equal(maxAlphaInRect(png, x0, FRAME_HEIGHT - GUTTER, FRAME_WIDTH, GUTTER), 0, `${contract.file} frame ${frame} bottom gutter should be transparent`);
    assert.ok(countVisiblePixels(png, x0, 0, FRAME_WIDTH, FRAME_HEIGHT) > contract.minVisible, `${contract.file} frame ${frame} should contain a full readable body pose`);
  }

  assert.ok(frameDifference(png, 0, contract.frameCount - 1) > contract.minFrameDiff, `${contract.file} should visibly change pose across the animation`);
  if (contract.heavyAttack) {
    for (let combo = 0; combo < 3; combo += 1) {
      const base = combo * 8;
      assert.ok(centerOfMassX(png, base + 2) < centerOfMassX(png, base + 6), `${contract.file} combo ${combo + 1} should shift body weight into the hit`);
      assert.ok(frameDifference(png, base + 3, base + 5) > frameDifference(png, base, base + 1) * 1.12, `${contract.file} combo ${combo + 1} should accelerate after anticipation`);
      assert.ok(
        upperBodyCenterOfMassX(png, base + 5) - upperBodyCenterOfMassX(png, base + 3) >= MIN_ATTACK_UPPER_BODY_SHIFT,
        `${contract.file} combo ${combo + 1} should visibly drive the upper body into the axe impact`,
      );
      assert.ok(
        silhouetteDifference(png, base + 3, base + 5, 44, 228) >= MIN_ATTACK_IMPACT_SILHOUETTE_DIFF,
        `${contract.file} combo ${combo + 1} needs a readable windup-to-impact silhouette change`,
      );
      assert.ok(
        attackGripBridgePixels(png, base + 4) >= 95,
        `${contract.file} combo ${combo + 1} frame 4 should show the hands driving the axe grip`,
      );
      assert.ok(
        attackGripBridgePixels(png, base + 5) >= 115,
        `${contract.file} combo ${combo + 1} frame 5 should keep the hands connected through impact`,
      );
      assert.ok(
        attackGripBridgePixels(png, base + 6) >= 85,
        `${contract.file} combo ${combo + 1} frame 6 should keep the hands and shoulders visible during axe follow-through`,
      );
      assert.ok(countBakedAxePixels(png, base + 5) < MAX_BAKED_AXE_PIXELS, `${contract.file} combo ${combo + 1} should keep the axe out of the body sheet`);
    }
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

function frameDifference(png, frameA, frameB) {
  let difference = 0;
  const ax = frameA * FRAME_WIDTH;
  const bx = frameB * FRAME_WIDTH;
  for (let y = 0; y < FRAME_HEIGHT; y += 3) {
    for (let x = 0; x < FRAME_WIDTH; x += 3) {
      const ai = (y * png.width + ax + x) * 4;
      const bi = (y * png.width + bx + x) * 4;
      const alphaDiff = Math.abs(png.pixels[ai + 3] - png.pixels[bi + 3]);
      const colorDiff = Math.abs(png.pixels[ai] - png.pixels[bi]) + Math.abs(png.pixels[ai + 1] - png.pixels[bi + 1]) + Math.abs(png.pixels[ai + 2] - png.pixels[bi + 2]);
      if (alphaDiff > 20 || colorDiff > 90) difference += 1;
    }
  }
  return difference;
}

function centerOfMassX(png, frame) {
  let weighted = 0;
  let total = 0;
  const x0 = frame * FRAME_WIDTH;
  for (let y = 0; y < FRAME_HEIGHT; y += 2) {
    for (let x = 0; x < FRAME_WIDTH; x += 2) {
      const alpha = png.pixels[(y * png.width + x0 + x) * 4 + 3];
      if (alpha <= 16) continue;
      weighted += x * alpha;
      total += alpha;
    }
  }
  return weighted / total;
}

function upperBodyCenterOfMassX(png, frame) {
  let weighted = 0;
  let total = 0;
  const x0 = frame * FRAME_WIDTH;
  for (let y = 44; y < 228; y += 2) {
    for (let x = 0; x < FRAME_WIDTH; x += 2) {
      const alpha = png.pixels[(y * png.width + x0 + x) * 4 + 3];
      if (alpha <= 16) continue;
      weighted += x * alpha;
      total += alpha;
    }
  }
  return weighted / Math.max(total, 1);
}

function silhouetteDifference(png, frameA, frameB, yMin, yMax) {
  let difference = 0;
  const ax = frameA * FRAME_WIDTH;
  const bx = frameB * FRAME_WIDTH;
  for (let y = yMin; y < yMax; y += 1) {
    for (let x = 0; x < FRAME_WIDTH; x += 1) {
      const alphaA = png.pixels[(y * png.width + ax + x) * 4 + 3] > 28;
      const alphaB = png.pixels[(y * png.width + bx + x) * 4 + 3] > 28;
      if (alphaA !== alphaB) difference += 1;
    }
  }
  return difference;
}

function attackGripBridgePixels(png, frame) {
  let count = 0;
  const x0 = frame * FRAME_WIDTH;
  for (let y = 118; y < 194; y += 1) {
    for (let x = 86; x < 142; x += 1) {
      const i = (y * png.width + x0 + x) * 4;
      const r = png.pixels[i];
      const g = png.pixels[i + 1];
      const b = png.pixels[i + 2];
      const a = png.pixels[i + 3];
      const darkArm = a > 72 && r >= 12 && r <= 94 && g >= 10 && g <= 76 && b >= 10 && b <= 70;
      const warmGrip = a > 64 && r > 70 && r <= 165 && g > 42 && g <= 118 && b < 92;
      if (darkArm || warmGrip) count += 1;
    }
  }
  return count;
}

function countBakedAxePixels(png, frame) {
  let count = 0;
  const x0 = frame * FRAME_WIDTH;
  for (let y = 40; y < 240; y += 1) {
    for (let x = GUTTER; x < FRAME_WIDTH - GUTTER; x += 1) {
      const likelyWeaponZone = x > 95 && x < 185 && y > 70 && y < 220;
      if (!likelyWeaponZone) continue;
      const i = (y * png.width + x0 + x) * 4;
      const expectedHandBridgeZone = x >= 86 && x <= 142 && y >= 118 && y <= 194;
      if (expectedHandBridgeZone) continue;
      const [r, g, b, a] = [png.pixels[i], png.pixels[i + 1], png.pixels[i + 2], png.pixels[i + 3]];
      if (a > 70 && r >= 70 && r <= 175 && g <= 70 && b <= 75 && r > g * 1.3 && r > b * 1.2) count += 1;
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
