import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

const requiredFiles = [
  'project.godot',
  'scenes/main.tscn',
  'scenes/platform.tscn',
  'scenes/collectible.tscn',
  'scripts/game.gd',
  'scripts/roguelike_run.gd',
  'scripts/stage_generator.gd',
  'scripts/enemy.gd',
  'scripts/player.gd',
  'scripts/e2e_runner.gd',
  'scripts/window_e2e_runner.gd',
  'scripts/llm_verify.gd',
  'assets/background-city.png',
  'assets/axe-swing-sheet-8.png',
  'assets/enemy-idle-sheet-8.png',
  'assets/enemy-walk-sheet-12.png',
  'assets/enemy-attack-sheet-8.png',
  'assets/boss-idle-sheet-8.png',
  'assets/player-idle-sheet-10.png',
  'assets/player-walk-sheet-24.png',
  'assets/player-attack-combo-sheet-18.png',
  'assets/player-shoot-sheet-8.png',
  'docs/enemy-ideas.md',
  'docs/roguelike-plan.md',
];

test('Godot migration includes the required project files and imported assets', () => {
  for (const file of requiredFiles) {
    assert.equal(existsSync(file), true, `${file} should exist`);
  }
});

test('Godot project opens the migrated main scene', async () => {
  const project = await readFile('project.godot', 'utf8');

  assert.match(project, /config\/name="Ecliptica"/);
  assert.match(project, /run\/main_scene="res:\/\/scenes\/main\.tscn"/);
  assert.match(project, /config\/features=PackedStringArray\("4\./);
});

test('Godot project launches and renders at 1920x1080', async () => {
  const project = await readFile('project.godot', 'utf8');
  const readme = await readFile('README.md', 'utf8');
  const readSetting = (name) => {
    const match = project.match(new RegExp(`^${name}=(\\d+)$`, 'm'));
    return match ? Number(match[1]) : null;
  };

  assert.equal(readSetting('window/size/viewport_width'), 1920);
  assert.equal(readSetting('window/size/viewport_height'), 1080);
  assert.equal(readSetting('window/size/window_width_override'), 1920);
  assert.equal(readSetting('window/size/window_height_override'), 1080);
  assert.match(readme, /```bash\ngodot --path \.\n```/);
  assert.match(readme, /起動時は全画面/);
  assert.match(readme, /HP と FOCUS はバー/);
  assert.doesNotMatch(readme, /--resolution 1920x1080/);
});

test('main scene wires gameplay, generated stage, player animation, and E2E runner', async () => {
  const scene = await readFile('scenes/main.tscn', 'utf8');

  assert.match(scene, /script = ExtResource\("1_game"\)/);
  assert.match(scene, /StageGenerator/);
  assert.match(scene, /\[node name="Enemies" type="Node2D" parent="\."\]/);
  assert.match(scene, /\[node name="PlayerSprite" type="AnimatedSprite2D" parent="Player"\]/);
  assert.match(scene, /\[node name="AttackArc" type="AnimatedSprite2D" parent="Player"\]/);
  assert.match(scene, /\[node name="AttackHitbox" type="Area2D" parent="Player"\]/);
  assert.match(scene, /\[node name="Projectiles" type="Node2D" parent="\."\]/);
  assert.match(scene, /\[node name="TrainingDummy" type="Area2D" parent="." groups=\["attack_targets"\]\]/);
  assert.match(scene, /E2ERunner/);
  assert.match(scene, /Goal/);
  assert.doesNotMatch(scene, /\[node name="Ground1"/);
  assert.doesNotMatch(scene, /\[node name="Collectible1"/);
  assert.match(scene, /CollisionShape2D/);
  assert.match(scene, /zoom = Vector2\(1\.65, 1\.65\)/);
  assert.match(scene, /\[node name="HealthFill" type="ColorRect" parent="CanvasLayer\/HUDPanel\/HealthBar"\]/);
  assert.match(scene, /\[node name="FocusFill" type="ColorRect" parent="CanvasLayer\/HUDPanel\/FocusBar"\]/);
  assert.match(scene, /\[node name="SigilPips" type="HBoxContainer" parent="CanvasLayer\/HUDPanel"\]/);
  assert.match(scene, /position = Vector2\(-2, -68\)/);
  assert.match(scene, /scale = Vector2\(0\.3, 0\.3\)/);
});

test('Godot scripts expose the expected gameplay and E2E hooks', async () => {
  const game = await readFile('scripts/game.gd', 'utf8');
  const roguelike = await readFile('scripts/roguelike_run.gd', 'utf8');
  const generator = await readFile('scripts/stage_generator.gd', 'utf8');
  const enemy = await readFile('scripts/enemy.gd', 'utf8');
  const player = await readFile('scripts/player.gd', 'utf8');
  const enemyIdeas = await readFile('docs/enemy-ideas.md', 'utf8');
  const roguelikePlan = await readFile('docs/roguelike-plan.md', 'utf8');
  const e2e = await readFile('scripts/e2e_runner.gd', 'utf8');
  const windowE2e = await readFile('scripts/window_e2e_runner.gd', 'utf8');
  const llmVerify = await readFile('scripts/llm_verify.gd', 'utf8');
  const packageJson = JSON.parse(await readFile('package.json', 'utf8'));

  assert.match(game, /func collect_sigil/);
  assert.match(game, /func damage_player/);
  assert.match(game, /func retry_game/);
  assert.match(game, /func advance_to_next_stage/);
  assert.match(game, /func _complete_roguelike_stage/);
  assert.match(game, /ROGUELIKE_RUN_SCRIPT/);
  assert.match(game, /run_stage_index/);
  assert.match(game, /run_rewards/);
  assert.match(game, /pending_reward_choices/);
  assert.match(game, /func _update_camera/);
  assert.match(game, /func open_gate/);
  assert.match(game, /func win_game/);
  assert.match(game, /player_health/);
  assert.match(game, /PLAYER_MAX_HEALTH := 3/);
  assert.match(game, /GATE_SEALED_COLOR/);
  assert.match(game, /Input\.is_action_just_pressed\("retry"\)/);
  assert.match(game, /Input\.is_action_just_pressed\("next_stage"\)/);
  assert.match(game, /KEY_R/);
  assert.match(game, /KEY_N/);
  assert.match(game, /KEY_ENTER/);
  assert.match(game, /TARGET_WINDOW_SIZE := Vector2i\(1920, 1080\)/);
  assert.match(game, /CAMERA_ZOOM := Vector2\(1\.65, 1\.65\)/);
  assert.match(game, /DisplayServer\.WINDOW_MODE_FULLSCREEN/);
  assert.match(game, /func _update_hud_bars/);
  assert.match(game, /health_fill/);
  assert.match(game, /focus_fill/);
  assert.match(game, /sigil_pips/);
  assert.match(game, /DisplayServer\.window_set_size\(/);
  assert.match(game, /DisplayServer\.screen_get_scale/);
  assert.match(game, /generated_stage_summary/);
  assert.match(generator, /func generate_stage/);
  assert.match(generator, /ROOM_LIBRARY/);
  assert.match(generator, /CASTLE_LAYOUT_STYLE := "castle_keep"/);
  assert.match(generator, /VERTICAL_ROOM_COUNT := 3/);
  assert.match(generator, /SHORTCUT_COUNT := 1/);
  assert.match(generator, /LOCKED_GATE_COUNT := 1/);
  assert.match(generator, /CRITICAL_PATH_ROOM_COUNT := 6/);
  assert.match(generator, /chapel_balcony/);
  assert.match(generator, /library_landing/);
  assert.match(generator, /crypt_drop/);
  assert.match(generator, /bell_tower/);
  assert.match(generator, /gate_hall/);
  assert.match(generator, /layout_style/);
  assert.match(generator, /vertical_room_count/);
  assert.match(generator, /shortcut_count/);
  assert.match(generator, /locked_gate_count/);
  assert.match(generator, /critical_path_room_count/);
  assert.match(generator, /DEFAULT_STAGE_SEED := 1337/);
  assert.match(generator, /run_stage_index/);
  assert.match(generator, /curse_level/);
  assert.match(generator, /run_reward_count/);
  assert.match(generator, /stage_variant/);
  assert.match(generator, /elite_enemy_count/);
  assert.match(generator, /platform_count/);
  assert.match(generator, /sigil_count/);
  assert.match(generator, /enemy_count/);
  assert.match(generator, /boss_count/);
  assert.match(generator, /func _create_enemy/);
  assert.match(generator, /ENEMY_SCRIPT/);
  assert.match(generator, /enemy-walk-sheet-12\.png/);
  assert.match(generator, /enemy-attack-sheet-8\.png/);
  assert.match(generator, /configure_patrol/);
  assert.match(generator, /func _create_boss/);
  assert.match(generator, /enemy-idle-sheet-8\.png/);
  assert.match(generator, /boss-idle-sheet-8\.png/);
  assert.match(generator, /AnimatedSprite2D/);
  assert.match(generator, /hit_points/);
  assert.match(enemy, /extends Area2D/);
  assert.match(enemy, /func configure_patrol/);
  assert.match(enemy, /func _process/);
  assert.match(enemy, /PATROL_STATE := "walk"/);
  assert.match(enemy, /ATTACK_STATE := "attack"/);
  assert.match(enemy, /get_first_node_in_group\("player"\)/);
  assert.match(player, /func _physics_process/);
  assert.match(player, /add_to_group\("player"\)/);
  assert.match(player, /func _update_animation/);
  assert.match(player, /IDLE_FRAME_COUNT := 10/);
  assert.match(player, /WALK_FRAME_COUNT := 24/);
  assert.match(player, /ATTACK_FRAME_COUNT := 8/);
  assert.match(player, /ATTACK_BODY_FRAME_COUNT := 6/);
  assert.match(player, /COMBO_STEP_COUNT := 3/);
  assert.match(player, /SHOOT_FRAME_COUNT := 8/);
  assert.match(player, /player-idle-sheet-10\.png/);
  assert.match(player, /player-walk-sheet-24\.png/);
  assert.match(player, /player-attack-combo-sheet-18\.png/);
  assert.match(player, /player-shoot-sheet-8\.png/);
  assert.match(player, /axe-swing-sheet-8\.png/);
  assert.match(player, /func attack/);
  assert.match(player, /func _advance_combo_step/);
  assert.match(player, /func _play_attack_body_animation/);
  assert.match(player, /func is_shooting/);
  assert.match(player, /FOCUS_MAX := 3\.0/);
  assert.match(player, /FOCUS_REGEN_PER_SECOND/);
  assert.match(player, /SHOT_COST := 1\.0/);
  assert.match(player, /func shoot/);
  assert.match(player, /func e2e_shoot/);
  assert.match(player, /func can_shoot/);
  assert.match(player, /func _create_projectile/);
  assert.match(player, /func _damage_attack_target/);
  assert.match(player, /func e2e_attack/);
  assert.match(player, /func is_attacking/);
  assert.match(game, /shoot_focus/);
  assert.match(enemyIdeas, /Cathedral Ghoul/);
  assert.match(enemyIdeas, /巡回/);
  assert.match(enemyIdeas, /突進/);
  assert.match(enemyIdeas, /Bloodborne を直接コピーしない/);
  assert.match(roguelike, /class_name RoguelikeRun/);
  assert.match(roguelike, /REWARD_LIBRARY/);
  assert.match(roguelike, /func reward_choices_for/);
  assert.match(roguelike, /func select_reward/);
  assert.match(roguelike, /func stage_seed_for/);
  assert.match(roguelike, /blood_vial/);
  assert.match(roguelikePlan, /Run Loop/);
  assert.match(roguelikePlan, /報酬/);
  assert.match(roguelikePlan, /次ステージ/);
  assert.match(e2e, /func run_e2e/);
  assert.match(e2e, /retry should clear game over and restore health/);
  assert.match(e2e, /retry should regenerate enemies/);
  assert.match(e2e, /shoot should consume focus/);
  assert.match(e2e, /combo should advance through three attack body animations/);
  assert.match(e2e, /shoot body animation should become active/);
  assert.match(e2e, /focus should regenerate over time/);
  assert.match(e2e, /E2E_OK/);
  assert.equal(packageJson.scripts['test:window'], 'RUN_GODOT_WINDOW_E2E=1 node --test test/godotWindowE2E.test.mjs');
  assert.match(windowE2e, /func run_window_e2e/);
  assert.match(windowE2e, /DisplayServer\.screen_get_scale/);
  assert.match(windowE2e, /WINDOW_E2E_OK/);
  assert.match(llmVerify, /LLM_VERIFY_JSON/);
  assert.match(llmVerify, /llm_headless_verify/);
  assert.match(llmVerify, /ranged/);
});

test('player visuals flip sprites instead of scaling the physics body', async () => {
  const player = await readFile('scripts/player.gd', 'utf8');

  assert.doesNotMatch(player, /scale\.x\s*=/);
  assert.match(player, /flip_h/);
});

test('walk atlas frames have transparent gutters for Godot hframes slicing', () => {
  const result = spawnSync(process.execPath, ['test/walkAtlasCheck.mjs'], {
    cwd: process.cwd(),
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test('axe swing atlas follows the accessory animation contract', () => {
  const result = spawnSync(process.execPath, ['test/axeAttackAssetCheck.mjs'], {
    cwd: process.cwd(),
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test('enemy and boss atlases follow the actor animation contract', () => {
  const result = spawnSync(process.execPath, ['test/enemyBossAssetCheck.mjs'], {
    cwd: process.cwd(),
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test('player action atlases follow the body animation contract', () => {
  const result = spawnSync(process.execPath, ['test/playerActionAssetCheck.mjs'], {
    cwd: process.cwd(),
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr || result.stdout);
});
