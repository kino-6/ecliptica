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

const WINDOW_E2E_TIMEOUT_MS = 45000;

test('Godot window E2E opens at 1920x1080 logical size', { skip: process.env.RUN_GODOT_WINDOW_E2E !== '1' }, async () => {
  const godot = godotCandidates.find((candidate) => existsSync(candidate) || !candidate.includes('/'));
  assert.ok(godot, 'Godot executable should be available');

  const result = await run(godot, [
    '--path',
    '.',
    '--log-file',
    '/private/tmp/codex-game-test-godot-window-e2e.log',
    '--script',
    'scripts/window_e2e_runner.gd',
  ]);

  assert.equal(result.code, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /WINDOW_E2E_OK/);
  const projectOutput = (result.stdout + result.stderr)
    .replace(/ERROR: Condition "ret != noErr" is true\. Returning: ""\n\s+at: get_system_ca_certificates \(platform\/macos\/os_macos\.mm:\d+\)\n?/g, '');
  assert.doesNotMatch(projectOutput, /ERROR:/);
});

function run(command, args) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { cwd: process.cwd(), env: process.env });
    let stdout = '';
    let stderr = '';
    let settled = false;
    const timeout = setTimeout(() => {
      if (settled) return;
      settled = true;
      child.kill('SIGTERM');
      resolve({
        code: -1,
        stdout,
        stderr: `${stderr}\nTimed out after ${WINDOW_E2E_TIMEOUT_MS}ms while waiting for Godot window E2E.`,
      });
    }, WINDOW_E2E_TIMEOUT_MS);

    child.stdout.on('data', (chunk) => {
      stdout += chunk;
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk;
    });
    child.on('error', (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      resolve({ code: -1, stdout, stderr: String(error) });
    });
    child.on('close', (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      resolve({ code, stdout, stderr });
    });
  });
}
