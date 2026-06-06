extends Node2D

const LEVEL_HEIGHT := 540.0
const TARGET_WINDOW_SIZE := Vector2i(1920, 1080)

@onready var player: CharacterBody2D = $Player
@onready var gate: Area2D = $Goal
@onready var gate_visual: ColorRect = $Goal/GateVisual
@onready var hud_label: Label = $CanvasLayer/HUD
@onready var stage_generator: Node = $StageGenerator

var sigils_total := 0
var sigils_collected := 0
var gate_open := false
var won := false
var generated_stage_summary := {}

func _ready() -> void:
	_apply_window_size()
	_ensure_input_actions()
	_generate_stage()
	_connect_collectibles()
	_update_hud()

func _process(_delta: float) -> void:
	if player.global_position.y > LEVEL_HEIGHT + 80.0:
		player.reset_to_spawn()

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

func win_game() -> void:
	if not gate_open:
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

func _on_sigil_body_entered(body: Node, sigil: Area2D) -> void:
	if body == player:
		collect_sigil(sigil)

func _on_goal_body_entered(body: Node) -> void:
	if body == player:
		win_game()

func _update_hud() -> void:
	var gate_text := "OPEN" if gate_open else "SEALED"
	var win_text := " / WON" if won else ""
	hud_label.text = "SIGILS %d/%d / %s%s" % [sigils_collected, sigils_total, gate_text, win_text]

func _ensure_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_W, KEY_UP, KEY_SPACE])
	_add_key_action("attack", [KEY_J, KEY_K, KEY_X])

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
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(TARGET_WINDOW_SIZE)

func _generate_stage() -> void:
	generated_stage_summary = stage_generator.generate_stage(self)
	player.spawn_position = player.global_position
