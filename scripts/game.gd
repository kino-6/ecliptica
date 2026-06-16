extends Node2D

const LEVEL_HEIGHT := 540.0
const TARGET_WINDOW_SIZE := Vector2i(1920, 1080)
const CAMERA_ZOOM := Vector2(2.2, 2.2)
const HUD_BAR_WIDTH := 240.0
const PLAYER_MAX_HEALTH := 3
const DAMAGE_INVULNERABILITY := 0.75
const CAMERA_Y := 500.0
const CAMERA_LOOKAHEAD_X := 96.0
const CAMERA_VERTICAL_DEADZONE := 74.0
const CAMERA_VERTICAL_FOLLOW := 0.18
const CAMERA_IMPULSE_DURATION := 0.16
const CAMERA_IMPULSE_PIXELS := 10.0
const GATE_FEEDBACK_DURATION := 1.4
const SIGIL_CUE_PULSE_FPS := 1.4
const BOSS_HEALTH_BAR_WIDTH := 400.0
const BOSS_HEALTH_REVEAL_MARGIN := 96.0
const GATE_SEALED_COLOR := Color(0.08, 0.09, 0.13, 0.82)
const GATE_OPEN_COLOR := Color(0.55, 0.08, 0.13, 0.82)
const ASSET_MANIFEST_SCRIPT := preload("res://scripts/asset_manifest.gd")
const BACKGROUND_ASSET_ID := "background_city"
const GATE_SEALED_ASSET_ID := "gate_sealed"
const GATE_OPEN_ASSET_ID := "gate_open"
const TRAINING_DUMMY_ASSET_ID := "training_reliquary"
const BASE_RUN_SEED := 1337
const GAME_REV_FALLBACK := "0.1.0-dev"
const ROGUELIKE_RUN_SCRIPT := preload("res://scripts/roguelike_run.gd")

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var gate: Area2D = $Goal
@onready var gate_visual: Sprite2D = $Goal/GateVisual
@onready var training_dummy_visual: Sprite2D = $TrainingDummy/Visual
@onready var health_fill: ColorRect = $CanvasLayer/HUDPanel/HealthBar/HealthFill
@onready var focus_fill: ColorRect = $CanvasLayer/HUDPanel/FocusBar/FocusFill
@onready var sigil_pips: HBoxContainer = $CanvasLayer/HUDPanel/SigilPips
@onready var sigil_count_label: Label = $CanvasLayer/HUDPanel/SigilCountLabel
@onready var state_label: Label = $CanvasLayer/HUDPanel/StateLabel
@onready var run_info_label: Label = $CanvasLayer/RunInfoLabel
@onready var tutorial_label: Label = $CanvasLayer/TutorialLabel
@onready var boss_health_panel: Control = $CanvasLayer/BossHealthPanel
@onready var boss_health_fill: ColorRect = $CanvasLayer/BossHealthPanel/BossHealthBack/BossHealthFill
@onready var boss_health_label: Label = $CanvasLayer/BossHealthPanel/BossHealthLabel
@onready var stage_generator: Node = $StageGenerator
@onready var background: Sprite2D = $Background

var sigils_total := 0
var sigils_collected := 0
var gate_open := false
var won := false
var game_over := false
var player_health := PLAYER_MAX_HEALTH
var player_max_health := PLAYER_MAX_HEALTH
var damage_invulnerability_timer := 0.0
var generated_stage_summary := {}
var run_model: RefCounted = ROGUELIKE_RUN_SCRIPT.new()
var run_seed := BASE_RUN_SEED
var run_stage_index := 1
var run_curse_level := 0
var run_rewards := []
var pending_reward_choices := []
var selected_reward := {}
var gate_sealed_texture: Texture2D
var gate_open_texture: Texture2D
var training_dummy_texture: Texture2D
var background_texture: Texture2D
var asset_manifest
var camera_impulse_timer := 0.0
var camera_impulse_strength := 0.0
var gate_feedback_timer := 0.0

