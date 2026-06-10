import { existsSync } from 'node:fs';
import { spawn } from 'node:child_process';

const candidates = [
  process.env.GODOT_BIN,
  'godot',
  'godot4',
  '/Applications/Godot.app/Contents/MacOS/Godot',
].filter(Boolean);

const godot = candidates.find((candidate) => existsSync(candidate) || !candidate.includes('/'));

if (!godot) {
  console.error('Godot executable not found. Set GODOT_BIN=/path/to/godot or install Godot 4.6.x.');
  process.exit(1);
}

const child = spawn(godot, ['--path', '.'], {
  cwd: process.cwd(),
  env: process.env,
  stdio: 'inherit',
});

child.on('error', (error) => {
  console.error(String(error));
  process.exit(1);
});

child.on('close', (code) => {
  process.exit(code ?? 0);
});
