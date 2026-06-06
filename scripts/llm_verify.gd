extends SceneTree

const MODE := "llm_headless_verify"

func _init() -> void:
	call_deferred("run_verify")

func run_verify() -> void:
	var failures: Array = []
	var summary: Dictionary = _base_summary()

	_record_project(summary, failures)

	var packed: PackedScene = load("res://scenes/main.tscn")
	if not _expect(packed != null, "main scene should load", failures):
		_finish(summary, failures)
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	var player: CharacterBody2D = scene.get_node_or_null("Player")
	var game: Node = scene
	_expect(player != null, "player should exist", failures)
	_expect(scene.get_node_or_null("Background") != null, "background should exist", failures)
	_expect(scene.get_node_or_null("Player/PlayerSprite") != null, "player sprite should exist", failures)
	_expect(scene.get_node_or_null("StageGenerator") != null, "stage generator should exist", failures)
	_expect(scene.get_node_or_null("Platforms") != null, "platform container should exist", failures)
	_expect(scene.get_node_or_null("Collectibles") != null, "collectible container should exist", failures)
	_expect(scene.get_node_or_null("Goal") != null, "goal should exist", failures)

	if player == null:
		_finish(summary, failures)
		return

	_record_stage(scene, game, summary, failures)
	await _verify_player_movement(scene, player, summary, failures)
	_verify_gameplay(scene, game, summary, failures)

	_finish(summary, failures)

func _base_summary() -> Dictionary:
	return {
		"mode": MODE,
		"status": "fail",
		"project": {},
		"stage": {},
		"player": {},
		"gameplay": {},
		"failures": [],
	}

func _record_project(summary: Dictionary, failures: Array) -> void:
	var width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	summary["project"] = {
		"name": String(ProjectSettings.get_setting("application/config/name")),
		"viewport": {
			"width": width,
			"height": height,
		},
	}
	_expect(width == 1920, "viewport width should be 1920", failures)
	_expect(height == 1080, "viewport height should be 1080", failures)

func _record_stage(scene: Node, game: Node, summary: Dictionary, failures: Array) -> void:
	var stage_summary: Dictionary = {}
	if game.get("generated_stage_summary") is Dictionary:
		stage_summary = game.get("generated_stage_summary")
	else:
		_expect(false, "generated stage summary should exist", failures)

	var platforms: Node = scene.get_node("Platforms")
	var sigil_count: int = get_nodes_in_group("sigils").size()
	var platform_count: int = platforms.get_child_count()

	summary["stage"] = {
		"seed": stage_summary.get("seed", null),
		"theme": stage_summary.get("theme", ""),
		"platform_count": platform_count,
		"sigil_count": sigil_count,
		"summary_platform_count": stage_summary.get("platform_count", null),
		"summary_sigil_count": stage_summary.get("sigil_count", null),
	}

	_expect(stage_summary.get("seed", null) == 1337, "stage seed should be deterministic", failures)
	_expect(platform_count >= 7, "stage should generate traversable platforms", failures)
	_expect(sigil_count == 6, "stage should generate six sigils", failures)
	_expect(platform_count == stage_summary.get("platform_count", -1), "platform count should match generated summary", failures)
	_expect(sigil_count == stage_summary.get("sigil_count", -1), "sigil count should match generated summary", failures)

func _verify_player_movement(scene: Node, player: CharacterBody2D, summary: Dictionary, failures: Array) -> void:
	var start_x: float = player.global_position.x
	player.e2e_set_axis(1.0)
	for frame in 45:
		await process_frame
	var moved_right_by: float = player.global_position.x - start_x
	var sprite: AnimatedSprite2D = scene.get_node("Player/PlayerSprite")

	summary["player"] = {
		"start_x": start_x,
		"end_x": player.global_position.x,
		"moved_right_by": moved_right_by,
		"animation": sprite.animation,
	}

	_expect(moved_right_by >= 40.0, "player should move right in headless simulation", failures)
	_expect(sprite.animation == "walk", "walk animation should become active", failures)

func _verify_gameplay(scene: Node, game: Node, summary: Dictionary, failures: Array) -> void:
	for sigil: Node in get_nodes_in_group("sigils"):
		game.collect_sigil(sigil)

	var gate_open: bool = bool(game.get("gate_open"))
	var player: CharacterBody2D = scene.get_node("Player")
	player.global_position = scene.get_node("Goal").global_position
	game.win_game()
	var won: bool = bool(game.get("won"))

	summary["gameplay"] = {
		"gate_open_after_collecting_sigils": gate_open,
		"win_state_reached": won,
	}

	_expect(gate_open, "gate should open after all sigils are collected", failures)
	_expect(won, "game should enter won state", failures)

func _expect(condition: bool, message: String, failures: Array) -> bool:
	if condition:
		return true
	failures.append(message)
	return false

func _finish(summary: Dictionary, failures: Array) -> void:
	summary["status"] = "pass" if failures.is_empty() else "fail"
	summary["failures"] = failures
	print("LLM_VERIFY_JSON " + JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)
