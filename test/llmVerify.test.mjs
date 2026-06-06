import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { spawn } from 'node:child_process';

const godotCandidates = [
  process.env.GODOT_BIN,
  'godot',
  'godot4',
  '/Applications/Godot.app/Contents/MacOS/Godot',
].filter(Boolean);

test('LLM verify mode is documented as a package script', async () => {
  const packageJson = JSON.parse(await readFile('package.json', 'utf8'));

  assert.equal(packageJson.scripts['verify:llm'], 'node tools/llmVerifyRunner.mjs');
  assert.equal(existsSync('scripts/llm_verify.gd'), true, 'scripts/llm_verify.gd should exist');
  assert.equal(existsSync('tools/llmVerifyRunner.mjs'), true, 'tools/llmVerifyRunner.mjs should exist');
});

test('LLM verify mode emits a machine-readable pass summary', async () => {
  const godot = godotCandidates.find((candidate) => existsSync(candidate) || !candidate.includes('/'));
  assert.ok(godot, 'Godot executable should be available');

  const result = await run(godot, [
    '--headless',
    '--path',
    '.',
    '--log-file',
    '/private/tmp/ecliptica-llm-verify.log',
    '--script',
    'scripts/llm_verify.gd',
  ]);

  assert.equal(result.code, 0, result.stderr || result.stdout);
  const summary = parseSummary(result.stdout);

  assert.equal(summary.status, 'pass');
  assert.equal(summary.mode, 'llm_headless_verify');
  assert.equal(summary.project.name, 'Ecliptica');
  assert.equal(summary.project.viewport.width, 1920);
  assert.equal(summary.project.viewport.height, 1080);
  assert.equal(summary.stage.seed, 1337);
  assert.equal(summary.stage.sigil_count, 6);
  assert.ok(summary.stage.platform_count >= 7);
  assert.ok(summary.player.moved_right_by >= 40);
  assert.equal(summary.gameplay.gate_open_after_collecting_sigils, true);
  assert.equal(summary.gameplay.win_state_reached, true);
  assert.deepEqual(summary.failures, []);
});

function parseSummary(stdout) {
  const line = stdout.split('\n').find((entry) => entry.startsWith('LLM_VERIFY_JSON '));
  assert.ok(line, `stdout should contain LLM_VERIFY_JSON line:\n${stdout}`);
  return JSON.parse(line.slice('LLM_VERIFY_JSON '.length));
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
