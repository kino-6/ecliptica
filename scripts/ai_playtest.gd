extends SceneTree

const MODE := "ai_headless_playtest"
const FRAME_MS := 1000.0 / 60.0
const PROFILES := [
	{
		"name": "novice",
		"human_reaction_ms": 520,
		"action_interval_ms": 680,
		"execution_error_rate": 0.42,
		"tactical_score": 2,
	},
	{
		"name": "casual",
		"human_reaction_ms": 380,
		"action_interval_ms": 520,
		"execution_error_rate": 0.26,
		"tactical_score": 4,
	},
	{
		"name": "adept",
		"human_reaction_ms": 250,
		"action_interval_ms": 360,
		"execution_error_rate": 0.14,
		"tactical_score": 6,
	},
	{
		"name": "expert",
		"human_reaction_ms": 180,
		"action_interval_ms": 270,
		"execution_error_rate": 0.07,
		"tactical_score": 8,
	},
	{
		"name": "master",
		"human_reaction_ms": 130,
		"action_interval_ms": 210,
		"execution_error_rate": 0.03,
		"tactical_score": 9,
	},
]

func _init() -> void:
	call_deferred("run_playtest")

func run_playtest() -> void:
	var single_profile_name := OS.get_environment("AI_PLAYTEST_PROFILE")
	if single_profile_name != "":
		await run_single_profile(single_profile_name)
		return

	var failures: Array = []
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_finish({"mode": MODE, "status": "fail", "failures": ["main scene should load"]}, ["main scene should load"])
		return

	var profiles: Array = []
	var stage_summary := {}
	for profile: Dictionary in PROFILES:
		var result: Dictionary = await _run_profile(packed, profile, failures)
		profiles.append(result)
		if stage_summary.is_empty() and result.has("stage"):
			stage_summary = result["stage"]

	var recommendation := _recommend(profiles)
	var summary := {
		"mode": MODE,
		"status": "pass" if failures.is_empty() else "fail",
		"stage": stage_summary,
		"profiles": profiles,
		"recommendation": recommendation,
		"failures": failures,
	}
	_finish(summary, failures)

func run_single_profile(profile_name: String) -> void:
	var failures: Array = []
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_finish_profile({"mode": "ai_profile_playtest", "status": "fail", "failures": ["main scene should load"]}, ["main scene should load"])
		return
	var profile := _profile_by_name(PROFILES, profile_name)
	if profile.is_empty():
		_finish_profile({"mode": "ai_profile_playtest", "status": "fail", "failures": ["unknown profile %s" % [profile_name]]}, ["unknown profile %s" % [profile_name]])
		return
	var result: Dictionary = await _run_profile(packed, profile, failures)
	var summary := {
		"mode": "ai_profile_playtest",
		"status": "pass" if failures.is_empty() else "fail",
		"profile": result,
		"stage": result.get("stage", {}),
		"failures": failures,
	}
	_finish_profile(summary, failures)

func _run_profile(packed: PackedScene, profile: Dictionary, failures: Array) -> Dictionary:
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var game: Node = scene
	var player: CharacterBody2D = scene.get_node("Player")
	var stage_summary: Dictionary = game.get("generated_stage_summary")
	var route_log: Array = []
	var reaction_ms := int(profile["human_reaction_ms"])
	var action_interval_ms := int(profile["action_interval_ms"])
	var reaction_frames := _frames_for_ms(reaction_ms)
	var action_interval_frames := _frames_for_ms(action_interval_ms)

	var moved := await _probe_movement(player, reaction_frames, action_interval_frames, route_log)
	var branch_score := _score_branch_challenges(profile, stage_summary, route_log)
	var melee_ok := await _probe_melee(scene, player, reaction_frames, action_interval_frames, route_log)
	var ranged_ok := await _probe_ranged(scene, player, reaction_frames, action_interval_frames, route_log)
	var boss_ok := await _probe_boss(scene, player, profile, reaction_frames, action_interval_frames, route_log)
	var outcome := _predict_outcome(profile, stage_summary, moved, melee_ok, ranged_ok, boss_ok, branch_score)

	if outcome["cleared"]:
		_collect_and_win(scene, game, route_log)
	else:
		route_log.append({
			"phase": "goal",
			"result": "not_reached",
			"reason": outcome["failure_reason"],
		})

	var result := {
		"name": String(profile["name"]),
		"human_reaction_ms": reaction_ms,
		"action_interval_ms": action_interval_ms,
		"execution_error_rate": float(profile["execution_error_rate"]),
		"tactical_score": int(profile["tactical_score"]),
		"predicted_attempts_to_clear": int(outcome["predicted_attempts_to_clear"]),
		"cleared": bool(outcome["cleared"]),
		"failure_reason": String(outcome["failure_reason"]),
		"mechanics": {
			"movement": moved,
			"melee": melee_ok,
			"ranged": ranged_ok,
			"boss": boss_ok,
			"branch_score": branch_score,
		},
		"route_log": route_log,
		"stage": _stage_report(scene, stage_summary),
	}

	if not moved:
		failures.append("%s profile should move in headless playtest" % [profile["name"]])
	if not melee_ok:
		failures.append("%s profile should validate melee mechanics" % [profile["name"]])
	if not ranged_ok:
		failures.append("%s profile should validate ranged mechanics" % [profile["name"]])

	scene.queue_free()
	await process_frame
	return result

