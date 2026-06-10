import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';

test('AI playtest mode is documented as a package script and skill', async () => {
  const packageJson = JSON.parse(await readFile('package.json', 'utf8'));

  assert.equal(packageJson.scripts['playtest:ai'], 'node tools/aiPlaytestRunner.mjs');
  assert.equal(existsSync('scripts/ai_playtest.gd'), true, 'scripts/ai_playtest.gd should exist');
  assert.equal(existsSync('tools/aiPlaytestRunner.mjs'), true, 'tools/aiPlaytestRunner.mjs should exist');
  assert.equal(existsSync('.agents/skills/headless-ai-playtest/SKILL.md'), true, 'headless AI playtest skill should exist');
});

test('AI playtest mode evaluates five human-limited skill profiles', async () => {
  const result = await run('npm', ['run', 'playtest:ai']);
  const summary = parseSummary(result.stdout);

  assert.equal(summary.mode, 'ai_headless_playtest');
  assert.equal(summary.stage.game_rev, '0.1.0-dev');
  assert.equal(summary.stage.display_seed, 1337);
  assert.match(summary.stage.run_info_text, /GAME REV 0\.1\.0-dev/);
  assert.match(summary.stage.run_info_text, /SEED 1337/);
  assert.equal(summary.stage.seed, 1337);
  assert.equal(summary.stage.layout_style, 'sanctuary_rogue_wing');
  assert.ok(summary.stage.room_count >= 7);
  assert.ok(summary.stage.branch_room_count >= 2);
  assert.equal(summary.stage.shortcut_count, 1);
  assert.equal(summary.stage.floating_platform_count, 0);
  assert.equal(summary.stage.critical_path_reachable, true);
  assert.ok(summary.stage.max_required_step_up <= 96);
  assert.equal(summary.stage.impossible_jump_count, 0);
  assert.equal(summary.stage.enemy_spawn_grounded, true);
  assert.equal(summary.stage.enemy_spawn_overlap_count, 0);
  assert.equal(summary.stage.enemy_spawn_out_of_floor_count, 0);
  assert.equal(summary.stage.boss_spawn_grounded, true);
  assert.equal(summary.stage.platform_count, summary.stage.room_count);
  assert.equal(summary.stage.balance.pacing, 'first_stage_two_try');
  assert.equal(summary.parallel.strategy, 'auto_machine_fit');
  assert.equal(typeof summary.parallel.available_parallelism, 'number');
  assert.equal(typeof summary.parallel.total_memory_gb, 'number');
  assert.equal(typeof summary.parallel.selected_workers, 'number');
  assert.equal(typeof summary.parallel.total_elapsed_ms, 'number');
  assert.ok(summary.parallel.available_parallelism >= 1);
  assert.ok(summary.parallel.selected_workers >= Math.min(2, summary.parallel.available_parallelism, 5));
  assert.ok(summary.parallel.selected_workers <= 5);
  assert.ok(summary.parallel.total_elapsed_ms > 0);
  assert.equal(result.code, 0, result.stderr || result.stdout);
  assert.equal(summary.status, 'pass');
  assert.equal(summary.profiles.length, 5);
  assert.deepEqual(summary.profiles.map((profile) => profile.name), ['novice', 'casual', 'adept', 'expert', 'master']);

  for (const profile of summary.profiles) {
    assert.equal(typeof profile.worker_index, 'number');
    assert.equal(typeof profile.elapsed_ms, 'number');
    assert.ok(profile.worker_index >= 0);
    assert.ok(profile.elapsed_ms > 0);
    assert.equal(typeof profile.human_reaction_ms, 'number');
    assert.ok(profile.human_reaction_ms >= 120, 'profiles should include plausible human reaction constraints');
    assert.equal(typeof profile.action_interval_ms, 'number');
    assert.ok(profile.action_interval_ms >= profile.human_reaction_ms);
    assert.equal(typeof profile.predicted_attempts_to_clear, 'number');
    assert.equal(typeof profile.cleared, 'boolean');
    assert.ok(Array.isArray(profile.route_log));
    assert.ok(profile.route_log.length >= 4);
  }

  const novice = summary.profiles.find((profile) => profile.name === 'novice');
  const adept = summary.profiles.find((profile) => profile.name === 'adept');
  const expert = summary.profiles.find((profile) => profile.name === 'expert');
  const master = summary.profiles.find((profile) => profile.name === 'master');

  assert.equal(novice.cleared, false);
  assert.equal(novice.predicted_attempts_to_clear > 2, true);
  assert.equal(adept.cleared, true);
  assert.equal(adept.predicted_attempts_to_clear, 2);
  assert.equal(expert.cleared, true);
  assert.equal(master.cleared, true);
  assert.equal(summary.recommendation, 'stage matches the two-try target for an adept action player');
});

function parseSummary(stdout) {
  const line = stdout.split('\n').find((entry) => entry.startsWith('AI_PLAYTEST_JSON '));
  assert.ok(line, `stdout should contain AI_PLAYTEST_JSON line:\n${stdout}`);
  return JSON.parse(line.slice('AI_PLAYTEST_JSON '.length));
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
