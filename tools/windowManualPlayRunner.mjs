import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';

const godotCandidates = [
  process.env.GODOT_BIN,
  'godot',
  'godot4',
  '/Applications/Godot.app/Contents/MacOS/Godot',
].filter(Boolean);

const godot = godotCandidates.find((candidate) => existsSync(candidate) || !candidate.includes('/'));
const WINDOW_MANUAL_TIMEOUT_MS = 45000;

if (!godot) {
  console.error('Godot executable should be available. Set GODOT_BIN if needed.');
  process.exit(1);
}

const child = spawn(godot, [
  '--path',
  '.',
  '--log-file',
  '/private/tmp/ecliptica-window-manual-play-probe.log',
  '--script',
  'scripts/window_manual_play_probe.gd',
], {
  cwd: process.cwd(),
  env: process.env,
});

let stdout = '';
let stderr = '';
let settled = false;
const timeout = setTimeout(() => {
  if (settled) return;
  settled = true;
  child.kill('SIGTERM');
  process.stdout.write(stdout);
  process.stderr.write(`${stderr}\nTimed out after ${WINDOW_MANUAL_TIMEOUT_MS}ms while waiting for window manual play probe.\n`);
  process.exit(1);
}, WINDOW_MANUAL_TIMEOUT_MS);

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
  console.error(String(error));
  process.exit(1);
});

child.on('close', (code) => {
  if (settled) return;
  settled = true;
  clearTimeout(timeout);
  process.stdout.write(stdout);
  const filteredStderr = stderr.replace(
    /ERROR: Condition "ret != noErr" is true\. Returning: ""\n\s+at: get_system_ca_certificates \(platform\/macos\/os_macos\.mm:\d+\)\n?/g,
    '',
  );
  if (filteredStderr.trim().length > 0) {
    process.stderr.write(filteredStderr);
  }
  process.exit(code ?? 1);
});
