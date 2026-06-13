import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';

test('manual play probe is exposed as a package script', async () => {
  const packageJson = JSON.parse(await readFile('package.json', 'utf8'));

  assert.equal(packageJson.scripts['playtest:manual'], 'node tools/manualPlayProbeRunner.mjs');
  assert.equal(existsSync('scripts/manual_play_probe.gd'), true, 'manual play Godot script should exist');
  assert.equal(existsSync('tools/manualPlayProbeRunner.mjs'), true, 'manual play runner should exist');
});

test('manual play probe runs held input and saves evidence screenshots', async () => {
  const result = await run('npm', ['run', 'playtest:manual']);
  const summary = await parseSummary(result.stdout);

  assert.equal(result.code, 0, result.stderr || result.stdout);
  assert.equal(summary.mode, 'manual_play_probe');
  assert.equal(summary.status, 'pass');
  assert.equal(summary.input_model, 'held_e2e_player_inputs');
  assert.equal(summary.direct_damage_used, false);
  assert.equal(summary.stage.seed, 1337);
  assert.ok(Array.isArray(summary.route_log));
  assert.ok(summary.route_log.some((entry) => entry.phase === 'movement' && entry.held_frames > 20));
  assert.ok(summary.route_log.some((entry) => entry.phase === 'first_enemy'));
  assert.ok(summary.route_log.some((entry) => entry.phase === 'attack'));
  assert.match(summary.run_id, /^\d{8}-\d{6}-manual-play$/);
  assert.equal(existsSync(summary.evidence_dir), true, 'run-specific evidence dir should exist');
  assert.equal(existsSync(summary.summary_path), true, 'summary.json should exist');
  assert.equal(existsSync(summary.timeline_path), true, 'timeline.json should exist');
  assert.equal(existsSync(summary.frame_sequence_path), true, 'frame sequence json should exist');
  assert.equal(existsSync(summary.capture_diagnostics_path), true, 'capture diagnostics json should exist');
  assert.equal(summary.verdict.status, 'pass');
  assert.ok(summary.verdict.reason.length > 0);
  assert.deepEqual(Object.keys(summary.state_map_legend).sort(), ['attack', 'boss', 'enemy', 'gate', 'player', 'sigil'].sort());
  for (const entry of Object.values(summary.state_map_legend)) {
    assert.match(entry.color, /^#[0-9a-f]{6}$/i);
    assert.ok(entry.label.length > 0);
  }
  assert.ok(Array.isArray(summary.frame_sequence));
  assert.ok(summary.frame_sequence.length >= 10);
  assert.ok(summary.frame_sequence.some((frame) => frame.label.includes('attack-active')));
  assert.ok(summary.frame_sequence.some((frame) => frame.label.includes('hit') || frame.label.includes('miss')));
  for (const frame of summary.frame_sequence) {
    assert.equal(existsSync(frame.path), true, `${frame.path} should exist`);
  }
  assert.ok(['available', 'unavailable'].includes(summary.capture_diagnostics.status));
  assert.ok(summary.capture_diagnostics.method.length > 0);
  assert.ok(summary.ui_evidence.objective_text.includes('Collect'));
  assert.ok(summary.ui_evidence.sigil_text.includes('Sigils'));
  assert.ok(Array.isArray(summary.timeline));
  assert.ok(summary.timeline.length >= 6);
  assert.ok(summary.timeline.some((entry) => entry.phase === 'movement' && entry.input.axis === 1));
  assert.ok(summary.timeline.some((entry) => entry.phase === 'attack' && typeof entry.attack.active === 'boolean'));
  assert.ok(summary.timeline.some((entry) => entry.enemy && typeof entry.enemy.distance_to_player === 'number'));
  assert.deepEqual(summary.scenario_names, [
    'first_enemy_approach_attack',
    'attack_while_moving',
    'jump_buffer_or_coyote',
    'enemy_lunge_tell',
    'boss_three_hits',
  ]);
  assert.equal(summary.scenarios.length, summary.scenario_names.length);
  for (const scenario of summary.scenarios) {
    assert.equal(summary.scenario_names.includes(scenario.name), true);
    assert.equal(scenario.status, 'pass', `${scenario.name} should pass`);
    assert.equal(existsSync(scenario.timeline_path), true, `${scenario.name} timeline should exist`);
    assert.ok(Array.isArray(scenario.timeline));
    assert.ok(scenario.timeline.length > 0, `${scenario.name} should include timeline entries`);
    assert.ok(scenario.verdict.reason.length > 0, `${scenario.name} should include a verdict reason`);
  }
  const movingAttack = summary.scenarios.find((scenario) => scenario.name === 'attack_while_moving');
  assert.ok(movingAttack.timeline.some((entry) => entry.phase === 'attack_while_moving' && entry.input.axis === 1));
  const jumpScenario = summary.scenarios.find((scenario) => scenario.name === 'jump_buffer_or_coyote');
  assert.equal(typeof jumpScenario.metrics.jump_velocity_after_input, 'number');
  assert.equal(jumpScenario.metrics.buffered_jump_triggered, true);
  assert.ok(jumpScenario.metrics.jump_velocity_after_input < -100);
  const lungeScenario = summary.scenarios.find((scenario) => scenario.name === 'enemy_lunge_tell');
  assert.ok(lungeScenario.timeline.some((entry) => entry.enemy && entry.enemy.state === 'windup'));
  const bossScenario = summary.scenarios.find((scenario) => scenario.name === 'boss_three_hits');
  assert.equal(typeof bossScenario.metrics.hits_landed, 'number');
  assert.ok(summary.screenshots.length >= 2);
  for (const screenshot of summary.screenshots) {
    assert.equal(existsSync(screenshot.path), true, `${screenshot.path} should exist`);
    assert.ok(screenshot.path.includes(summary.evidence_dir), 'screenshots should be scoped to the run evidence dir');
    assert.ok(screenshot.width > 0);
    assert.ok(screenshot.height > 0);
  }

  const persistedSummary = JSON.parse(await readFile(summary.summary_path, 'utf8'));
  assert.equal(persistedSummary.run_id, summary.run_id);
  assert.equal(persistedSummary.timeline_path, summary.timeline_path);

  const persistedTimeline = JSON.parse(await readFile(summary.timeline_path, 'utf8'));
  assert.deepEqual(persistedTimeline, summary.timeline);
});

async function parseSummary(stdout) {
  const line = stdout.split('\n').find((entry) => entry.startsWith('MANUAL_PLAY_JSON '));
  assert.ok(line, `stdout should contain MANUAL_PLAY_JSON line:\n${stdout}`);
  const stdoutSummary = JSON.parse(line.slice('MANUAL_PLAY_JSON '.length));
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
