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
	_expect(scene.get_node_or_null("Projectiles") != null, "projectile container should exist", failures)
	_expect(scene.get_node_or_null("Goal") != null, "goal should exist", failures)

	if player == null:
		_finish(summary, failures)
		return

	_record_stage(scene, game, summary, failures)
	await _verify_enemy_behavior(scene, summary, failures)
	await _verify_player_movement(scene, player, summary, failures)
	await _verify_attack(scene, player, summary, failures)
	await _verify_ranged_attack(scene, player, summary, failures)
	await _verify_combat_and_damage(scene, game, player, summary, failures)
	_verify_retry(scene, game, player, summary, failures)
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
		"enemy": {},
		"attack": {},
		"ranged": {},
		"combat": {},
		"balance": {},
		"gameplay": {},
		"roguelike": {},
		"retry": {},
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
		"run_seed": int(stage_summary.get("run_seed", 0)),
		"run_stage_index": int(stage_summary.get("run_stage_index", 0)),
		"stage_variant": stage_summary.get("stage_variant", ""),
		"elite_enemy_count": int(stage_summary.get("elite_enemy_count", 0)),
		"layout_style": stage_summary.get("layout_style", ""),
		"vertical_room_count": int(stage_summary.get("vertical_room_count", 0)),
		"shortcut_count": int(stage_summary.get("shortcut_count", 0)),
		"locked_gate_count": int(stage_summary.get("locked_gate_count", 0)),
		"critical_path_room_count": int(stage_summary.get("critical_path_room_count", 0)),
		"platform_count": platform_count,
		"sigil_count": sigil_count,
		"enemy_count": enemy_count,
		"summary_platform_count": stage_summary.get("platform_count", null),
		"summary_sigil_count": stage_summary.get("sigil_count", null),
		"summary_enemy_count": stage_summary.get("enemy_count", null),
	}

	_expect(stage_summary.get("seed", null) == 1337, "stage seed should be deterministic", failures)
	_expect(stage_summary.get("layout_style", "") == "castle_keep", "stage should use a castle keep layout rather than a linear platform chain", failures)
	_expect(int(stage_summary.get("vertical_room_count", 0)) == 3, "stage should include three vertical castle rooms", failures)
	_expect(int(stage_summary.get("shortcut_count", 0)) == 1, "stage should include one readable shortcut branch", failures)
	_expect(int(stage_summary.get("locked_gate_count", 0)) == 1, "stage should end at one locked gate hall", failures)
	_expect(int(stage_summary.get("critical_path_room_count", 0)) == 6, "stage should expose a six-room critical path", failures)
	_expect(platform_count >= 7, "stage should generate traversable platforms", failures)
	_expect(sigil_count == 6, "stage should generate six sigils", failures)
	_expect(enemy_count >= 3, "stage should generate enemies", failures)
	_expect(platform_count == stage_summary.get("platform_count", -1), "platform count should match generated summary", failures)
	_expect(sigil_count == stage_summary.get("sigil_count", -1), "sigil count should match generated summary", failures)
	_expect(enemy_count == stage_summary.get("enemy_count", -1), "enemy count should match generated summary", failures)
	_record_balance(scene, stage_summary, summary, failures)

