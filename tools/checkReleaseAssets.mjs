import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

const MANIFEST_PATH = process.env.ASSET_MANIFEST_PATH ?? 'assets/manifest.yaml';
const REQUIRED_ASSETS = [
  'background_city',
  'showcase_backdrop',
  'platform_stone_tile',
  'player_idle',
  'player_walk',
  'player_attack_body',
  'player_shoot_body',
  'player_axe_idle',
  'player_axe_walk',
  'player_axe_attack',
  'player_axe_shoot',
  'player_shot_vfx',
  'hit_spark',
  'enemy_idle',
  'enemy_walk',
  'enemy_attack',
  'boss_idle',
  'sigil_relic',
  'gate_sealed',
  'gate_open',
  'training_reliquary',
];

const manifest = parseManifest(readFileSync(MANIFEST_PATH, 'utf8'));
const failures = [];

for (const assetId of REQUIRED_ASSETS) {
  const entry = manifest.assets[assetId];
  if (!entry) {
    failures.push(`${assetId} is missing from ${MANIFEST_PATH}`);
    continue;
  }
  const assetPath = String(entry.path ?? '');
  const kind = String(entry.kind ?? '');
  if (kind === 'placeholder' || assetPath.includes('/placeholder/')) {
    failures.push(`${assetId} still points to placeholder asset: ${assetPath}`);
  }
  if (!assetPath.includes('/production/')) {
    failures.push(`${assetId} should point to assets/production: ${assetPath}`);
  }
  const localPath = assetPath.replace(/^res:\/\//, '');
  if (!existsSync(localPath)) {
    failures.push(`${assetId} file does not exist: ${localPath}`);
  }
  if (!Array.isArray(entry.replacement_checklist) || entry.replacement_checklist.length === 0) {
    failures.push(`${assetId} needs a replacement_checklist`);
  }
}

if (!existsSync('assets/style-bible.md')) {
  failures.push('assets/style-bible.md should exist');
}

if (failures.length > 0) {
  console.error(`RELEASE_ASSET_CHECK failed:\n${failures.map((failure) => `- ${failure}`).join('\n')}`);
  process.exit(1);
}

console.log(JSON.stringify({
  status: 'pass',
  manifest: path.resolve(MANIFEST_PATH),
  checked_assets: REQUIRED_ASSETS.length,
}));

function parseManifest(text) {
  const result = { assets: {} };
  let section = '';
  let currentAsset = '';

  for (const rawLine of text.split('\n')) {
    const line = stripComment(rawLine);
    if (line.trim().length === 0) continue;
    const indent = line.length - line.trimStart().length;
    const trimmed = line.trim();
    if (indent === 0) {
      if (trimmed.endsWith(':')) {
        section = trimmed.slice(0, -1);
        currentAsset = '';
      }
      continue;
    }
    if (section !== 'assets') continue;
    if (indent === 2 && trimmed.endsWith(':')) {
      currentAsset = trimmed.slice(0, -1);
      result.assets[currentAsset] = {};
      continue;
    }
    if (indent >= 4 && currentAsset) {
      const pair = splitPair(trimmed);
      if (pair) result.assets[currentAsset][pair.key] = pair.value;
    }
  }

  return result;
}

function stripComment(line) {
  const index = line.indexOf('#');
  return index >= 0 ? line.slice(0, index) : line;
}

function splitPair(line) {
  const index = line.indexOf(':');
  if (index < 0) return null;
  return {
    key: line.slice(0, index).trim(),
    value: parseValue(line.slice(index + 1).trim()),
  };
}

function parseValue(value) {
  if (value === 'null') return null;
  if (value.startsWith('[') && value.endsWith(']')) {
    const inner = value.slice(1, -1).trim();
    if (!inner) return [];
    return inner.split(',').map((item) => parseScalar(item.trim()));
  }
  return parseScalar(value);
}

function parseScalar(value) {
  if (/^-?\d+$/.test(value)) return Number(value);
  if (/^-?\d+\.\d+$/.test(value)) return Number(value);
  return value.replace(/^"|"$/g, '');
}
