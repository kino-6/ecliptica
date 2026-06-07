import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';

const godotCandidates = [
  process.env.GODOT_BIN,
  'godot',
  'godot4',
  '/Applications/Godot.app/Contents/MacOS/Godot',
].filter(Boolean);

test('enemy lunges horizontally while gravity pulls it down', async () => {
  const godot = godotCandidates.find((candidate) => existsSync(candidate) || !candidate.includes('/'));
  assert.ok(godot, 'Godot executable should be available');

  const result = await run(godot, [
    '--headless',
    '--path',
    '.',
    '--log-file',
    '/private/tmp/codex-game-test-enemy-gravity.log',
    '--script',
    'scripts/enemy_gravity_capture.gd',
  ]);

  assert.equal(result.code, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /ENEMY_GRAVITY_JSON /);
  const summary = JSON.parse(result.stdout.match(/ENEMY_GRAVITY_JSON (.+)/)?.[1] ?? '{}');
  assert.equal(summary.mode, 'enemy_gravity_capture');
  assert.ok(Math.abs(summary.delta.x) > 18, `enemy should still lunge horizontally, got delta.x=${summary.delta.x}`);
  assert.ok(summary.delta.y > 36, `airborne enemy should fall under gravity, got delta.y=${summary.delta.y}`);
  assert.ok(summary.samples.some((sample) => sample.state === 'attack'), 'enemy should enter attack/lunge state during the probe');
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