func _ready() -> void:
	_apply_window_size()
	RenderingServer.set_default_clear_color(Color(0.025, 0.028, 0.032, 1.0))
	camera.zoom = CAMERA_ZOOM
	_load_runtime_textures()
	_ensure_input_actions()
	_generate_stage()
	_configure_background()
	_configure_static_sprites()
	_connect_collectibles()
	_connect_enemies()
	_update_camera()
	_update_hud()

func _process(delta: float) -> void:
	if game_over and Input.is_action_just_pressed("retry"):
		retry_game()
		return
	if won and Input.is_action_just_pressed("next_stage"):
		advance_to_next_stage()
		return
	damage_invulnerability_timer = maxf(damage_invulnerability_timer - delta, 0.0)
	camera_impulse_timer = maxf(camera_impulse_timer - delta, 0.0)
	gate_feedback_timer = maxf(gate_feedback_timer - delta, 0.0)
	if player.global_position.y > LEVEL_HEIGHT + 80.0:
		damage_player()
	_update_player_damage_feedback()
	_update_sigil_world_cues()
	_update_camera()
	_update_hud()

func collect_sigil(sigil: Area2D) -> void:
	if sigil == null or sigil.get_meta("collected", false):
		return

	sigil.set_meta("collected", true)
	sigil.visible = false
	sigil.set_deferred("monitoring", false)
	sigils_collected += 1
	if sigils_collected >= sigils_total:
		open_gate()
	_update_hud()

func open_gate() -> void:
	gate_open = true
	gate_feedback_timer = GATE_FEEDBACK_DURATION
	gate_visual.texture = gate_open_texture
	gate_visual.modulate = GATE_OPEN_COLOR
	request_camera_impulse(0.42)
	_update_hud()

func damage_player(source: Node = null) -> void:
	if won or game_over or damage_invulnerability_timer > 0.0:
		return
	player_health = maxi(player_health - 1, 0)
	damage_invulnerability_timer = DAMAGE_INVULNERABILITY
	if source == null:
		_apply_fall_damage()
	else:
		_apply_contact_damage(source)
	if player_health <= 0:
		game_over = true
	_update_hud()

func _apply_contact_damage(source: Node) -> void:
	if source is Node2D:
		player.apply_damage_knockback((source as Node2D).global_position)
	else:
		player.apply_damage_knockback(player.global_position + Vector2(-1.0, 0.0))

func _apply_fall_damage() -> void:
	player.reset_to_spawn()
	_update_camera()

func win_game() -> void:
	if not gate_open or game_over or won:
		return
	won = true
	_complete_roguelike_stage()
	_update_hud()

func advance_to_next_stage() -> bool:
	if not won:
		return false
	run_stage_index += 1
	pending_reward_choices = []
	selected_reward = {}
	_start_stage()
	return true

func retry_game() -> void:
	_start_stage()

func _start_stage() -> void:
	_reset_run_state()
	_clear_projectiles()
	_generate_stage()
	_connect_collectibles()
	_connect_enemies()
	_reset_player_for_stage()
	_reset_gate_visual()
	_refresh_stage_view()

func _connect_collectibles() -> void:
	var sigils := get_tree().get_nodes_in_group("sigils")
	sigils_total = sigils.size()
	for sigil in sigils:
		sigil.set_meta("collected", false)
		sigil.body_entered.connect(_on_sigil_body_entered.bind(sigil))
	var goal_callback := Callable(self, "_on_goal_body_entered")
	if not gate.body_entered.is_connected(goal_callback):
		gate.body_entered.connect(goal_callback)

func _connect_enemies() -> void:
	for enemy: Area2D in get_tree().get_nodes_in_group("enemies"):
		enemy.set_meta("destroyed", false)
		enemy.body_entered.connect(_on_enemy_body_entered.bind(enemy))

func _on_sigil_body_entered(body: Node, sigil: Area2D) -> void:
	if body == player:
		collect_sigil(sigil)

func _on_enemy_body_entered(body: Node, enemy: Area2D) -> void:
	if body == player and not enemy.get_meta("destroyed", false):
		damage_player(enemy)

func _on_goal_body_entered(body: Node) -> void:
	if body == player:
		win_game()

