import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const requiredAssets = [
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

test('asset style bible and manifest define the production replacement contract', () => {
  assert.equal(existsSync('assets/style-bible.md'), true);
  assert.equal(existsSync('assets/manifest.yaml'), true);
  assert.equal(existsSync('assets/production'), true);
  assert.equal(existsSync('assets/placeholder'), true);

  const styleBible = readFileSync('assets/style-bible.md', 'utf8');
  assert.match(styleBible, /解像度/);
  assert.match(styleBible, /線の太さ/);
  assert.match(styleBible, /色数/);
  assert.match(styleBible, /影の方向/);
  assert.match(styleBible, /キャラの比率/);
  assert.match(styleBible, /背景とのコントラスト/);
  assert.match(styleBible, /禁止表現/);
  assert.match(styleBible, /参考にする質感/);
  assert.match(styleBible, /コピーしてはいけない要素/);

  const manifest = parseManifest(readFileSync('assets/manifest.yaml', 'utf8'));
  for (const assetId of requiredAssets) {
    const entry = manifest.assets[assetId];
    assert.ok(entry, `${assetId} should exist in manifest`);
    assert.equal(entry.kind, 'production');
    assert.match(entry.path, /^res:\/\/assets\/production\//);
    assert.equal(existsSync(entry.path.replace(/^res:\/\//, '')), true, `${assetId} path should exist`);
    assert.ok(Array.isArray(entry.frame_size), `${assetId} should define frame_size`);
    assert.equal(typeof entry.frame_count, 'number', `${assetId} should define frame_count`);
    assert.ok('pivot' in entry, `${assetId} should define pivot`);
    assert.ok('baseline' in entry, `${assetId} should define baseline`);
    assert.ok('animation_fps' in entry, `${assetId} should define animation_fps`);
    assert.ok(Array.isArray(entry.required_states), `${assetId} should define required states`);
    assert.ok(Array.isArray(entry.replacement_checklist), `${assetId} should define replacement checklist`);
  }

  assert.deepEqual(manifest.assets.player_idle.frame_size, [192, 384]);
  assert.equal(manifest.assets.player_idle.frame_count, 10);
  assert.deepEqual(manifest.assets.player_walk.required_states, ['walk']);
  assert.deepEqual(manifest.assets.player_attack_body.required_states, ['attack1', 'attack2', 'attack3']);
  assert.equal(manifest.assets.player_axe_attack.animation_fps, 16);
  assert.deepEqual(manifest.assets.enemy_idle.frame_size, [192, 384]);
  assert.deepEqual(manifest.assets.boss_idle.frame_size, [256, 384]);
});

test('release asset check fails if active placeholders remain', () => {
  const passResult = spawnSync(process.execPath, ['tools/checkReleaseAssets.mjs'], {
    cwd: process.cwd(),
    encoding: 'utf8',
  });

  assert.equal(passResult.status, 0, passResult.stderr || passResult.stdout);
  assert.match(passResult.stdout, /"status":"pass"/);

  const tempDir = mkdtempSync(path.join(tmpdir(), 'ecliptica-asset-manifest-'));
  const tempManifest = path.join(tempDir, 'manifest.yaml');
  const placeholderManifest = readFileSync('assets/manifest.yaml', 'utf8')
    .replace('path: res://assets/production/player-idle-sheet-10.png', 'path: res://assets/placeholder/player-idle-sheet-10.png')
    .replace('kind: production', 'kind: placeholder');
  writeFileSync(tempManifest, placeholderManifest);

  const failResult = spawnSync(process.execPath, ['tools/checkReleaseAssets.mjs'], {
    cwd: process.cwd(),
    env: { ...process.env, ASSET_MANIFEST_PATH: tempManifest },
    encoding: 'utf8',
  });

  assert.notEqual(failResult.status, 0);
  assert.match(failResult.stderr, /player_idle still points to placeholder asset/);
});

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
