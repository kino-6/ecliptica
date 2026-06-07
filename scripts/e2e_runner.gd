extends SceneTree

func _init() -> void:
	call_deferred("run_e2e")

func run_e2e() -> void:
	if not _expect(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920, "viewport width should be 1920"):
		return
	if not _expect(ProjectSettings.get_setting("display/window/size/viewport_height") == 1080, "viewport height should be 1080"):
		return

	var packed: PackedScene = load("res://scenes/main.tscn")
	if not _expect(packed != null, "main scene should load"):
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	var player: CharacterBody2D = scene.get_node("Player")
	var player_sprite: AnimatedSprite2D = scene.get_node("Player/PlayerSprite")
	var game: Node = scene
	if not _expect(root.size == Vector2i(1920, 1080), "runtime root viewport should be 1920x1080"):
		return
	if not _expect(player != null, "player should exist"):
		return
	if not _expect(scene.get_node_or_null("Background") != null, "background should exist"):
		return
	if not _expect(scene.get_node("Camera2D").zoom == Vector2(1.65, 1.65), "camera should zoom in enough for readable play"):
		return
	if not _expect(scene.get_node_or_null("CanvasLayer/HUDPanel/HealthBar/HealthFill") != null, "health should render as a HUD bar"):
		return
	if not _expect(scene.get_node_or_null("CanvasLayer/HUDPanel/FocusBar/FocusFill") != null, "focus should render as a HUD bar"):
		return
	if not _expect(scene.get_node_or_null("CanvasLayer/HUDPanel/SigilPips") != null, "sigils should render as pips"):
		return
	if not _expect(scene.get_node_or_null("Player/PlayerSprite") != null, "player sprite should exist"):
		return
	if not _expect(scene.get_node_or_null("Player/AttackArc") != null, "attack arc should exist"):
		return
	if not _expect(scene.get_node_or_null("Player/AttackHitbox") != null, "attack hitbox should exist"):
		return
	if not _expect(scene.get_node_or_null("Projectiles") != null, "projectile container should exist"):
		return
	if not _expect(scene.get_node_or_null("TrainingDummy") != null, "training dummy should exist"):
		return
	if not _expect(scene.get_node_or_null("StageGenerator") != null, "stage generator should exist"):
		return
	if not _expect(game.generated_stage_summary.has("seed"), "stage summary should exist"):
		return
	if not _expect(game.generated_stage_summary["seed"] == 1337, "stage seed should be deterministic"):
		return
	if not _expect(game.generated_stage_summary.get("layout_style", "") == "castle_keep", "stage should use a castle keep layout"):
		return
	if not _expect(game.generated_stage_summary.get("vertical_room_count", 0) == 3, "stage should include vertical castle rooms"):
		return
	if not _expect(game.generated_stage_summary.get("shortcut_count", 0) == 1, "stage should include a shortcut branch"):
		return
	if not _expect(game.generated_stage_summary.get("locked_gate_count", 0) == 1, "stage should include a locked gate hall"):
		return
	if not _expect(game.generated_stage_summary.get("critical_path_room_count", 0) == 6, "stage should expose a six-room critical path"):
		return
	if not _expect(game.generated_stage_summary["platform_count"] >= 7, "stage should generate traversable platforms"):
		return
	if not _expect(game.generated_stage_summary["sigil_count"] == 6, "stage should generate six sigils"):
		return
	if not _expect(scene.get_node("Platforms").get_child_count() == game.generated_stage_summary["platform_count"], "platform container should match generated summary"):
		return
	if not _expect(get_nodes_in_group("sigils").size() == game.generated_stage_summary["sigil_count"], "sigil group should match generated summary"):
		return
	if not _expect(get_nodes_in_group("enemies").size() == game.generated_stage_summary["enemy_count"], "enemy group should match generated summary"):
		return
	if not _expect(get_nodes_in_group("bosses").size() == game.generated_stage_summary["boss_count"], "boss group should match generated summary"):
		return

	var start_x: float = player.global_position.x
	player.e2e_set_axis(1.0)
	for frame in 45:
		await process_frame
	if not _expect(player.global_position.x > start_x + 40.0, "player should move right"):
		return
	if not _expect(player_sprite.animation == "walk", "walk animation should become active"):
		return

	player.global_position = Vector2(1300.0, player.global_position.y)
	game._update_camera()
	if not _expect(scene.get_node("Camera2D").global_position.x > 1000.0, "camera should follow the player across the stage"):
		return

	var dummy: Area2D = scene.get_node("TrainingDummy")
	dummy.visible = true
	dummy.monitoring = true
	dummy.monitorable = true
	dummy.set_meta("destroyed", false)
	dummy.global_position = player.global_position + Vector2(76.0, -42.0)
	player.attack()
	await process_frame
	await process_frame
	if not _expect(scene.get_node("Player/AttackArc").visible, "attack arc should become visible"):
		return
	var hitbox_enabled := false
	for frame in 16:
		await process_frame
		hitbox_enabled = hitbox_enabled or scene.get_node("Player/AttackHitbox").monitoring
	if not _expect(hitbox_enabled, "attack hitbox should enable during active frames"):
		return
	if not _expect(dummy.get_meta("destroyed", false), "attack should destroy training dummy"):
		return

	player.attack_timer = 0.0
	player.combo_reset_timer = 0.0
	player.current_attack_step = 0
	var combo_animations: Array[String] = []
	for step in range(3):
		player.attack()
		await process_frame
		combo_animations.append(String(player_sprite.animation))
		player.attack_timer = 0.0
		player.attack_hitbox.monitoring = false
		scene.get_node("Player/AttackArc").visible = false
	var combo_ok := combo_animations.size() == 3 and combo_animations[0] == "attack1" and combo_animations[1] == "attack2" and combo_animations[2] == "attack3"
	if not _expect(combo_ok, "combo should advance through three attack body animations: %s" % [combo_animations]):
		return
	player.attack_timer = 0.0
	player.combo_reset_timer = 0.0
	player.current_attack_step = 0

	var enemies := get_nodes_in_group("enemies")
	if not _expect(enemies.size() >= 3, "generated stage should include enemies"):
		return
	var bosses := get_nodes_in_group("bosses")
	if not _expect(bosses.size() == 1, "generated stage should include one boss"):
		return
	var boss: Area2D = bosses[0]
	if not _expect(boss.get_node_or_null("BossSprite") != null, "boss should use a dedicated sprite asset"):
		return
	if not _expect(boss.get_meta("hit_points", 0) > 1, "boss should require multiple hits"):
		return
	player._damage_attack_target(boss)
	if not _expect(not boss.get_meta("destroyed", false), "boss should survive the first hit"):
		return
	while int(boss.get_meta("hit_points", 0)) > 0:
		player._damage_attack_target(boss)
	if not _expect(boss.get_meta("destroyed", false), "boss should be destroyed after all hit points are removed"):
		return

	var ranged_enemy: Area2D = enemies[1]
	ranged_enemy.visible = true
	ranged_enemy.monitoring = true
	ranged_enemy.monitorable = true
	ranged_enemy.set_meta("destroyed", false)
	ranged_enemy.global_position = player.global_position + Vector2(240.0, -44.0)
	player.shoot_focus = player.FOCUS_MAX
	var focus_before_shot: float = player.shoot_focus
	var projectile_count_before: int = scene.get_node("Projectiles").get_child_count()
	if not _expect(player.shoot(), "shoot should fire when focus is available"):
		return
	if not _expect(player_sprite.animation == "shoot", "shoot body animation should become active"):
		return
	var focus_after_shot: float = player.shoot_focus
	if not _expect(focus_after_shot < focus_before_shot, "shoot should consume focus"):
		return
	if not _expect(scene.get_node("Projectiles").get_child_count() > projectile_count_before, "shoot should spawn a projectile"):
		return
	for frame in 30:
		await process_frame
	if not _expect(ranged_enemy.get_meta("destroyed", false), "shot should destroy an enemy at range"):
		return
	for frame in 90:
		await process_frame
	if not _expect(player.shoot_focus > focus_after_shot, "focus should regenerate over time"):
		return

	game.damage_invulnerability_timer = 0.0
	var health_before: int = game.player_health
	var position_before_damage: Vector2 = player.global_position
	game.damage_player(enemies[0])
	if not _expect(game.player_health == health_before - 1, "enemy contact should damage player"):
		return
	if not _expect(player.global_position.distance_to(position_before_damage) < 1.0, "enemy contact damage should not return player to spawn"):
		return
	if not _expect(game.damage_invulnerability_timer > 0.0, "enemy contact damage should start invulnerability"):
		return
	if not _expect(absf(player.velocity.x) > 120.0 and player.velocity.y < 0.0, "enemy contact damage should apply knockback"):
		return
	var health_after_first_hit: int = game.player_health
	game.damage_player(enemies[0])
	if not _expect(game.player_health == health_after_first_hit, "invulnerability should block repeated enemy contact damage"):
		return

	game.player_health = 1
	game.damage_invulnerability_timer = 0.0
	game.damage_player(enemies[0])
	if not _expect(game.game_over, "damage at one health should enter game over"):
		return
	game.retry_game()
	if not _expect(not game.game_over and game.player_health == game.PLAYER_MAX_HEALTH, "retry should clear game over and restore health"):
		return
	if not _expect(game.sigils_collected == 0 and not game.gate_open, "retry should reset sigils and reseal the gate"):
		return
	if not _expect(get_nodes_in_group("enemies").size() == game.generated_stage_summary["enemy_count"], "retry should regenerate enemies"):
		return

	for sigil: Node in get_nodes_in_group("sigils"):
		game.collect_sigil(sigil)
	if not _expect(game.gate_open, "gate should open after all sigils are collected"):
		return

	player.global_position = scene.get_node("Goal").global_position
	game.win_game()
	if not _expect(game.won, "game should enter won state"):
		return
	if not _expect(game.run_rewards.size() == 1 and game.selected_reward.get("id", "") == "blood_vial", "stage clear should grant the first roguelike reward"):
		return
	if not _expect(game.player_max_health == 4, "blood vial should increase max health"):
		return
	var first_stage_seed: int = int(game.generated_stage_summary["seed"])
	if not _expect(game.advance_to_next_stage(), "won run should advance to the next roguelike stage"):
		return
	if not _expect(game.run_stage_index == 2 and int(game.generated_stage_summary["seed"]) != first_stage_seed, "next roguelike stage should increment index and change seed"):
		return
	if not _expect(game.generated_stage_summary.get("stage_variant", "") == "moonlit_cloister", "second roguelike stage should use moonlit cloister variant"):
		return

	print("E2E_OK")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