func _update_hud() -> void:
	_update_hud_bars()
	_update_sigil_pips()
	_update_boss_health()
	_update_tutorial()
	_update_run_info()
	var gate_text := "OPEN" if gate_open else "SEALED"
	if not gate_open:
		gate_text = "SEALED %d SIGILS" % [maxi(sigils_total - sigils_collected, 0)]
	if gate_feedback_timer > 0.0:
		gate_text = "GATE OPEN"
	var reward_text := ""
	if won and not selected_reward.is_empty():
		reward_text = " / %s" % [String(selected_reward.get("label", ""))]
	var win_text := " / WON%s / N TO DESCEND" % [reward_text] if won else ""
	var state_text := " / GAME OVER / R TO RETRY" if game_over else win_text
	state_label.text = "RUN %d / %s%s" % [run_stage_index, gate_text, state_text]

func _update_run_info() -> void:
	var text := "GAME REV %s\nSEED %d" % [game_revision(), current_display_seed()]
	if asset_manifest != null and asset_manifest.has_placeholder_assets():
		text += "\n%s" % [asset_manifest.warning_text]
	run_info_label.text = text

func game_revision() -> String:
	return String(ProjectSettings.get_setting("application/config/version", GAME_REV_FALLBACK))

func current_display_seed() -> int:
	if generated_stage_summary.has("seed"):
		return int(generated_stage_summary["seed"])
	return run_model.stage_seed_for(run_seed, run_stage_index)

func request_camera_impulse(strength: float) -> void:
	camera_impulse_timer = CAMERA_IMPULSE_DURATION
	camera_impulse_strength = clampf(strength, 0.0, 1.0)

func _update_player_damage_feedback() -> void:
	if damage_invulnerability_timer <= 0.0 or game_over:
		player.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	var flash := int(damage_invulnerability_timer * 18.0) % 2 == 0
	player.modulate = Color(1.0, 0.78, 0.78, 0.72 if flash else 1.0)

func _update_hud_bars() -> void:
	var health_ratio := clampf(float(player_health) / float(player_max_health), 0.0, 1.0)
	var focus_ratio := clampf(player.shoot_focus / player.FOCUS_MAX, 0.0, 1.0)
	health_fill.offset_right = HUD_BAR_WIDTH * health_ratio
	focus_fill.offset_right = HUD_BAR_WIDTH * focus_ratio

func _update_sigil_pips() -> void:
	while sigil_pips.get_child_count() < sigils_total:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16.0, 16.0)
		sigil_pips.add_child(pip)
	for index in range(sigil_pips.get_child_count()):
		var pip: ColorRect = sigil_pips.get_child(index)
		pip.visible = index < sigils_total
		pip.color = Color(0.72, 0.08, 0.13, 0.96) if index < sigils_collected else Color(0.10, 0.08, 0.09, 0.78)
	sigil_count_label.text = "Sigils %d/%d%s" % [sigils_collected, sigils_total, _next_sigil_direction_text()]

func _next_sigil_direction_text() -> String:
	if gate_open or sigils_collected >= sigils_total:
		return ""
	var sigil := _nearest_uncollected_sigil()
	if sigil == null:
		return ""
	var delta_x := sigil.global_position.x - player.global_position.x
	if absf(delta_x) <= 36.0:
		return " / NEXT HERE"
	return " / NEXT >" if delta_x > 0.0 else " / NEXT <"

func _nearest_uncollected_sigil() -> Area2D:
	var nearest: Area2D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("sigils"):
		var sigil := node as Area2D
		if sigil == null or bool(sigil.get_meta("collected", false)):
			continue
		var distance := sigil.global_position.distance_squared_to(player.global_position)
		if distance < nearest_distance:
			nearest = sigil
			nearest_distance = distance
	return nearest

