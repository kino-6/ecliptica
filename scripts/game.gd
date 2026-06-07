extends Node2D

const LEVEL_HEIGHT := 540.0
const TARGET_WINDOW_SIZE := Vector2i(1920, 1080)
const CAMERA_ZOOM := Vector2(1.65, 1.65)
const HUD_BAR_WIDTH := 240.0
const PLAYER_MAX_HEALTH := 3
const DAMAGE_INVULNERABILITY := 0.75
const CAMERA_Y := 500.0
const GATE_SEALED_COLOR := Color(0.08, 0.09, 0.13, 0.82)
const GATE_OPEN_COLOR := Color(0.55, 0.08, 0.13, 0.82)

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var gate: Area2D = $Goal
@onready var gate_visual: ColorRect = $Goal/GateVisual
@onready var health_fill: ColorRect = $CanvasLayer/HUDPanel/HealthBar/HealthFill
@onready var focus_fill: ColorRect = $CanvasLayer/HUDPanel/FocusBar/FocusFill
@onready var sigil_pips: HBoxContainer = $CanvasLayer/HUDPanel/SigilPips
@onready var state_label: Label = $CanvasLayer/HUDPanel/StateLabel
@onready var stage_generator: Node = $StageGenerator

var sigils_total := 0
var sigils_collected := 0
var gate_open := false
var won := false
var game_over := false
var player_health := PLAYER_MAX_HEALTH
var damage_invulnerability_timer := 0.0
var generated_stage_summary := {}

func _ready() -> void:
	_apply_window_size()
	camera.zoom = CAMERA_ZOOM
	_ensure_input_actions()
	_generate_stage()
	_connect_collectibles()
	_connect_enemies()
	_update_camera()
	_update_hud()

func _process(delta: float) -> void:
	if game_over and Input.is_action_just_pressed("retry"):
		retry_game()
		return
	damage_invulnerability_timer = maxf(damage_invulnerability_timer - delta, 0.0)
	if player.global_position.y > LEVEL_HEIGHT + 80.0:
		damage_player()
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
	gate_visual.color = GATE_OPEN_COLOR
	_update_hud()

func damage_player(_source: Node = null) -> void:
	if won or game_over or damage_invulnerability_timer > 0.0:
		return
	player_health = maxi(player_health - 1, 0)
	damage_invulnerability_timer = DAMAGE_INVULNERABILITY
	player.reset_to_spawn()
	_update_camera()
	if player_health <= 0:
		game_over = true
	_update_hud()

func win_game() -> void:
	if not gate_open or game_over:
		return
	won = true
	_update_hud()

func retry_game() -> void:
	_reset_run_state()
	_clear_projectiles()
	_generate_stage()
	_connect_collectibles()
	_connect_enemies()
	player.reset_to_spawn()
	player.shoot_focus = player.FOCUS_MAX
	gate_visual.color = GATE_SEALED_COLOR
	_update_camera()
	_update_hud()

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
	var gate_text := "OPEN" if gate_open else "SEALED"
	var win_text := " / WON" if won else ""
	var state_text := " / GAME OVER / R TO RETRY" if game_over else win_text
	state_label.text = "%s%s" % [gate_text, state_text]

func _update_hud_bars() -> void:
	var health_ratio := clampf(float(player_health) / float(PLAYER_MAX_HEALTH), 0.0, 1.0)
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

func _ensure_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_W, KEY_UP, KEY_SPACE])
	_add_key_action("attack", [KEY_J, KEY_K, KEY_X])
	_add_key_action("shoot", [KEY_L, KEY_C, KEY_V])
	_add_key_action("retry", [KEY_R, KEY_ENTER])

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
	generated_stage_summary = stage_generator.generate_stage(self)
	player.spawn_position = player.global_position

func _reset_run_state() -> void:
	sigils_total = 0
	sigils_collected = 0
	gate_open = false
	won = false
	game_over = false
	player_health = PLAYER_MAX_HEALTH
	damage_invulnerability_timer = 0.0

func _clear_projectiles() -> void:
	var projectiles := get_node_or_null("Projectiles")
	if projectiles == null:
		return
	for projectile in projectiles.get_children():
		projectile.free()

func _update_camera() -> void:
	var half_width := TARGET_WINDOW_SIZE.x / (2.0 * CAMERA_ZOOM.x)
	var max_x := maxf(half_width, gate.global_position.x - half_width)
	camera.global_position = Vector2(clampf(player.global_position.x, half_width, max_x), CAMERA_Y)