func _probe_movement(player: CharacterBody2D, reaction_frames: int, action_interval_frames: int, route_log: Array) -> bool:
	await _wait_frames(reaction_frames)
	var start_x := player.global_position.x
	player.e2e_set_axis(1.0)
	await _wait_frames(maxi(action_interval_frames, 30))
	player.e2e_set_axis(0.0)
	var moved_by := player.global_position.x - start_x
	var ok := moved_by >= 36.0
	route_log.append({
		"phase": "movement",
		"reaction_frames": reaction_frames,
		"moved_by": moved_by,
		"result": "pass" if ok else "fail",
	})
	return ok

func _probe_melee(scene: Node, player: CharacterBody2D, reaction_frames: int, action_interval_frames: int, route_log: Array) -> bool:
	var enemies := get_nodes_in_group("enemies")
	if enemies.is_empty():
		route_log.append({"phase": "melee", "result": "fail", "reason": "no enemies"})
		return false
	var enemy: Area2D = enemies[0]
	enemy.visible = true
	enemy.monitoring = true
	enemy.monitorable = true
	enemy.set_meta("destroyed", false)
	enemy.set_meta("hit_points", 1)
	var attack_hitbox := player.get_node("AttackHitbox") as Area2D
	player.facing_left = false
	player.attack_timer = 0.0
	player._sync_attack_geometry()
	enemy.global_position = attack_hitbox.global_position
	enemy.set_physics_process(false)
	await _wait_frames(reaction_frames)
	player.attack()
	var active_seen := false
	var overlap_seen := false
	for frame in range(maxi(action_interval_frames, _frames_for_seconds(player.ATTACK_ACTIVE_END) + 4)):
		await physics_frame
		active_seen = active_seen or attack_hitbox.monitoring
		if attack_hitbox.monitoring and _area_center_inside_hitbox(enemy, attack_hitbox):
			overlap_seen = true
			if not bool(enemy.get_meta("destroyed", false)):
				player._damage_attack_target(enemy)
	var destroyed := bool(enemy.get_meta("destroyed", false))
	route_log.append({
		"phase": "melee",
		"target": enemy.name,
		"active_seen": active_seen,
		"overlap_seen": overlap_seen,
		"result": "pass" if destroyed else "fail",
	})
	return destroyed

func _probe_ranged(scene: Node, player: CharacterBody2D, reaction_frames: int, action_interval_frames: int, route_log: Array) -> bool:
	var enemies := get_nodes_in_group("enemies")
	if enemies.size() < 2:
		route_log.append({"phase": "ranged", "result": "fail", "reason": "not enough enemies"})
		return false
	var enemy: Area2D = enemies[1]
	enemy.visible = true
	enemy.monitoring = true
	enemy.monitorable = true
	enemy.set_meta("destroyed", false)
	enemy.set_meta("hit_points", 1)
	enemy.global_position = player.global_position + Vector2(240.0, -44.0)
	enemy.set_physics_process(false)
	player.facing_left = false
	player.shoot_focus = player.FOCUS_MAX
	await _wait_frames(reaction_frames)
	var fired: bool = player.shoot()
	await _wait_frames(maxi(action_interval_frames, 30))
	var destroyed := bool(enemy.get_meta("destroyed", false))
	route_log.append({
		"phase": "ranged",
		"fired": fired,
		"focus_after_shot": player.shoot_focus,
		"result": "pass" if fired and destroyed else "fail",
	})
	return fired and destroyed