func _update_sigil_world_cues() -> void:
	var nearest := _nearest_uncollected_sigil()
	var pulse := (sin(Time.get_ticks_msec() / 1000.0 * TAU * SIGIL_CUE_PULSE_FPS) + 1.0) * 0.5
	for node in get_tree().get_nodes_in_group("sigils"):
		var sigil := node as Area2D
		if sigil == null:
			continue
		var collected := bool(sigil.get_meta("collected", false))
		var glow := sigil.get_node_or_null("Glow") as Sprite2D
		var visual := sigil.get_node_or_null("Visual") as Sprite2D
		var is_nearest := sigil == nearest and not collected
		sigil.set_meta("next_cue_visible", is_nearest)
		if glow != null:
			glow.visible = not collected
			if is_nearest:
				var cue_scale := 1.04 + pulse * 0.22
				glow.scale = Vector2(cue_scale, cue_scale)
				glow.modulate = Color(1.0, 0.35, 0.14, 0.42 + pulse * 0.24)
				glow.z_index = 8
			else:
				glow.scale = Vector2(0.92, 0.92)
				glow.modulate = Color(1.0, 0.24, 0.16, 0.16)
				glow.z_index = 5
		if visual != null:
			visual.modulate = Color(1.30, 1.12 + pulse * 0.10, 0.94, 1.0) if is_nearest else Color(1.22, 1.04, 0.92, 1.0)

func _update_tutorial() -> void:
	tutorial_label.visible = run_stage_index == 1 and sigils_collected == 0 and not won and not game_over

func _update_boss_health() -> void:
	var boss: Area2D = _current_boss()
	if boss == null or bool(boss.get_meta("destroyed", false)) or not _should_show_boss_health(boss):
		boss_health_panel.visible = false
		return
	var max_hp := maxi(1, int(boss.get_meta("max_hit_points", 1)))
	var current_hp := clampi(int(boss.get_meta("hit_points", max_hp)), 0, max_hp)
	var ratio := clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	boss_health_panel.visible = true
	boss_health_fill.offset_right = BOSS_HEALTH_BAR_WIDTH * ratio
	boss_health_label.text = "BOSS %d/%d" % [current_hp, max_hp]

func _current_boss() -> Area2D:
	for node in get_tree().get_nodes_in_group("bosses"):
		var boss := node as Area2D
		if boss != null:
			return boss
	return null

func _should_show_boss_health(boss: Area2D) -> bool:
	if boss == null:
		return false
	var visible_half_width := TARGET_WINDOW_SIZE.x / (2.0 * CAMERA_ZOOM.x)
	return absf(boss.global_position.x - camera.global_position.x) <= visible_half_width + BOSS_HEALTH_REVEAL_MARGIN

func _ensure_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_W, KEY_UP, KEY_SPACE])
	_add_key_action("attack", [KEY_J, KEY_K, KEY_X])
	_add_key_action("shoot", [KEY_L, KEY_C, KEY_V])
	_add_key_action("retry", [KEY_R, KEY_ENTER])
	_add_key_action("next_stage", [KEY_N, KEY_ENTER])

func _add_key_action(action_name: StringName, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode in keys:
		var exists := false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey and event.physical_keycode == keycode:
				exists = true
		if not exists:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action_name, event)

func _apply_window_size() -> void:
	var window := get_window()
	window.size = TARGET_WINDOW_SIZE
	window.content_scale_size = TARGET_WINDOW_SIZE
	if DisplayServer.get_name() == "headless":
		return
	var physical_window_size := _target_physical_window_size()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(physical_window_size)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	window.size = physical_window_size
	window.content_scale_size = TARGET_WINDOW_SIZE

func _target_physical_window_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return TARGET_WINDOW_SIZE
	var screen := DisplayServer.window_get_current_screen()
	var scale := maxf(DisplayServer.screen_get_scale(screen), 1.0)
	return Vector2i(ceili(TARGET_WINDOW_SIZE.x * scale), ceili(TARGET_WINDOW_SIZE.y * scale))

func _generate_stage() -> void:
	stage_generator.stage_seed = run_model.stage_seed_for(run_seed, run_stage_index)
	stage_generator.run_seed = run_seed
	stage_generator.run_stage_index = run_stage_index
	stage_generator.curse_level = run_curse_level
	stage_generator.run_reward_count = run_rewards.size()
	generated_stage_summary = stage_generator.generate_stage(self)
	player.spawn_position = player.global_position

