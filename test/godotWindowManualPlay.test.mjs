import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';

test('window manual play evidence mode is exposed as a package script', async () => {
  const packageJson = JSON.parse(await readFile('package.json', 'utf8'));

  assert.equal(packageJson.scripts['playtest:window-manual'], 'node tools/windowManualPlayRunner.mjs');
  assert.equal(existsSync('scripts/window_manual_play_probe.gd'), true, 'window manual Godot script should exist');
  assert.equal(existsSync('tools/windowManualPlayRunner.mjs'), true, 'window manual runner should exist');
});

test('window manual play captures real non-headless viewport evidence', { skip: process.env.RUN_GODOT_WINDOW_MANUAL !== '1' }, async () => {
  const result = await run('npm', ['run', 'playtest:window-manual']);
  const summary = await parseSummary(result.stdout);

  assert.equal(result.code, 0, result.stderr || result.stdout);
  assert.equal(summary.mode, 'window_manual_play_probe');
  assert.equal(summary.status, 'pass');
  assert.notEqual(summary.display_name, 'headless');
  assert.equal(summary.input_model, 'held_e2e_player_inputs');
  assert.equal(summary.direct_damage_used, false);
  assert.ok(summary.window.content_scale_size.x >= 1280);
  assert.ok(summary.window.content_scale_size.y >= 720);
  assert.equal(existsSync(summary.summary_path), true, 'summary.json should exist');
  assert.ok(summary.screenshots.length >= 3);
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-after_attack'));
  for (const screenshot of summary.screenshots) {
    assert.equal(existsSync(screenshot.path), true, `${screenshot.path} should exist`);
    assert.ok(screenshot.width > 0);
    assert.ok(screenshot.height > 0);
  }
  assert.ok(summary.route_log.some((entry) => entry.phase === 'movement' && entry.moved_by > 20));
  assert.ok(summary.route_log.some((entry) => entry.phase === 'attack' && entry.hit === true));
});

async function parseSummary(stdout) {
  const line = stdout.split('\n').find((entry) => entry.startsWith('WINDOW_MANUAL_PLAY_JSON '));
  assert.ok(line, `stdout should contain WINDOW_MANUAL_PLAY_JSON line:\n${stdout}`);
  const stdoutSummary = JSON.parse(line.slice('WINDOW_MANUAL_PLAY_JSON '.length));
  assert.equal(existsSync(stdoutSummary.summary_path), true, 'stdout summary_path should exist');
  return JSON.parse(await readFile(stdoutSummary.summary_path, 'utf8'));
}

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
