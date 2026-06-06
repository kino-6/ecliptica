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
	await _verify_attack(scene, player, summary, failures)
	await _verify_combat_and_damage(scene, game, player, summary, failures)
	_verify_gameplay(scene, game, summary, failures)

	_finish(summary, failures)

func _base_summary() -> Dictionary:
	return {
		"mode": MODE,
		"status": "fail",
		"project": {},
			"stage": {},
			"player": {},
			"camera": {},
			"attack": {},
			"combat": {},
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
	var enemy_count: int = get_nodes_in_group("enemies").size()
	var platform_count: int = platforms.get_child_count()

	summary["stage"] = {
		"seed": stage_summary.get("seed", null),
		"theme": stage_summary.get("theme", ""),
		"platform_count": platform_count,
		"sigil_count": sigil_count,
		"enemy_count": enemy_count,
		"summary_platform_count": stage_summary.get("platform_count", null),
		"summary_sigil_count": stage_summary.get("sigil_count", null),
		"summary_enemy_count": stage_summary.get("enemy_count", null),
	}

	_expect(stage_summary.get("seed", null) == 1337, "stage seed should be deterministic", failures)
	_expect(platform_count >= 7, "stage should generate traversable platforms", failures)
	_expect(sigil_count == 6, "stage should generate six sigils", failures)
	_expect(enemy_count >= 3, "stage should generate enemies", failures)
	_expect(platform_count == stage_summary.get("platform_count", -1), "platform count should match generated summary", failures)
	_expect(sigil_count == stage_summary.get("sigil_count", -1), "sigil count should match generated summary", failures)
	_expect(enemy_count == stage_summary.get("enemy_count", -1), "enemy count should match generated summary", failures)

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

	var game: Node = scene
	var camera: Camera2D = scene.get_node("Camera2D")
	player.global_position = Vector2(1300.0, player.global_position.y)
	game._update_camera()
	var camera_followed := camera.global_position.x > 1000.0
	summary["camera"] = {
		"x": camera.global_position.x,
		"followed_player": camera_followed,
	}
	_expect(camera_followed, "camera should follow the player across the stage", failures)

func _verify_attack(scene: Node, player: CharacterBody2D, summary: Dictionary, failures: Array) -> void:
	var dummy: Area2D = scene.get_node_or_null("TrainingDummy")
	var attack_arc: AnimatedSprite2D = scene.get_node("Player/AttackArc")
	var attack_hitbox: Area2D = scene.get_node("Player/AttackHitbox")

	if dummy == null:
		_expect(false, "training dummy should exist", failures)
		summary["attack"] = {
			"available": player.has_method("attack"),
			"animation_seen": false,
			"hitbox_enabled_during_attack": false,
			"training_dummy_destroyed": false,
		}
		return

	dummy.visible = true
	dummy.monitoring = true
	dummy.monitorable = true
	dummy.set_meta("destroyed", false)
	dummy.global_position = player.global_position + Vector2(76.0, -42.0)

	player.e2e_attack()
	await process_frame
	await process_frame

	var animation_seen := attack_arc.visible
	var hitbox_enabled := false
	for frame in 16:
		await process_frame
		hitbox_enabled = hitbox_enabled or attack_hitbox.monitoring

	var destroyed := bool(dummy.get_meta("destroyed", false))
	summary["attack"] = {
		"available": player.has_method("attack"),
		"animation_seen": animation_seen,
		"hitbox_enabled_during_attack": hitbox_enabled,
		"training_dummy_destroyed": destroyed,
	}

	_expect(player.has_method("attack"), "player should expose attack action", failures)
	_expect(animation_seen, "attack arc should become visible during attack", failures)
	_expect(hitbox_enabled, "attack hitbox should enable during active attack frames", failures)
	_expect(destroyed, "attack should destroy training dummy", failures)

func _verify_combat_and_damage(scene: Node, game: Node, player: CharacterBody2D, summary: Dictionary, failures: Array) -> void:
	for frame in 24:
		await process_frame

	var enemies := get_nodes_in_group("enemies")
	if enemies.is_empty():
		_expect(false, "at least one enemy should exist", failures)
		summary["combat"] = {"enemy_destroyed_by_attack": false}
		return

	game.player_health = 3
	game.damage_invulnerability_timer = 999.0
	player.attack_timer = 0.0
	player.e2e_set_axis(0.0)
	var enemy: Area2D = enemies[0]
	enemy.visible = true
	enemy.monitoring = true
	enemy.monitorable = true
	enemy.set_meta("destroyed", false)
	enemy.global_position = player.global_position + Vector2(104.0, -42.0)

	player.attack()
	await process_frame
	await process_frame
	for frame in 16:
		await process_frame

	var enemy_destroyed := bool(enemy.get_meta("destroyed", false))
	game.player_health = 3
	game.damage_invulnerability_timer = 0.0
	summary["combat"] = {
		"enemy_destroyed_by_attack": enemy_destroyed,
	}
	_expect(enemy_destroyed, "player attack should destroy an enemy", failures)

	var health_before: int = int(game.get("player_health"))
	var old_spawn: Vector2 = player.spawn_position
	player.global_position = Vector2(1600.0, 400.0)
	game.damage_invulnerability_timer = 0.0
	game.damage_player(enemy)
	var health_after: int = int(game.get("player_health"))
	var respawned := player.global_position.distance_to(old_spawn) < 1.0
	var player_summary: Dictionary = summary["player"]
	player_summary["health_after_damage"] = health_after
	player_summary["respawned_after_damage"] = respawned
	summary["player"] = player_summary

	_expect(health_before == 3, "player should start with full health", failures)
	_expect(health_after == 2, "enemy damage should reduce player health", failures)
	_expect(respawned, "enemy damage should return player to spawn", failures)

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
		"stage_playable_path": gate_open and won and not bool(game.get("game_over")),
	}

	_expect(gate_open, "gate should open after all sigils are collected", failures)
	_expect(won, "game should enter won state", failures)
	_expect(summary["gameplay"]["stage_playable_path"], "stage should have a playable path from start to win", failures)

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
