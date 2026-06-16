import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';

test('window manual play evidence mode is exposed as a package script', async () => {
  const packageJson = JSON.parse(await readFile('package.json', 'utf8'));

  assert.equal(packageJson.scripts['playtest:window-manual'], 'node tools/windowManualPlayRunner.mjs');
  assert.equal(existsSync('scripts/window_manual_play_probe.gd'), true, 'window manual Godot script should exist');
  assert.equal(existsSync('tools/windowManualPlayRunner.mjs'), true, 'window manual runner should exist');
});

test('window manual play captures real non-headless viewport evidence', { skip: process.env.RUN_GODOT_WINDOW_MANUAL !== '1' }, async () => {
  const result = await run('npm', ['run', 'playtest:window-manual']);
  const summary = await parseSummary(result.stdout);

  assert.equal(result.code, 0, result.stderr || result.stdout);
  assert.equal(summary.mode, 'window_manual_play_probe');
  assert.equal(summary.status, 'pass');
  assert.notEqual(summary.display_name, 'headless');
  assert.equal(summary.input_model, 'held_e2e_player_inputs');
  assert.equal(summary.direct_damage_used, false);
  assert.deepEqual(summary.scenario_names, ['first_enemy', 'first_sigil', 'boss_reveal']);
  assert.ok(summary.window.content_scale_size.x >= 1280);
  assert.ok(summary.window.content_scale_size.y >= 720);
  assert.equal(existsSync(summary.summary_path), true, 'summary.json should exist');
  assert.equal(summary.ui_evidence.boss_hp_visible, false);
  assert.ok(summary.ui_evidence.sigil_text.includes('Sigils'));
  assert.ok(summary.ui_evidence.sigil_text.includes('NEXT'));
  assert.ok(summary.ui_evidence.state_text.includes('SEALED'));
  assert.ok(summary.ui_evidence.state_text.includes('SIGILS'));
  assert.ok(summary.ui_evidence.objective_text.includes('Collect'));
  assert.ok(summary.screenshots.length >= 6);
  assert.equal(summary.hit_evidence.attack_active_captured, true);
  assert.equal(summary.hit_evidence.hit_frame_captured, true);
  assert.equal(summary.hit_evidence.follow_through_captured, true);
  assert.equal(summary.hit_evidence.hit_spark_visible, true);
  assert.equal(summary.hit_evidence.enemy_reaction_visible, true);
  assert.equal(summary.sigil_evidence.next_sigil_visible, true);
  assert.equal(summary.sigil_evidence.pickup_captured, true);
  assert.equal(summary.sigil_evidence.sigils_collected_after, 1);
  assert.equal(summary.boss_evidence.boss_hp_visible, true);
  assert.equal(summary.boss_evidence.boss_found, true);
  assert.equal(summary.boss_evidence.contact_damage_captured, true);
  assert.ok(summary.boss_evidence.player_damage_taken >= 1);
  assert.ok(summary.boss_evidence.contact_knockback_max_displacement_x <= 72);
  assert.ok(summary.boss_evidence.contact_knockback_max_velocity_x >= 80);
  assert.ok(summary.boss_evidence.contact_knockback_control_recovery_frames > 0);
  assert.ok(summary.boss_evidence.contact_knockback_control_recovery_frames <= 18);
  assert.equal(summary.windup_evidence.windup_frame_captured, true);
  assert.match(summary.windup_evidence.windup_direction, /^(left|right)$/);
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-attack-start'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-attack-active'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-hit-frame'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-hit-spark'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-attack-follow-through'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-after_first_enemy'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-next-sigil-visible'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-after_sigil_pickup'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-boss-hp-visible'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-boss-contact-damage'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-enemy-windup'));
  assert.ok(summary.screenshots.some((shot) => shot.label === 'window-after_attack'));
  for (const screenshot of summary.screenshots) {
    assert.equal(existsSync(screenshot.path), true, `${screenshot.path} should exist`);
    assert.ok(screenshot.width > 0);
    assert.ok(screenshot.height > 0);
  }
  assert.ok(summary.route_log.some((entry) => entry.phase === 'movement' && entry.moved_by > 20));
  assert.ok(summary.route_log.some((entry) => entry.phase === 'attack' && entry.hit === true));
});

async function parseSummary(stdout) {
  const line = stdout.split('\n').find((entry) => entry.startsWith('WINDOW_MANUAL_PLAY_JSON '));
  assert.ok(line, `stdout should contain WINDOW_MANUAL_PLAY_JSON line:\n${stdout}`);
  const stdoutSummary = JSON.parse(line.slice('WINDOW_MANUAL_PLAY_JSON '.length));
  assert.equal(existsSync(stdoutSummary.summary_path), true, 'stdout summary_path should exist');
  return JSON.parse(await readFile(stdoutSummary.summary_path, 'utf8'));
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
