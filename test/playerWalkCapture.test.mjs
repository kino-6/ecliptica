import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { inflateSync } from 'node:zlib';

const FRAME_WIDTH = 192;
const FRAME_HEIGHT = 384;
const FRAME_CENTER_X = FRAME_WIDTH / 2;
const WALK_SHEET = 'assets/player-walk-sheet-24.png';

const godotCandidates = [
  process.env.GODOT_BIN,
  'godot',
  'godot4',
  '/Applications/Godot.app/Contents/MacOS/Godot',
].filter(Boolean);

test('Godot walk capture keeps player control and sprite screen motion stable', async () => {
  const godot = godotCandidates.find((candidate) => existsSync(candidate) || !candidate.includes('/'));
  assert.ok(godot, 'Godot executable should be available');

  const result = await run(godot, [
    '--headless',
    '--path',
    '.',
    '--log-file',
    '/private/tmp/codex-game-test-walk-capture.log',
    '--script',
    'scripts/walk_capture.gd',
  ]);

  assert.equal(result.code, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /WALK_CAPTURE_JSON /);
  const summary = JSON.parse(result.stdout.match(/WALK_CAPTURE_JSON (.+)/)?.[1] ?? '{}');
  assert.equal(summary.mode, 'walk_capture');
  assert.ok(summary.samples.length >= 48, 'walk capture should record enough frames for a full cycle');

  const atlas = parsePng(readFileSync(WALK_SHEET));
  const centerOffsets = Array.from({ length: 24 }, (_, frame) => alphaCenterX(atlas, frame) - FRAME_CENTER_X);
  const walkingSamples = summary.samples.filter((sample) => sample.animation === 'walk');
  assert.ok(new Set(walkingSamples.map((sample) => sample.frame)).size >= 10, 'walk capture should advance through multiple animation frames');

  const playerSteps = consecutiveDeltas(walkingSamples.map((sample) => sample.player_x));
  assert.ok(range(playerSteps) <= 0.08, `player control should move at a stable per-frame step, got ${range(playerSteps).toFixed(3)}px jitter`);

  const visualX = walkingSamples.map((sample) => sample.sprite_screen_x + centerOffsets[sample.frame] * sample.sprite_screen_scale_x);
  const visualSteps = consecutiveDeltas(visualX);
  assert.ok(range(visualSteps) <= 0.85, `walk sprite should not visibly vibrate in screen space, got ${range(visualSteps).toFixed(3)}px step jitter`);
});

function run(command, args) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { cwd: process.cwd(), env: process.env });
    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk) => {
      stdout += chunk;
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk;
    });
    child.on('error', (error) => {
      resolve({ code: -1, stdout, stderr: String(error) });
    });
    child.on('close', (code) => {
      resolve({ code, stdout, stderr });
    });
  });
}

function consecutiveDeltas(values) {
  const deltas = [];
  for (let index = 1; index < values.length; index += 1) {
    deltas.push(values[index] - values[index - 1]);
  }
  return deltas;
}

function range(values) {
  return Math.max(...values) - Math.min(...values);
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

function alphaCenterX(png, frame) {
  let weightedX = 0;
  let alphaTotal = 0;
  const x0 = frame * FRAME_WIDTH;
  for (let y = 0; y < FRAME_HEIGHT; y += 1) {
    for (let x = 0; x < FRAME_WIDTH; x += 1) {
      const alpha = png.pixels[(y * png.width + x0 + x) * 4 + 3];
      if (alpha <= 8) continue;
      weightedX += x * alpha;
      alphaTotal += alpha;
    }
  }
  return weightedX / alphaTotal;
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