func _configure_background() -> void:
	background.texture = background_texture
	background.centered = true
	background.position = Vector2(1420.0, 540.0)
	background.scale = Vector2(2.85, 1.22)
	background.z_index = -100

func _configure_static_sprites() -> void:
	gate_visual.texture = gate_sealed_texture
	gate_visual.scale = Vector2(0.74, 0.74)
	gate_visual.z_index = 7
	gate_visual.modulate = GATE_SEALED_COLOR
	training_dummy_visual.texture = training_dummy_texture
	training_dummy_visual.position = Vector2(0, -4)
	training_dummy_visual.scale = Vector2(0.76, 0.76)
	training_dummy_visual.z_index = 4

func _load_runtime_textures() -> void:
	asset_manifest = ASSET_MANIFEST_SCRIPT.new()
	asset_manifest.load_from_file()
	background_texture = _load_asset_texture(BACKGROUND_ASSET_ID)
	gate_sealed_texture = _load_asset_texture(GATE_SEALED_ASSET_ID)
	gate_open_texture = _load_asset_texture(GATE_OPEN_ASSET_ID)
	training_dummy_texture = _load_asset_texture(TRAINING_DUMMY_ASSET_ID)

func _load_asset_texture(asset_id: String) -> Texture2D:
	return _load_png_texture(asset_manifest.texture_path(asset_id))

func _load_png_texture(path: String) -> Texture2D:
	var image := Image.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	var error := image.load_png_from_buffer(bytes)
	if error != OK:
		push_error("Failed to load game texture: %s" % [path])
		return null
	return ImageTexture.create_from_image(image)

func _reset_run_state() -> void:
	sigils_total = 0
	sigils_collected = 0
	gate_open = false
	won = false
	game_over = false
	player_health = player_max_health
	damage_invulnerability_timer = 0.0

func _clear_projectiles() -> void:
	var projectiles := get_node_or_null("Projectiles")
	if projectiles == null:
		return
	for projectile in projectiles.get_children():
		projectile.free()

func _reset_player_for_stage() -> void:
	player.reset_to_spawn()
	player.shoot_focus = player.FOCUS_MAX

func _reset_gate_visual() -> void:
	gate_visual.texture = gate_sealed_texture
	gate_visual.modulate = GATE_SEALED_COLOR

func _refresh_stage_view() -> void:
	_update_camera()
	_update_hud()

func _complete_roguelike_stage() -> void:
	pending_reward_choices = run_model.reward_choices_for(run_stage_index, run_seed)
	selected_reward = run_model.select_reward(pending_reward_choices)
	if selected_reward.is_empty():
		return
	run_rewards.append(String(selected_reward.get("id", "")))
	player_max_health += int(selected_reward.get("max_health_bonus", 0))
	run_curse_level += int(selected_reward.get("curse", 0))
	player_health = player_max_health
	player.shoot_focus = player.FOCUS_MAX

func _update_camera() -> void:
	var half_width := TARGET_WINDOW_SIZE.x / (2.0 * CAMERA_ZOOM.x)
	var max_x := maxf(half_width, gate.global_position.x - half_width)
	var facing_direction := -1.0 if bool(player.get("facing_left")) else 1.0
	var target_x := player.global_position.x + CAMERA_LOOKAHEAD_X * facing_direction
	var target_y := CAMERA_Y
	var vertical_delta := player.global_position.y - CAMERA_Y
	if absf(vertical_delta) > CAMERA_VERTICAL_DEADZONE:
		target_y += (absf(vertical_delta) - CAMERA_VERTICAL_DEADZONE) * signf(vertical_delta) * CAMERA_VERTICAL_FOLLOW
	var impulse := _camera_impulse_offset()
	camera.global_position = Vector2(clampf(target_x, half_width, max_x), target_y) + impulse

func _camera_impulse_offset() -> Vector2:
	if camera_impulse_timer <= 0.0:
		return Vector2.ZERO
	var progress := camera_impulse_timer / CAMERA_IMPULSE_DURATION
	var kick := sin(progress * PI * 5.0) * progress * CAMERA_IMPULSE_PIXELS * camera_impulse_strength
	return Vector2(kick, -absf(kick) * 0.35)
