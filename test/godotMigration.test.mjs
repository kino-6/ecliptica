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
  'scripts/asset_manifest.gd',
  'scripts/roguelike_run.gd',
  'scripts/stage_generator.gd',
  'scripts/enemy.gd',
  'scripts/player.gd',
  'scripts/e2e_runner.gd',
  'scripts/window_e2e_runner.gd',
  'scripts/llm_verify.gd',
  'scripts/showcase_screenshot.gd',
  'assets/background-city.png',
  'assets/style-bible.md',
  'assets/manifest.yaml',
  '.agents/skills/weapon-vfx-quality-gate/SKILL.md',
  '.agents/skills/weapon-vfx-quality-gate/agents/openai.yaml',
  'assets/platform-stone-tile.png',
  'assets/production/showcase-room-backdrop.png',
  'assets/player-shot-sheet-6.png',
  'assets/production/hit-spark-sheet-4.png',
  'assets/sigil-relic.png',
  'assets/gate-sealed.png',
  'assets/gate-open.png',
  'assets/training-reliquary.png',
  'tools/runGodotGame.mjs',
  'tools/checkReleaseAssets.mjs',
  'tools/showcaseScreenshotRunner.mjs',
  'tools/stabilizePlayerWalkSheet.py',
  'tools/generateStageVisualAssets.py',
  'tools/generatePlayerAxeSheets.py',
  'assets/source/player-axe-source-key.png',
  'assets/source/player-axe-source.png',
  'assets/player-axe-idle-sheet-10.png',
  'assets/player-axe-walk-sheet-24.png',
  'assets/player-axe-attack-combo-sheet-24.png',
  'assets/player-axe-shoot-sheet-8.png',
  'assets/enemy-idle-sheet-8.png',
  'assets/enemy-walk-sheet-12.png',
  'assets/enemy-attack-sheet-8.png',
  'assets/boss-idle-sheet-8.png',
  'assets/player-idle-sheet-10.png',
  'assets/player-walk-sheet-24.png',
  'assets/player-attack-combo-sheet-24.png',
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
  assert.match(project, /config\/version="0\.1\.0-dev"/);
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
  assert.match(readme, /```bash\nnpm run start\n```/);
  assert.doesNotMatch(readme, /```bash\ngodot --path \.\n```/);
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
  assert.match(scene, /\[node name="AxeSprite" type="AnimatedSprite2D" parent="Player"\]/);
  assert.match(scene, /\[node name="AxeSprite" type="AnimatedSprite2D" parent="Player"\]\nz_index = 9\nposition = Vector2\(-2, -68\)\nscale = Vector2\(0\.3, 0\.3\)/);
  assert.doesNotMatch(scene, /\[node name="AttackArc"/);
  assert.match(scene, /\[node name="AttackHitbox" type="Area2D" parent="Player"\]/);
  assert.match(scene, /\[node name="AttackHitbox" type="Area2D" parent="Player"\]\nposition = Vector2\(76, -48\)/);
  assert.match(scene, /\[node name="Projectiles" type="Node2D" parent="\."\]/);
  assert.match(scene, /\[node name="TrainingDummy" type="Area2D" parent="." groups=\["attack_targets"\]\]/);
  assert.match(scene, /\[node name="Visual" type="Sprite2D" parent="TrainingDummy"\]/);
  assert.match(scene, /\[node name="GateVisual" type="Sprite2D" parent="Goal"\]/);
  assert.match(scene, /E2ERunner/);
  assert.match(scene, /Goal/);
  assert.doesNotMatch(scene, /\[node name="Ground1"/);
  assert.doesNotMatch(scene, /\[node name="Collectible1"/);
  assert.match(scene, /CollisionShape2D/);
  assert.match(scene, /zoom = Vector2\(2\.2, 2\.2\)/);
  assert.match(scene, /\[node name="HealthFill" type="ColorRect" parent="CanvasLayer\/HUDPanel\/HealthBar"\]/);
  assert.match(scene, /\[node name="FocusFill" type="ColorRect" parent="CanvasLayer\/HUDPanel\/FocusBar"\]/);
  assert.match(scene, /\[node name="SigilPips" type="HBoxContainer" parent="CanvasLayer\/HUDPanel"\]/);
  assert.match(scene, /\[node name="RunInfoLabel" type="Label" parent="CanvasLayer"\]/);
  assert.match(scene, /horizontal_alignment = 2/);
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
  assert.match(game, /func _apply_contact_damage/);
  assert.match(game, /func _apply_fall_damage/);
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
  assert.match(game, /ASSET_MANIFEST_SCRIPT := preload\("res:\/\/scripts\/asset_manifest\.gd"\)/);
  assert.match(game, /BACKGROUND_ASSET_ID := "background_city"/);
  assert.match(game, /GATE_SEALED_ASSET_ID := "gate_sealed"/);
  assert.match(game, /GATE_OPEN_ASSET_ID := "gate_open"/);
  assert.match(game, /TRAINING_DUMMY_ASSET_ID := "training_reliquary"/);
  assert.match(game, /PLACEHOLDER ASSET|placeholder_assets|has_placeholder_assets/);
  assert.match(game, /func _configure_static_sprites/);
  assert.match(game, /Input\.is_action_just_pressed\("retry"\)/);
  assert.match(game, /Input\.is_action_just_pressed\("next_stage"\)/);
  assert.match(game, /KEY_R/);
  assert.match(game, /KEY_N/);
  assert.match(game, /KEY_ENTER/);
  assert.match(game, /TARGET_WINDOW_SIZE := Vector2i\(1920, 1080\)/);
  assert.match(game, /CAMERA_ZOOM := Vector2\(2\.2, 2\.2\)/);
  assert.match(game, /CAMERA_LOOKAHEAD_X := 96\.0/);
  assert.match(game, /CAMERA_VERTICAL_DEADZONE := 74\.0/);
  assert.match(game, /CAMERA_IMPULSE_PIXELS := 10\.0/);
  assert.match(game, /func request_camera_impulse/);
  assert.match(game, /GAME_REV_FALLBACK := "0\.1\.0-dev"/);
  assert.match(game, /run_info_label/);
  assert.match(game, /func game_revision/);
  assert.match(game, /func current_display_seed/);
  assert.match(game, /func _update_run_info/);
  assert.match(game, /DisplayServer\.WINDOW_MODE_FULLSCREEN/);
  assert.match(game, /func _update_hud_bars/);
  assert.match(game, /health_fill/);
  assert.match(game, /focus_fill/);
  assert.match(game, /sigil_pips/);
  assert.match(game, /DisplayServer\.window_set_size\(/);
  assert.match(game, /DisplayServer\.screen_get_scale/);
  assert.match(game, /generated_stage_summary/);
  assert.match(generator, /func generate_stage/);
  assert.match(generator, /ROOM_GRAPH/);
  assert.match(generator, /STAGE_LAYOUT_STYLE := "sanctuary_rogue_wing"/);
  assert.match(generator, /VERTICAL_ROOM_COUNT := 3/);
  assert.match(generator, /SHORTCUT_COUNT := 1/);
  assert.match(generator, /LOCKED_GATE_COUNT := 1/);
  assert.match(generator, /CRITICAL_PATH_ROOM_COUNT := 6/);
  assert.match(generator, /BRANCH_ROOM_COUNT := 2/);
  assert.match(generator, /FLOATING_PLATFORM_COUNT := 0/);
  assert.match(generator, /PLAYER_MAX_STEP_UP := 96\.0/);
  assert.match(generator, /ENEMY_SPAWN_SLOTS/);
  assert.match(generator, /BOSS_SPAWN_SLOT/);
  assert.match(generator, /TRAVERSAL_EDGES/);
  assert.match(generator, /entrance_sanctuary/);
  assert.match(generator, /gatehouse_hall/);
  assert.match(generator, /upper_chapel/);
  assert.match(generator, /ossuary_cache/);
  assert.match(generator, /crypt_descent/);
  assert.match(generator, /shortcut_bell_stair/);
  assert.match(generator, /sealed_nave_boss/);
  assert.match(generator, /layout_style/);
  assert.match(generator, /room_count/);
  assert.match(generator, /vertical_room_count/);
  assert.match(generator, /shortcut_count/);
  assert.match(generator, /locked_gate_count/);
  assert.match(generator, /critical_path_room_count/);
  assert.match(generator, /branch_room_count/);
  assert.match(generator, /floating_platform_count/);
  assert.match(generator, /critical_path_reachable/);
  assert.match(generator, /max_required_step_up/);
  assert.match(generator, /impossible_jump_count/);
  assert.match(generator, /enemy_spawn_grounded/);
  assert.match(generator, /enemy_spawn_overlap_count/);
  assert.match(generator, /enemy_spawn_out_of_floor_count/);
  assert.match(generator, /boss_spawn_grounded/);
  assert.match(generator, /showcase_room_floor_segments/);
  assert.match(generator, /showcase_enemy_count/);
  assert.match(generator, /showcase_has_backdrop/);
  assert.match(generator, /DEFAULT_STAGE_SEED := 1337/);
  assert.match(generator, /ASSET_MANIFEST_SCRIPT := preload\("res:\/\/scripts\/asset_manifest\.gd"\)/);
  assert.match(generator, /PLATFORM_TILE_ASSET_ID := "platform_stone_tile"/);
  assert.match(generator, /SHOWCASE_BACKDROP_ASSET_ID := "showcase_backdrop"/);
  assert.match(generator, /SIGIL_ASSET_ID := "sigil_relic"/);
  assert.match(generator, /FileAccess\.get_file_as_bytes\(path\)/);
  assert.match(generator, /load_png_from_buffer/);
  assert.doesNotMatch(generator, /image\.load\(path\)/);
  assert.match(generator, /func _create_room_shell/);
  assert.match(generator, /func _validate_stage_geometry/);
  assert.match(generator, /func _spawn_position_from_slot/);
  assert.match(generator, /func _spawn_slot_is_inside_floor/);
  assert.match(generator, /func _add_room_floor_tiles/);
  assert.match(generator, /BackWall/);
  assert.match(generator, /Connectors/);
  assert.match(generator, /VisualTiles/);
  assert.match(generator, /WallVisuals/);
  assert.doesNotMatch(generator, /WallCollision/);
  assert.match(generator, /run_stage_index/);
  assert.match(generator, /curse_level/);
  assert.match(generator, /run_reward_count/);
  assert.match(generator, /stage_variant/);
  assert.match(generator, /elite_enemy_count/);
  assert.match(generator, /platform_count/);
  assert.match(generator, /sigil_count/);
  assert.match(generator, /enemy_count/);
  assert.match(generator, /standard_enemy_count/);
  assert.match(generator, /boss_count/);
  assert.match(generator, /func _create_enemy/);
  assert.match(generator, /ENEMY_SCRIPT/);
  assert.match(generator, /ENEMY_IDLE_ASSET_ID := "enemy_idle"/);
  assert.match(generator, /ENEMY_WALK_ASSET_ID := "enemy_walk"/);
  assert.match(generator, /ENEMY_ATTACK_ASSET_ID := "enemy_attack"/);
  assert.match(generator, /configure_patrol/);
  assert.match(generator, /func _create_boss/);
  assert.match(generator, /BOSS_ASSET_ID := "boss_idle"/);
  assert.match(generator, /AnimatedSprite2D/);
  assert.match(generator, /hit_points/);
  assert.match(enemy, /extends Area2D/);
  assert.match(enemy, /func configure_patrol/);
  assert.match(enemy, /func _physics_process/);
  assert.match(enemy, /GRAVITY :=/);
  assert.match(enemy, /intersect_ray/);
  assert.match(enemy, /PATROL_STATE := "walk"/);
  assert.match(enemy, /ATTACK_STATE := "attack"/);
  assert.match(enemy, /func _can_move_to_x/);
  assert.match(enemy, /func _has_floor_at/);
  assert.match(enemy, /func apply_hit_reaction/);
  assert.match(enemy, /get_first_node_in_group\("player"\)/);
  assert.match(player, /func _physics_process/);
  assert.match(player, /add_to_group\("player"\)/);
  assert.match(player, /func _update_animation/);
  assert.match(player, /IDLE_FRAME_COUNT := 10/);
  assert.match(player, /WALK_FRAME_COUNT := 24/);
  assert.match(player, /ATTACK_BODY_FRAME_COUNT := 8/);
  assert.match(player, /COMBO_STEP_COUNT := 3/);
  assert.match(player, /SHOOT_FRAME_COUNT := 8/);
  assert.match(player, /IDLE_ASSET_ID := "player_idle"/);
  assert.match(player, /WALK_ASSET_ID := "player_walk"/);
  assert.match(player, /ATTACK_BODY_ASSET_ID := "player_attack_body"/);
  assert.match(player, /SHOOT_ASSET_ID := "player_shoot_body"/);
  assert.match(player, /AXE_IDLE_ASSET_ID := "player_axe_idle"/);
  assert.match(player, /AXE_WALK_ASSET_ID := "player_axe_walk"/);
  assert.match(player, /AXE_ATTACK_ASSET_ID := "player_axe_attack"/);
  assert.match(player, /AXE_SHOOT_ASSET_ID := "player_axe_shoot"/);
  assert.match(player, /@onready var axe_sprite: AnimatedSprite2D = \$AxeSprite/);
  assert.match(player, /func _setup_axe_animations/);
  assert.match(player, /ASSET_MANIFEST_SCRIPT := preload\("res:\/\/scripts\/asset_manifest\.gd"\)/);
  assert.match(player, /SHOT_ASSET_ID := "player_shot_vfx"/);
  assert.match(player, /SHOT_VFX_FRAME_COUNT := 6/);
  assert.match(player, /SHOT_FRAME_SIZE := Vector2i\(160, 72\)/);
  assert.match(player, /FileAccess\.get_file_as_bytes\(path\)/);
  assert.match(player, /load_png_from_buffer/);
  assert.doesNotMatch(player, /image\.load\(path\)/);
  assert.doesNotMatch(player, /axe-swing-sheet-8\.png/);
  assert.doesNotMatch(player, /const ATTACK_TEXTURE :=/);
  assert.match(player, /ATTACK_ANIMATION_FPS := 16\.0/);
  assert.match(player, /ATTACK_STARTUP_FRAMES := 4/);
  assert.match(player, /ATTACK_ACTIVE_FRAME_START := 4/);
  assert.match(player, /ATTACK_ACTIVE_FRAME_END := 5/);
  assert.match(player, /ATTACK_RECOVERY_FRAMES := 2/);
  assert.match(player, /ATTACK_ACTIVE_START := 0\.25/);
  assert.match(player, /ATTACK_ACTIVE_END := 0\.375/);
  assert.match(player, /ATTACK_HITBOX_OFFSETS := \[/);
  assert.match(player, /Vector2\(48, -82\), Vector2\(68, -50\)/);
  assert.match(player, /ATTACK_HITBOX_SIZES := \[/);
  assert.match(player, /Vector2\(96, 78\), Vector2\(112, 86\)/);
  assert.match(player, /AXE_ATTACK_SCALE := Vector2\(0\.46, 0\.46\)/);
  assert.match(player, /ATTACK_MOVE_SPEED_SCALE := 0\.18/);
  assert.match(player, /HITSTOP_IMPACT_FRAMES := 5/);
  assert.match(player, /HIT_SPARK_ASSET_ID := "hit_spark"/);
  assert.doesNotMatch(player, /attack_arc/);
  assert.match(player, /func _sync_attack_geometry/);
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
  assert.match(player, /AnimatedSprite2D\.new\(\)/);
  assert.match(player, /func _build_projectile_sprite_frames/);
  assert.match(player, /func _damage_attack_target/);
  assert.match(player, /func _apply_hit_feedback/);
  assert.match(player, /func _spawn_hit_spark/);
  assert.match(player, /func apply_damage_knockback/);
  assert.match(player, /KNOCKBACK_DURATION := 0\.24/);
  assert.match(player, /KNOCKBACK_VELOCITY := Vector2\(360, -260\)/);
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
  assert.match(e2e, /animated gunshot VFX sheet/);
  assert.match(e2e, /combo should advance through three attack body animations/);
  assert.match(e2e, /dedicated image-based axe animation/);
  assert.match(e2e, /attack should not use a separate drawn arc object/);
  assert.match(e2e, /attack should use the image-based axe layer scale contract/);
  assert.match(e2e, /combo should advance through three dedicated axe animations/);
  assert.match(e2e, /shoot body animation should become active/);
  assert.match(e2e, /focus should regenerate over time/);
  assert.match(e2e, /E2E_OK/);
  assert.equal(packageJson.scripts.start, 'node tools/runGodotGame.mjs');
  assert.equal(packageJson.scripts.game, 'node tools/runGodotGame.mjs');
  assert.equal(packageJson.scripts['test:window'], 'RUN_GODOT_WINDOW_E2E=1 node --test test/godotWindowE2E.test.mjs');
  assert.equal(packageJson.scripts['screenshot:showcase'], 'node tools/showcaseScreenshotRunner.mjs');
  assert.equal(packageJson.scripts['release:check'], 'node tools/checkReleaseAssets.mjs');
  assert.match(windowE2e, /func run_window_e2e/);
  assert.match(windowE2e, /DisplayServer\.screen_get_scale/);
  assert.match(windowE2e, /WINDOW_E2E_OK/);
  assert.match(llmVerify, /LLM_VERIFY_JSON/);
  assert.match(llmVerify, /llm_headless_verify/);
  assert.match(llmVerify, /run_info_text/);
  assert.match(llmVerify, /attack_startup_frames/);
  assert.match(llmVerify, /hitstop_triggered/);
  assert.match(llmVerify, /enemy_hit_flash_triggered/);
  assert.match(llmVerify, /dedicated image-based axe animation/);
  assert.match(llmVerify, /ranged/);
  assert.match(llmVerify, /projectile_visual_is_animated/);
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

test('player axe atlases follow the dedicated image accessory contract', () => {
  const result = spawnSync(process.execPath, ['test/playerAxeAssetCheck.mjs'], {
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
