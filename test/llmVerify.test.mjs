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
  assert.equal(packageJson.scripts['screenshot:showcase'], 'node tools/showcaseScreenshotRunner.mjs');
  assert.equal(existsSync('scripts/llm_verify.gd'), true, 'scripts/llm_verify.gd should exist');
  assert.equal(existsSync('tools/llmVerifyRunner.mjs'), true, 'tools/llmVerifyRunner.mjs should exist');
  assert.equal(existsSync('scripts/showcase_screenshot.gd'), true, 'scripts/showcase_screenshot.gd should exist');
  assert.equal(existsSync('tools/showcaseScreenshotRunner.mjs'), true, 'tools/showcaseScreenshotRunner.mjs should exist');
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
  assert.equal(summary.stage.game_rev, '0.1.0-dev');
  assert.equal(summary.stage.display_seed, 1337);
  assert.match(summary.stage.run_info_text, /GAME REV 0\.1\.0-dev/);
  assert.match(summary.stage.run_info_text, /SEED 1337/);
  assert.equal(summary.stage.seed, 1337);
  assert.equal(summary.stage.layout_style, 'sanctuary_rogue_wing');
  assert.ok(summary.stage.room_count >= 7);
  assert.equal(summary.stage.vertical_room_count, 3);
  assert.equal(summary.stage.shortcut_count, 1);
  assert.equal(summary.stage.locked_gate_count, 1);
  assert.equal(summary.stage.critical_path_room_count, 6);
  assert.ok(summary.stage.branch_room_count >= 2);
  assert.equal(summary.stage.floating_platform_count, 0);
  assert.equal(summary.stage.critical_path_reachable, true);
  assert.ok(summary.stage.max_required_step_up <= 96);
  assert.equal(summary.stage.impossible_jump_count, 0);
  assert.equal(summary.stage.enemy_spawn_grounded, true);
  assert.equal(summary.stage.enemy_spawn_overlap_count, 0);
  assert.equal(summary.stage.enemy_spawn_out_of_floor_count, 0);
  assert.equal(summary.stage.boss_spawn_grounded, true);
  assert.ok(summary.stage.showcase_room_floor_segments >= 3);
  assert.equal(summary.stage.showcase_enemy_count, 1);
  assert.equal(summary.stage.showcase_has_backdrop, true);
  assert.equal(summary.stage.sigil_count, 7);
  assert.ok(summary.stage.enemy_count >= 3);
  assert.equal(summary.stage.platform_count, summary.stage.room_count);
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
  assert.equal(summary.visuals.platform_flat_rect_hidden, true);
  assert.equal(summary.visuals.platform_tiles_present, true);
  assert.equal(summary.visuals.room_back_wall_present, true);
  assert.equal(summary.visuals.showcase_backdrop_present, true);
  assert.equal(summary.visuals.showcase_debug_back_wall_hidden, true);
  assert.equal(summary.visuals.room_connectors_present, true);
  assert.equal(summary.visuals.blocking_wall_collision_count, 0);
  assert.equal(summary.visuals.sigil_uses_sprite, true);
  assert.equal(summary.visuals.gate_uses_sprite, true);
  assert.equal(summary.visuals.training_dummy_uses_sprite, true);
  assert.equal(summary.visuals.enemy_frame_height, 384);
  assert.equal(summary.visuals.boss_frame_height, 384);
  assert.equal(summary.enemy.has_ai_script, true);
  assert.ok(summary.enemy.patrol_moved_by >= 6);
  assert.ok(summary.enemy.patrol_fell_by <= 8);
  assert.ok(['walk', 'attack'].includes(summary.enemy.animation_after_patrol));
  assert.equal(summary.camera.followed_player, true);
  assert.ok(summary.camera.lookahead_x >= 80);
  assert.ok(summary.camera.lookahead_x <= 110);
  assert.deepEqual(summary.camera.zoom, { x: 2.2, y: 2.2 });
  assert.ok(summary.camera.visible_world_width <= 900);
  assert.ok(summary.player.moved_right_by >= 40);
  assert.equal(summary.player.health_after_damage, 2);
  assert.equal(summary.player.stayed_in_place_after_damage, true);
  assert.equal(summary.player.damage_invulnerability_started, true);
  assert.equal(summary.player.knockback_applied, true);
  assert.equal(summary.player.health_after_invulnerable_hit, 2);
  assert.equal(summary.attack.available, true);
  assert.equal(summary.attack.animation_seen, true);
  assert.equal(summary.attack.hitbox_enabled_during_attack, true);
  assert.equal(summary.attack.uses_legacy_attack_arc, false);
  assert.deepEqual(summary.attack.axe_attack_scale, { x: 0.46, y: 0.46 });
  assert.equal(summary.attack.startup_frames, 4);
  assert.deepEqual(summary.attack.active_frames, [4, 5]);
  assert.equal(summary.attack.recovery_frames, 2);
  assert.deepEqual(summary.attack.active_frames_seen, [4, 5]);
  assert.equal(summary.attack.illegal_startup_active, false);
  assert.equal(summary.attack.illegal_recovery_active, false);
  assert.equal(summary.attack.hitstop_triggered, true);
  assert.equal(summary.attack.enemy_hp_after_hit, 1);
  assert.equal(summary.attack.enemy_hit_flash_triggered, true);
  assert.equal(summary.attack.enemy_hit_knockback_triggered, true);
  assert.equal(summary.attack.hit_spark_spawned, true);
  assert.equal(summary.attack.camera_impulse_triggered, true);
  assert.deepEqual(summary.attack.hitbox_position_right, { x: 78, y: -50 });
  assert.deepEqual(summary.attack.hitbox_position_left, { x: -78, y: -50 });
  assert.deepEqual(summary.attack.hitbox_size_right, { x: 136, y: 92 });
  assert.deepEqual(summary.attack.active_hitbox_samples.map((sample) => sample.frame), [4, 5]);
  assert.equal(summary.attack.training_dummy_destroyed, true);
  assert.equal(summary.feel.move_max_speed, 210);
  assert.equal(summary.feel.ground_acceleration, 1180);
  assert.equal(summary.feel.ground_deceleration, 1560);
  assert.equal(summary.feel.air_acceleration, 620);
  assert.equal(summary.feel.air_deceleration, 430);
  assert.equal(summary.feel.jump_velocity, -620);
  assert.equal(summary.feel.landing_recovery_seconds, 0.1);
  assert.equal(summary.feel.attack_move_speed_scale, 0.24);
  assert.equal(summary.feel.attack_startup_frames, 4);
  assert.deepEqual(summary.feel.attack_active_frames, [4, 5]);
  assert.equal(summary.feel.attack_recovery_frames, 2);
  assert.equal(summary.feel.hitstop_glancing_frames, 3);
  assert.equal(summary.feel.hitstop_impact_frames, 5);
  assert.equal(summary.feel.camera_lookahead_x, 96);
  assert.equal(summary.feel.camera_impulse_pixels, 10);
  assert.equal(summary.ranged.available, true);
  assert.equal(summary.ranged.projectile_spawned, true);
  assert.equal(summary.ranged.projectile_visual_is_animated, true);
  assert.equal(summary.ranged.projectile_vfx_frame_count, 6);
  assert.deepEqual(summary.ranged.projectile_vfx_sheet_size, { x: 960, y: 72 });
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