func _record_balance(scene: Node, stage_summary: Dictionary, summary: Dictionary, failures: Array) -> void:
	var balance: Dictionary = stage_summary.get("balance", {})
	var bosses := get_nodes_in_group("bosses")
	var boss_hit_points := 0
	if not bosses.is_empty():
		boss_hit_points = int(bosses[0].get_meta("max_hit_points", 0))
	var combat_encounters := get_nodes_in_group("enemies").size()
	var reported_balance := {
		"target_clear_attempts": int(balance.get("target_clear_attempts", 0)),
		"expected_clear_attempts": int(balance.get("expected_clear_attempts", 0)),
		"risk_score": int(balance.get("risk_score", 0)),
		"health_buffer_hits": int(balance.get("health_buffer_hits", 0)),
		"focus_shots_available": int(balance.get("focus_shots_available", 0)),
		"branch_challenge_count": int(balance.get("branch_challenge_count", 0)),
		"combat_encounter_count": combat_encounters,
		"boss_hit_points": boss_hit_points,
		"recovery_window_count": int(balance.get("recovery_window_count", 0)),
		"pacing": String(balance.get("pacing", "")),
	}
	summary["balance"] = reported_balance

	_expect(reported_balance["target_clear_attempts"] == 2, "first stage should target a two-attempt clear", failures)
	_expect(reported_balance["expected_clear_attempts"] == 2, "first stage balance should estimate two clear attempts", failures)
	_expect(reported_balance["risk_score"] >= 7 and reported_balance["risk_score"] <= 10, "first stage risk score should be moderate", failures)
	_expect(reported_balance["health_buffer_hits"] == 2, "player should have two mistakes of health buffer", failures)
	_expect(reported_balance["focus_shots_available"] == 3, "player should start with three focus shots available", failures)
	_expect(reported_balance["branch_challenge_count"] == 2, "first stage should have two branch challenges", failures)
	_expect(reported_balance["combat_encounter_count"] == int(stage_summary.get("enemy_count", -1)), "combat encounter count should match generated enemies", failures)
	_expect(reported_balance["combat_encounter_count"] == 4, "first stage should have three enemies and one boss", failures)
	_expect(reported_balance["boss_hit_points"] == 3, "first stage boss should take three hits", failures)
	_expect(reported_balance["recovery_window_count"] >= 2, "first stage should include recovery windows", failures)
	_expect(reported_balance["pacing"] == "first_stage_two_try", "first stage pacing label should match two-try target", failures)

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
	var visible_world_width := float(ProjectSettings.get_setting("display/window/size/viewport_width")) / camera.zoom.x
	summary["camera"] = {
		"x": camera.global_position.x,
		"followed_player": camera_followed,
		"zoom": _vector_summary(camera.zoom),
		"visible_world_width": snappedf(visible_world_width, 0.01),
	}
	_expect(camera_followed, "camera should follow the player across the stage", failures)
	_expect(camera.zoom == Vector2(2.2, 2.2), "camera should use close gothic action framing", failures)
	_expect(visible_world_width <= 900.0, "camera should keep the visible world width tight enough to read character detail", failures)

func _verify_enemy_behavior(scene: Node, summary: Dictionary, failures: Array) -> void:
	var enemies := get_nodes_in_group("enemies")
	if enemies.is_empty():
		_expect(false, "enemy behavior verify needs at least one enemy", failures)
		summary["enemy"] = {
			"has_ai_script": false,
			"patrol_moved_by": 0.0,
			"animation_after_patrol": "",
		}
		return

	var enemy: Area2D = enemies[0]
	var sprite := enemy.get_node_or_null("EnemySprite") as AnimatedSprite2D
	var start_x := enemy.global_position.x
	for frame in 45:
		await process_frame
	var moved_by := absf(enemy.global_position.x - start_x)
	var animation := "" if sprite == null else String(sprite.animation)
	var has_ai_script := enemy.get_script() != null and enemy.has_method("configure_patrol")

	summary["enemy"] = {
		"has_ai_script": has_ai_script,
		"patrol_moved_by": moved_by,
		"animation_after_patrol": animation,
	}

	_expect(has_ai_script, "generated enemies should use the dedicated enemy AI script", failures)
	_expect(moved_by >= 6.0, "generated enemies should patrol instead of standing still", failures)
	_expect(animation == "walk" or animation == "attack", "generated enemies should play walk or attack animation", failures)

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
			"arc_hitbox_aligned_right": false,
			"arc_hitbox_aligned_left": false,
			"training_dummy_destroyed": false,
		}
		return

	player.facing_left = false
	player._sync_attack_geometry()
	var arc_position_right := _vector_summary(attack_arc.position)
	var hitbox_position_right := _vector_summary(attack_hitbox.position)
	var arc_hitbox_aligned_right := attack_arc.position.distance_to(attack_hitbox.position) <= 0.5
	player.facing_left = true
	player._sync_attack_geometry()
	var arc_position_left := _vector_summary(attack_arc.position)
	var hitbox_position_left := _vector_summary(attack_hitbox.position)
	var arc_hitbox_aligned_left := attack_arc.position.distance_to(attack_hitbox.position) <= 0.5
	player.facing_left = false
	player._sync_attack_geometry()

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
		animation_seen = animation_seen or attack_arc.visible
		hitbox_enabled = hitbox_enabled or attack_hitbox.monitoring

	var destroyed := bool(dummy.get_meta("destroyed", false))
	summary["attack"] = {
		"available": player.has_method("attack"),
		"animation_seen": animation_seen,
		"hitbox_enabled_during_attack": hitbox_enabled,
		"arc_hitbox_aligned_right": arc_hitbox_aligned_right,
		"arc_hitbox_aligned_left": arc_hitbox_aligned_left,
		"arc_position_right": arc_position_right,
		"hitbox_position_right": hitbox_position_right,
		"arc_position_left": arc_position_left,
		"hitbox_position_left": hitbox_position_left,
		"arc_scale": _vector_summary(attack_arc.scale),
		"training_dummy_destroyed": destroyed,
	}

	_expect(player.has_method("attack"), "player should expose attack action", failures)
	_expect(animation_seen, "attack arc should become visible during attack", failures)
	_expect(hitbox_enabled, "attack hitbox should enable during active attack frames", failures)
	_expect(arc_hitbox_aligned_right, "right-facing attack arc should share the attack hitbox center", failures)
	_expect(arc_hitbox_aligned_left, "left-facing attack arc should share the attack hitbox center", failures)
	_expect(destroyed, "attack should destroy training dummy", failures)

