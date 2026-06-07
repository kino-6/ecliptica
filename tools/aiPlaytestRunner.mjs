import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';

const godotCandidates = [
  process.env.GODOT_BIN,
  'godot',
  'godot4',
  '/Applications/Godot.app/Contents/MacOS/Godot',
].filter(Boolean);

const godot = godotCandidates.find((candidate) => existsSync(candidate) || !candidate.includes('/'));

if (!godot) {
  console.error('Godot executable should be available. Set GODOT_BIN if needed.');
  process.exit(1);
}

const child = spawn(godot, [
  '--headless',
  '--path',
  '.',
  '--log-file',
  '/private/tmp/ecliptica-ai-playtest.log',
  '--script',
  'scripts/ai_playtest.gd',
], {
  cwd: process.cwd(),
  env: process.env,
});

let stdout = '';
let stderr = '';

child.stdout.on('data', (chunk) => {
  stdout += chunk;
});

child.stderr.on('data', (chunk) => {
  stderr += chunk;
});

child.on('error', (error) => {
  console.error(String(error));
  process.exit(1);
});

child.on('close', (code) => {
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
