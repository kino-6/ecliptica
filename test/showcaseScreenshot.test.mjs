import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, statSync } from 'node:fs';
import { spawn } from 'node:child_process';

test('showcase screenshot command saves the first-room capture', async () => {
  const result = await run(process.execPath, ['tools/showcaseScreenshotRunner.mjs']);

  assert.equal(result.code, 0, result.stderr || result.stdout);
  const summary = parseSummary(result.stdout);
  assert.equal(summary.status, 'pass');
  assert.equal(summary.width, 1920);
  assert.equal(summary.height, 1080);
  assert.equal(existsSync(summary.path), true, `${summary.path} should exist`);
  assert.ok(statSync(summary.path).size > 1024, 'showcase screenshot should not be empty');
});

function parseSummary(stdout) {
  const line = stdout.split('\n').find((entry) => entry.startsWith('SHOWCASE_SCREENSHOT_JSON '));
  assert.ok(line, `stdout should contain SHOWCASE_SCREENSHOT_JSON line:\n${stdout}`);
  return JSON.parse(line.slice('SHOWCASE_SCREENSHOT_JSON '.length));
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