func _verify_ranged_attack(scene: Node, player: CharacterBody2D, summary: Dictionary, failures: Array) -> void:
	for frame in 24:
		await process_frame

	var enemies := get_nodes_in_group("enemies")
	var projectiles: Node2D = scene.get_node("Projectiles")
	if enemies.size() < 2:
		_expect(false, "ranged verify needs at least two enemies", failures)
		summary["ranged"] = {
			"available": player.has_method("shoot"),
			"projectile_spawned": false,
			"enemy_destroyed_by_shot": false,
			"focus_after_shot": null,
			"focus_after_regen": null,
		}
		return

	player.e2e_set_axis(0.0)
	player.facing_left = false
	player.shoot_focus = player.FOCUS_MAX
	var enemy: Area2D = enemies[1]
	enemy.visible = true
	enemy.monitoring = true
	enemy.monitorable = true
	enemy.set_meta("destroyed", false)
	enemy.global_position = player.global_position + Vector2(240.0, -44.0)
	enemy.set_physics_process(false)

	var projectile_count_before := projectiles.get_child_count()
	var fired: bool = player.shoot()
	var focus_after_shot: float = player.shoot_focus
	var projectile_spawned := projectiles.get_child_count() > projectile_count_before
	for frame in 30:
		await process_frame

	var destroyed := bool(enemy.get_meta("destroyed", false))
	for frame in 60:
		await process_frame
	var focus_after_regen: float = player.shoot_focus

	summary["ranged"] = {
		"available": player.has_method("shoot"),
		"fired": fired,
		"projectile_spawned": projectile_spawned,
		"enemy_destroyed_by_shot": destroyed,
		"focus_after_shot": focus_after_shot,
		"focus_after_regen": focus_after_regen,
	}

	_expect(player.has_method("shoot"), "player should expose ranged shoot action", failures)
	_expect(fired, "shoot should fire when focus is available", failures)
	_expect(projectile_spawned, "shoot should spawn a projectile", failures)
	_expect(destroyed, "shot should destroy an enemy at range", failures)
	_expect(is_equal_approx(focus_after_shot, player.FOCUS_MAX - player.SHOT_COST), "shoot should consume focus", failures)
	_expect(focus_after_regen > focus_after_shot, "focus should regenerate over time", failures)

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
	enemy.set_physics_process(false)

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
	player.global_position = Vector2(1600.0, 400.0)
	var position_before_damage: Vector2 = player.global_position
	game.damage_invulnerability_timer = 0.0
	game.damage_player(enemy)
	var health_after: int = int(game.get("player_health"))
	var stayed_in_place := player.global_position.distance_to(position_before_damage) < 1.0
	var invulnerability_started := float(game.get("damage_invulnerability_timer")) > 0.0
	var knockback_applied := absf(player.velocity.x) > 120.0 and player.velocity.y < 0.0
	game.damage_player(enemy)
	var health_after_invulnerable_hit: int = int(game.get("player_health"))
	var player_summary: Dictionary = summary["player"]
	player_summary["health_after_damage"] = health_after
	player_summary["stayed_in_place_after_damage"] = stayed_in_place
	player_summary["damage_invulnerability_started"] = invulnerability_started
	player_summary["knockback_applied"] = knockback_applied
	player_summary["health_after_invulnerable_hit"] = health_after_invulnerable_hit
	summary["player"] = player_summary

	_expect(health_before == 3, "player should start with full health", failures)
	_expect(health_after == 2, "enemy damage should reduce player health", failures)
	_expect(stayed_in_place, "enemy damage should not return player to spawn", failures)
	_expect(invulnerability_started, "enemy damage should start invulnerability", failures)
	_expect(knockback_applied, "enemy damage should apply knockback", failures)
	_expect(health_after_invulnerable_hit == health_after, "invulnerability should block repeated enemy contact damage", failures)

