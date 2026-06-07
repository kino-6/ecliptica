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
  assert.equal(summary.stage.layout_style, 'castle_keep');
  assert.equal(summary.stage.vertical_room_count, 3);
  assert.equal(summary.stage.shortcut_count, 1);
  assert.equal(summary.stage.locked_gate_count, 1);
  assert.equal(summary.stage.critical_path_room_count, 6);
  assert.equal(summary.stage.sigil_count, 6);
  assert.ok(summary.stage.enemy_count >= 3);
  assert.ok(summary.stage.platform_count >= 7);
  assert.equal(summary.balance.target_clear_attempts, 2);
  assert.equal(summary.balance.expected_clear_attempts, 2);
  assert.ok(summary.balance.risk_score >= 7, 'first stage should not be trivial');
  assert.ok(summary.balance.risk_score <= 10, 'first stage should stay fair for a skilled player');
  assert.equal(summary.balance.health_buffer_hits, 2);
  assert.equal(summary.balance.focus_shots_available, 3);
  assert.equal(summary.balance.branch_challenge_count, 2);
  assert.equal(summary.balance.combat_encounter_count, 4);
  assert.equal(summary.balance.boss_hit_points, 3);
  assert.equal(summary.balance.recovery_window_count >= 2, true);
  assert.equal(summary.balance.pacing, 'first_stage_two_try');
  assert.equal(summary.enemy.has_ai_script, true);
  assert.ok(summary.enemy.patrol_moved_by >= 6);
  assert.ok(['walk', 'attack'].includes(summary.enemy.animation_after_patrol));
  assert.equal(summary.camera.followed_player, true);
  assert.ok(summary.player.moved_right_by >= 40);
  assert.equal(summary.player.health_after_damage, 2);
  assert.equal(summary.player.stayed_in_place_after_damage, true);
  assert.equal(summary.player.damage_invulnerability_started, true);
  assert.equal(summary.player.knockback_applied, true);
  assert.equal(summary.player.health_after_invulnerable_hit, 2);
  assert.equal(summary.attack.available, true);
  assert.equal(summary.attack.animation_seen, true);
  assert.equal(summary.attack.hitbox_enabled_during_attack, true);
  assert.equal(summary.attack.arc_hitbox_aligned_right, true);
  assert.equal(summary.attack.arc_hitbox_aligned_left, true);
  assert.deepEqual(summary.attack.arc_position_right, { x: 62, y: -36 });
  assert.deepEqual(summary.attack.hitbox_position_right, { x: 62, y: -36 });
  assert.deepEqual(summary.attack.arc_position_left, { x: -62, y: -36 });
  assert.deepEqual(summary.attack.hitbox_position_left, { x: -62, y: -36 });
  assert.deepEqual(summary.attack.arc_scale, { x: 0.72, y: 0.56 });
  assert.equal(summary.attack.training_dummy_destroyed, true);
  assert.equal(summary.ranged.available, true);
  assert.equal(summary.ranged.projectile_spawned, true);
  assert.equal(summary.ranged.enemy_destroyed_by_shot, true);
  assert.equal(summary.ranged.focus_after_shot, 2);
  assert.ok(summary.ranged.focus_after_regen > summary.ranged.focus_after_shot);
  assert.equal(summary.combat.enemy_destroyed_by_attack, true);
  assert.equal(summary.gameplay.gate_open_after_collecting_sigils, true);
  assert.equal(summary.gameplay.win_state_reached, true);
  assert.equal(summary.gameplay.stage_playable_path, true);
  assert.equal(summary.roguelike.initial_stage_index, 1);
  assert.equal(summary.roguelike.reward_granted_after_win, true);
  assert.equal(summary.roguelike.selected_reward_id, 'blood_vial');
  assert.equal(summary.roguelike.max_health_after_reward, 4);
  assert.equal(summary.roguelike.advanced_to_stage_index, 2);
  assert.notEqual(summary.roguelike.next_stage_seed, 1337);
  assert.equal(summary.roguelike.reward_count_after_advance, 1);
  assert.equal(summary.roguelike.next_stage_variant, 'moonlit_cloister');
  assert.equal(summary.retry.game_over_before_retry, true);
  assert.equal(summary.retry.game_over_after_retry, false);
  assert.equal(summary.retry.health_after_retry, 3);
  assert.equal(summary.retry.sigils_after_retry, 0);
  assert.equal(summary.retry.gate_open_after_retry, false);
  assert.equal(summary.retry.enemy_count_after_retry, 4);
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
