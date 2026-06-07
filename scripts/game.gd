extends Node2D

const LEVEL_HEIGHT := 540.0
const TARGET_WINDOW_SIZE := Vector2i(1920, 1080)
const PLAYER_MAX_HEALTH := 3
const DAMAGE_INVULNERABILITY := 0.75
const CAMERA_MIN_X := 960.0
const CAMERA_Y := 540.0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var gate: Area2D = $Goal
@onready var gate_visual: ColorRect = $Goal/GateVisual
@onready var hud_label: Label = $CanvasLayer/HUD
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
	_ensure_input_actions()
	_generate_stage()
	_connect_collectibles()
	_connect_enemies()
	_update_camera()
	_update_hud()

func _process(delta: float) -> void:
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
	gate_visual.color = Color(0.55, 0.08, 0.13, 0.82)
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

func _connect_collectibles() -> void:
	var sigils := get_tree().get_nodes_in_group("sigils")
	sigils_total = sigils.size()
	for sigil in sigils:
		sigil.set_meta("collected", false)
		sigil.body_entered.connect(_on_sigil_body_entered.bind(sigil))
	gate.body_entered.connect(_on_goal_body_entered)

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
	var gate_text := "OPEN" if gate_open else "SEALED"
	var win_text := " / WON" if won else ""
	var state_text := " / GAME OVER" if game_over else win_text
	var shoot_focus: float = player.shoot_focus
	hud_label.text = "HP %d/%d / FOCUS %.1f/%.0f / SIGILS %d/%d / %s%s" % [player_health, PLAYER_MAX_HEALTH, shoot_focus, player.FOCUS_MAX, sigils_collected, sigils_total, gate_text, state_text]

func _ensure_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_W, KEY_UP, KEY_SPACE])
	_add_key_action("attack", [KEY_J, KEY_K, KEY_X])
	_add_key_action("shoot", [KEY_L, KEY_C, KEY_V])

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

func _update_camera() -> void:
	var max_x := maxf(CAMERA_MIN_X, gate.global_position.x - CAMERA_MIN_X)
	camera.global_position = Vector2(clampf(player.global_position.x, CAMERA_MIN_X, max_x), CAMERA_Y)