func _verify_retry(scene: Node, game: Node, player: CharacterBody2D, summary: Dictionary, failures: Array) -> void:
	var enemies_before_retry := get_nodes_in_group("enemies")
	if enemies_before_retry.is_empty():
		_expect(false, "retry verify needs at least one enemy", failures)
		return

	game.player_health = 1
	game.damage_invulnerability_timer = 0.0
	game.damage_player(enemies_before_retry[0])
	var game_over_before_retry: bool = bool(game.get("game_over"))

	game.retry_game()
	var game_over_after_retry: bool = bool(game.get("game_over"))
	var gate_open_after_retry: bool = bool(game.get("gate_open"))
	var health_after_retry: int = int(game.get("player_health"))
	var sigils_after_retry: int = int(game.get("sigils_collected"))
	var enemy_count_after_retry := get_nodes_in_group("enemies").size()
	var focus_after_retry: float = player.shoot_focus

	summary["retry"] = {
		"game_over_before_retry": game_over_before_retry,
		"game_over_after_retry": game_over_after_retry,
		"health_after_retry": health_after_retry,
		"sigils_after_retry": sigils_after_retry,
		"gate_open_after_retry": gate_open_after_retry,
		"enemy_count_after_retry": enemy_count_after_retry,
		"focus_after_retry": focus_after_retry,
	}

	_expect(game_over_before_retry, "damage at one health should enter game over", failures)
	_expect(not game_over_after_retry, "retry should clear game over", failures)
	_expect(health_after_retry == 3, "retry should restore full health", failures)
	_expect(sigils_after_retry == 0, "retry should reset sigil progress", failures)
	_expect(not gate_open_after_retry, "retry should reseal the gate", failures)
	_expect(enemy_count_after_retry == 4, "retry should regenerate enemies", failures)
	_expect(is_equal_approx(focus_after_retry, player.FOCUS_MAX), "retry should restore focus", failures)

func _verify_gameplay(scene: Node, game: Node, summary: Dictionary, failures: Array) -> void:
	var initial_stage_index: int = int(game.get("run_stage_index"))
	for sigil: Node in get_nodes_in_group("sigils"):
		game.collect_sigil(sigil)

	var gate_open: bool = bool(game.get("gate_open"))
	var player: CharacterBody2D = scene.get_node("Player")
	player.global_position = scene.get_node("Goal").global_position
	game.win_game()
	var won: bool = bool(game.get("won"))
	var selected_reward: Dictionary = game.get("selected_reward")
	var reward_count_after_win: int = game.get("run_rewards").size()
	var max_health_after_reward: int = int(game.get("player_max_health"))

	summary["gameplay"] = {
		"gate_open_after_collecting_sigils": gate_open,
		"win_state_reached": won,
		"stage_playable_path": gate_open and won and not bool(game.get("game_over")),
	}

	var advanced: bool = game.advance_to_next_stage()
	var next_stage_summary: Dictionary = game.get("generated_stage_summary")
	summary["roguelike"] = {
		"initial_stage_index": initial_stage_index,
		"reward_granted_after_win": reward_count_after_win == 1,
		"selected_reward_id": String(selected_reward.get("id", "")),
		"max_health_after_reward": max_health_after_reward,
		"advanced_to_stage_index": int(game.get("run_stage_index")),
		"next_stage_seed": int(next_stage_summary.get("seed", 0)),
		"reward_count_after_advance": game.get("run_rewards").size(),
		"next_stage_variant": String(next_stage_summary.get("stage_variant", "")),
		"advanced": advanced,
	}

	_expect(gate_open, "gate should open after all sigils are collected", failures)
	_expect(won, "game should enter won state", failures)
	_expect(summary["gameplay"]["stage_playable_path"], "stage should have a playable path from start to win", failures)
	_expect(initial_stage_index == 1, "run should begin at stage index one", failures)
	_expect(reward_count_after_win == 1, "stage clear should grant one roguelike reward", failures)
	_expect(String(selected_reward.get("id", "")) == "blood_vial", "first clear should grant deterministic blood vial reward", failures)
	_expect(max_health_after_reward == 4, "blood vial should increase max health", failures)
	_expect(advanced, "won run should advance to the next stage", failures)
	_expect(int(game.get("run_stage_index")) == 2, "next stage should increment run stage index", failures)
	_expect(int(next_stage_summary.get("seed", 0)) != 1337, "next stage should use a different seed", failures)
	_expect(String(next_stage_summary.get("stage_variant", "")) == "moonlit_cloister", "second stage should use moonlit cloister variant", failures)

func _expect(condition: bool, message: String, failures: Array) -> bool:
	if condition:
		return true
	failures.append(message)
	return false

func _vector_summary(vector: Vector2) -> Dictionary:
	return {
		"x": snappedf(vector.x, 0.01),
		"y": snappedf(vector.y, 0.01),
	}

func _finish(summary: Dictionary, failures: Array) -> void:
	summary["status"] = "pass" if failures.is_empty() else "fail"
	summary["failures"] = failures
	print("LLM_VERIFY_JSON " + JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)