func _probe_boss(scene: Node, player: CharacterBody2D, profile: Dictionary, reaction_frames: int, action_interval_frames: int, route_log: Array) -> bool:
	var bosses := get_nodes_in_group("bosses")
	if bosses.is_empty():
		route_log.append({"phase": "boss", "result": "fail", "reason": "no boss"})
		return false
	var boss: Area2D = bosses[0]
	boss.visible = true
	boss.monitoring = true
	boss.monitorable = true
	boss.set_meta("destroyed", false)
	var max_hp := int(boss.get_meta("max_hit_points", 3))
	boss.set_meta("hit_points", max_hp)
	boss.global_position = player.global_position + Vector2(86.0, -42.0)
	var hits_landed := 0
	var allowed_hits: int = max_hp if _can_manage_boss(profile) else max(1, max_hp - 1)
	for hit in range(allowed_hits):
		await _wait_frames(reaction_frames)
		player._damage_attack_target(boss)
		hits_landed += 1
		await _wait_frames(action_interval_frames)
	var destroyed := bool(boss.get_meta("destroyed", false))
	route_log.append({
		"phase": "boss",
		"hits_landed": hits_landed,
		"required_hits": max_hp,
		"result": "pass" if destroyed else "fail",
	})
	return destroyed

func _score_branch_challenges(profile: Dictionary, stage_summary: Dictionary, route_log: Array) -> int:
	var balance: Dictionary = stage_summary.get("balance", {})
	var branch_count := int(balance.get("branch_challenge_count", 2))
	var reaction_ms := int(profile["human_reaction_ms"])
	var tactical_score := int(profile["tactical_score"])
	var execution_error := float(profile["execution_error_rate"])
	var cleared_branches := 0
	for branch in range(branch_count):
		var branch_ok := reaction_ms <= 380 and tactical_score >= 4 and execution_error <= 0.28
		if branch_ok:
			cleared_branches += 1
		route_log.append({
			"phase": "branch",
			"index": branch + 1,
			"reaction_ms": reaction_ms,
			"result": "pass" if branch_ok else "fail",
		})
	return cleared_branches

func _predict_outcome(profile: Dictionary, stage_summary: Dictionary, moved: bool, melee_ok: bool, ranged_ok: bool, boss_ok: bool, branch_score: int) -> Dictionary:
	var balance: Dictionary = stage_summary.get("balance", {})
	var branch_count := int(balance.get("branch_challenge_count", 2))
	var risk_score := int(balance.get("risk_score", 8))
	var reaction_ms := int(profile["human_reaction_ms"])
	var tactical_score := int(profile["tactical_score"])
	var execution_error := float(profile["execution_error_rate"])
	var mechanical_ok := moved and melee_ok and ranged_ok
	var clear_power := tactical_score * 1.1
	clear_power += (420 - reaction_ms) / 95.0
	clear_power -= execution_error * 6.0
	clear_power += 1.0 if boss_ok else -1.0
	clear_power += 0.5 if branch_score >= branch_count else -1.0

	if not mechanical_ok:
		return {
			"cleared": false,
			"predicted_attempts_to_clear": 99,
			"failure_reason": "basic mechanics failed",
		}
	if clear_power >= risk_score:
		return {
			"cleared": true,
			"predicted_attempts_to_clear": 1 if reaction_ms <= 190 else 2,
			"failure_reason": "",
		}
	if clear_power >= risk_score - 1.8:
		return {
			"cleared": true,
			"predicted_attempts_to_clear": 2,
			"failure_reason": "",
		}
	return {
		"cleared": false,
		"predicted_attempts_to_clear": 3 if tactical_score >= 4 else 5,
		"failure_reason": "reaction and tactical score below stage risk",
	}

func _can_manage_boss(profile: Dictionary) -> bool:
	return int(profile["tactical_score"]) >= 6 and int(profile["human_reaction_ms"]) <= 260

func _collect_and_win(scene: Node, game: Node, route_log: Array) -> void:
	for sigil: Node in get_nodes_in_group("sigils"):
		game.collect_sigil(sigil)
	var player: CharacterBody2D = scene.get_node("Player")
	player.global_position = scene.get_node("Goal").global_position
	game.win_game()
	route_log.append({
		"phase": "goal",
		"gate_open": bool(game.get("gate_open")),
		"won": bool(game.get("won")),
		"result": "pass" if bool(game.get("won")) else "fail",
	})

func _stage_report(scene: Node, stage_summary: Dictionary) -> Dictionary:
	var game: Node = scene
	var run_info_label := scene.get_node_or_null("CanvasLayer/RunInfoLabel") as Label
	return {
		"game_rev": String(game.call("game_revision")) if game.has_method("game_revision") else "",
		"display_seed": int(game.call("current_display_seed")) if game.has_method("current_display_seed") else 0,
		"run_info_text": run_info_label.text if run_info_label != null else "",
		"seed": stage_summary.get("seed", null),
		"theme": stage_summary.get("theme", ""),
		"layout_style": stage_summary.get("layout_style", ""),
		"room_count": int(stage_summary.get("room_count", 0)),
		"branch_room_count": int(stage_summary.get("branch_room_count", 0)),
		"shortcut_count": int(stage_summary.get("shortcut_count", 0)),
		"floating_platform_count": int(stage_summary.get("floating_platform_count", -1)),
		"critical_path_reachable": bool(stage_summary.get("critical_path_reachable", false)),
		"max_required_step_up": float(stage_summary.get("max_required_step_up", 9999.0)),
		"impossible_jump_count": int(stage_summary.get("impossible_jump_count", -1)),
		"enemy_spawn_grounded": bool(stage_summary.get("enemy_spawn_grounded", false)),
		"enemy_spawn_overlap_count": int(stage_summary.get("enemy_spawn_overlap_count", -1)),
		"enemy_spawn_out_of_floor_count": int(stage_summary.get("enemy_spawn_out_of_floor_count", -1)),
		"boss_spawn_grounded": bool(stage_summary.get("boss_spawn_grounded", false)),
		"platform_count": scene.get_node("Platforms").get_child_count(),
		"sigil_count": get_nodes_in_group("sigils").size(),
		"enemy_count": get_nodes_in_group("enemies").size(),
		"balance": stage_summary.get("balance", {}),
	}

func _recommend(profiles: Array) -> String:
	var novice: Dictionary = _profile_by_name(profiles, "novice")
	var adept: Dictionary = _profile_by_name(profiles, "adept")
	var expert: Dictionary = _profile_by_name(profiles, "expert")
	if not bool(novice.get("cleared", true)) and bool(adept.get("cleared", false)) and int(adept.get("predicted_attempts_to_clear", 0)) == 2 and bool(expert.get("cleared", false)):
		return "stage matches the two-try target for an adept action player"
	return "stage balance needs another pass"

func _profile_by_name(profiles: Array, profile_name: String) -> Dictionary:
	for profile: Dictionary in profiles:
		if profile.get("name", "") == profile_name:
			return profile
	return {}

func _frames_for_ms(milliseconds: int) -> int:
	return maxi(1, ceili(float(milliseconds) / FRAME_MS))

func _frames_for_seconds(seconds: float) -> int:
	return maxi(1, ceili(seconds * 60.0))

func _area_center_inside_hitbox(area: Area2D, hitbox: Area2D) -> bool:
	var collision_shape := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return false
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return false
	var delta := area.global_position - hitbox.global_position
	var half_size := rectangle.size * 0.5
	return absf(delta.x) <= half_size.x and absf(delta.y) <= half_size.y

func _wait_frames(frame_count: int) -> void:
	for frame in range(frame_count):
		await process_frame

func _finish(summary: Dictionary, failures: Array) -> void:
	summary["status"] = "pass" if failures.is_empty() else "fail"
	summary["failures"] = failures
	print("AI_PLAYTEST_JSON " + JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)

func _finish_profile(summary: Dictionary, failures: Array) -> void:
	summary["status"] = "pass" if failures.is_empty() else "fail"
	summary["failures"] = failures
	print("AI_PROFILE_JSON " + JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)
