extends SceneTree

const MODE := "manual_play_probe"
const OUTPUT_DIR := "res://artifacts/manual-play"
const SCENE_PATH := "res://scenes/main.tscn"
const SCENARIO_NAMES := [
	"first_enemy_approach_attack",
	"attack_while_moving",
	"jump_buffer_or_coyote",
	"enemy_lunge_tell",
	"boss_three_hits",
]

var run_id := ""
var evidence_dir := ""
var timeline: Array = []
var packed_scene: PackedScene

func _init() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	_prepare_evidence_dir()
	var failures: Array = []
	var screenshots: Array = []
	packed_scene = load(SCENE_PATH) as PackedScene
	if packed_scene == null:
		_finish("fail", failures, screenshots, [], {}, "main scene should load")
		return

	var scenarios: Array = []
	for scenario_name in SCENARIO_NAMES:
		var scenario: Dictionary = await _run_scenario(String(scenario_name))
		scenarios.append(scenario)
		for failure in scenario.get("failures", []):
			failures.append("%s: %s" % [scenario_name, String(failure)])
		for screenshot in scenario.get("screenshots", []):
			screenshots.append(screenshot)

	var primary: Dictionary = scenarios[0] if not scenarios.is_empty() else {}
	var route_log: Array = primary.get("route_log", [])
	timeline = primary.get("timeline", [])
	var stage_summary: Dictionary = primary.get("stage", {})
	var saved_screenshots := _valid_screenshots(screenshots)
	if saved_screenshots.size() < 2:
		failures.append("manual probe should save at least two evidence screenshots")
	var moved_entry: Dictionary = route_log[0] if not route_log.is_empty() else {}
	if float(moved_entry.get("moved_by", 0.0)) < 20.0:
		failures.append("held movement should move the player")
	var verdict := _build_verdict(route_log, failures)
	var timeline_path := _write_json_file("timeline.json", timeline)
	var frame_sequence := _write_frame_sequence(scenarios)
	var frame_sequence_path := _write_json_file("frame-sequence.json", frame_sequence)
	var capture_diagnostics := _capture_diagnostics()
	var capture_diagnostics_path := _write_json_file("capture-diagnostics.json", capture_diagnostics)

	var summary := {
		"mode": MODE,
		"status": "pass" if failures.is_empty() else "fail",
		"run_id": run_id,
		"evidence_dir": evidence_dir,
		"timeline_path": timeline_path,
		"frame_sequence_path": frame_sequence_path,
		"capture_diagnostics_path": capture_diagnostics_path,
		"input_model": "held_e2e_player_inputs",
		"direct_damage_used": false,
		"stage": {
			"seed": int(stage_summary.get("seed", 0)),
			"layout_style": String(stage_summary.get("layout_style", "")),
			"sigil_count": int(stage_summary.get("sigil_count", 0)),
			"enemy_count": int(stage_summary.get("enemy_count", 0)),
		},
		"player": primary.get("player", {}),
		"route_log": route_log,
		"timeline": timeline,
		"verdict": verdict,
		"state_map_legend": _state_map_legend(),
		"frame_sequence": frame_sequence,
		"capture_diagnostics": capture_diagnostics,
		"ui_evidence": primary.get("ui_evidence", {}),
		"scenario_names": SCENARIO_NAMES,
		"scenarios": scenarios,
		"screenshots": saved_screenshots,
		"failures": failures,
	}
	var summary_path := _write_json_file("summary.json", summary)
	summary["summary_path"] = summary_path
	_write_json_file("summary.json", summary)
	print("MANUAL_PLAY_JSON " + JSON.stringify(_stdout_summary(summary)))
	quit(0 if failures.is_empty() else 1)

func _run_scenario(scenario_name: String) -> Dictionary:
	timeline = []
	var failures: Array = []
	var screenshots: Array = []
	var route_log: Array = []
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await _wait_frames(4)
	var game: Node = scene
	var player: CharacterBody2D = scene.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		failures.append("player should exist")
		return _finish_scenario(scenario_name, game, player, scene, route_log, screenshots, failures, "missing_player", {})

	match scenario_name:
		"first_enemy_approach_attack":
			_record_sample("start", game, player, null, _input_state(0.0, false, false, false), {})
			screenshots.append(await _capture("%s-start" % [scenario_name], scene))
			route_log.append(await _run_movement_probe(game, player, "movement"))
			screenshots.append(await _capture("%s-after_movement" % [scenario_name], scene))
			var enemy := _first_standard_enemy()
			route_log.append(_describe_first_enemy(player, enemy))
			route_log.append(await _run_attack_probe(game, player, enemy, "attack", 0.0))
			screenshots.append(await _capture("%s-after_attack" % [scenario_name], scene))
		"attack_while_moving":
			await _run_attack_while_moving_scenario(game, player, scene, route_log, screenshots)
		"jump_buffer_or_coyote":
			await _run_jump_scenario(game, player, scene, route_log, screenshots)
		"enemy_lunge_tell":
			await _run_enemy_lunge_tell_scenario(game, player, scene, route_log, screenshots)
		"boss_three_hits":
			await _run_boss_three_hits_scenario(game, player, scene, route_log, screenshots)
		_:
			failures.append("unknown scenario: %s" % [scenario_name])

	var metrics := _scenario_metrics(scenario_name, route_log)
	_validate_scenario_result(scenario_name, metrics, failures)
	var verdict := _build_verdict(route_log, failures)
	var scenario := _finish_scenario(scenario_name, game, player, scene, route_log, screenshots, failures, verdict.get("reason", ""), metrics)
	scene.queue_free()
	await _wait_frames(2)
	return scenario

func _finish_scenario(scenario_name: String, game: Node, player: CharacterBody2D, scene: Node, route_log: Array, screenshots: Array, failures: Array, reason: String, metrics: Dictionary) -> Dictionary:
	var stage_summary: Dictionary = game.get("generated_stage_summary") if game != null else {}
	var scenario_timeline := timeline.duplicate(true)
	var timeline_path := _write_json_file("%s-timeline.json" % [scenario_name], scenario_timeline)
	return {
		"name": scenario_name,
		"status": "pass" if failures.is_empty() else "fail",
		"stage": {
			"seed": int(stage_summary.get("seed", 0)),
			"layout_style": String(stage_summary.get("layout_style", "")),
			"sigil_count": int(stage_summary.get("sigil_count", 0)),
			"enemy_count": int(stage_summary.get("enemy_count", 0)),
		},
		"player": _player_state(game, player) if player != null else {},
		"route_log": route_log,
		"timeline": scenario_timeline,
		"timeline_path": timeline_path,
		"screenshots": _valid_screenshots(screenshots),
		"metrics": metrics,
		"ui_evidence": _ui_evidence(game),
		"verdict": {
			"status": "pass" if failures.is_empty() else "fail",
			"reason": reason,
			"evidence": "scenario_timeline_json",
		},
		"failures": failures,
	}

func _run_movement_probe(game: Node, player: CharacterBody2D, phase_name: String) -> Dictionary:
	var start_position := player.global_position
	var enemy := _first_standard_enemy()
	var held_frames := 54
	player.e2e_set_axis(1.0)
	for frame in range(held_frames):
		await physics_frame
		if frame % 9 == 0 or frame == held_frames - 1:
			_record_sample(phase_name, game, player, enemy, _input_state(1.0, false, false, false), {
				"held_frame": frame + 1,
			})
	player.e2e_set_axis(0.0)
	for frame in range(8):
		await physics_frame
		if frame == 7:
			_record_sample("%s_stop" % [phase_name], game, player, enemy, _input_state(0.0, false, false, false), {
				"settle_frame": frame + 1,
			})
	return {
		"phase": phase_name,
		"held_frames": held_frames,
		"start": _vector_to_dict(start_position),
		"end": _vector_to_dict(player.global_position),
		"moved_by": snapped(player.global_position.x - start_position.x, 0.01),
	}

func _describe_first_enemy(player: CharacterBody2D, enemy: Area2D) -> Dictionary:
	if enemy == null:
		return {
			"phase": "first_enemy",
			"found": false,
		}
	return {
		"phase": "first_enemy",
		"found": true,
		"name": enemy.name,
		"position": _vector_to_dict(enemy.global_position),
		"distance_x": snapped(enemy.global_position.x - player.global_position.x, 0.01),
		"hit_points": int(enemy.get_meta("hit_points", 0)),
		"ai_state": String(enemy.get_meta("ai_state", "")),
	}

func _run_attack_probe(game: Node, player: CharacterBody2D, enemy: Area2D, phase_name: String, axis: float) -> Dictionary:
	var health_before := int(game.get("player_health"))
	var enemy_hp_before := 0
	if enemy != null:
		enemy_hp_before = int(enemy.get_meta("hit_points", 0))
	if absf(axis) > 0.01:
		player.e2e_set_axis(axis)
	player.e2e_attack()
	for frame in range(44):
		await physics_frame
		var attack_active := _attack_active(player)
		if frame % 4 == 0 or attack_active or frame == 43:
			_record_sample(phase_name, game, player, enemy, _input_state(axis, false, frame == 0, false), {
				"attack_probe_frame": frame + 1,
			})
	player.e2e_set_axis(0.0)
	var enemy_destroyed := false
	var enemy_hp_after := 0
	if enemy != null:
		enemy_destroyed = bool(enemy.get_meta("destroyed", false))
		enemy_hp_after = int(enemy.get_meta("hit_points", 0))
	var damage_taken := health_before - int(game.get("player_health"))
	var result_reason := "hit_landed_after_approach" if enemy_hp_after < enemy_hp_before or enemy_destroyed else "missed_due_to_range_or_timing"
	if damage_taken > 0:
		result_reason = "took_contact_before_or_during_attack"
	return {
		"phase": phase_name,
		"used_input": "e2e_attack",
		"enemy_hp_before": enemy_hp_before,
		"enemy_hp_after": enemy_hp_after,
		"enemy_destroyed": enemy_destroyed,
		"hit": enemy_hp_after < enemy_hp_before or enemy_destroyed,
		"miss": enemy_hp_after >= enemy_hp_before and not enemy_destroyed,
		"player_damage_taken": damage_taken,
		"reason": result_reason,
	}

func _run_attack_while_moving_scenario(game: Node, player: CharacterBody2D, scene: Node, route_log: Array, screenshots: Array) -> void:
	screenshots.append(await _capture("attack_while_moving-start", scene))
	route_log.append(await _run_movement_probe(game, player, "approach_before_moving_attack"))
	var enemy := _first_standard_enemy()
	route_log.append(_describe_first_enemy(player, enemy))
	route_log.append(await _run_attack_probe(game, player, enemy, "attack_while_moving", 1.0))
	screenshots.append(await _capture("attack_while_moving-after_attack", scene))

func _run_jump_scenario(game: Node, player: CharacterBody2D, scene: Node, route_log: Array, screenshots: Array) -> void:
	screenshots.append(await _capture("jump_buffer_or_coyote-start", scene))
	var before_y := player.global_position.y
	player.global_position.y -= 18.0
	player.velocity = Vector2(0.0, 720.0)
	await physics_frame
	player.e2e_jump()
	var min_velocity_after_input := 9999.0
	var airborne_seen := false
	var buffered_jump_triggered := false
	for frame in range(20):
		await physics_frame
		min_velocity_after_input = minf(min_velocity_after_input, player.velocity.y)
		airborne_seen = airborne_seen or not player.is_on_floor()
		buffered_jump_triggered = buffered_jump_triggered or player.velocity.y < -100.0
		if frame % 3 == 0 or frame == 19:
			_record_sample("jump_buffer_or_coyote", game, player, _first_standard_enemy(), _input_state(0.0, frame == 0, false, false), {
				"jump_probe_frame": frame + 1,
			})
	route_log.append({
		"phase": "jump_buffer_or_coyote",
		"used_input": "e2e_jump",
		"start_y": snapped(before_y, 0.01),
		"end_y": snapped(player.global_position.y, 0.01),
		"jump_velocity_after_input": snapped(min_velocity_after_input, 0.01),
		"airborne_seen": airborne_seen,
		"buffered_jump_triggered": buffered_jump_triggered,
		"reason": "jump_buffer_triggered_after_near_landing_input" if buffered_jump_triggered else "jump_buffer_did_not_trigger",
	})
	screenshots.append(await _capture("jump_buffer_or_coyote-after_jump", scene))

func _run_enemy_lunge_tell_scenario(game: Node, player: CharacterBody2D, scene: Node, route_log: Array, screenshots: Array) -> void:
	screenshots.append(await _capture("enemy_lunge_tell-start", scene))
	var enemy := _first_standard_enemy()
	route_log.append(_describe_first_enemy(player, enemy))
	var windup_seen := false
	var attack_seen := false
	player.e2e_set_axis(1.0)
	for frame in range(36):
		await physics_frame
		if frame == 24:
			player.e2e_set_axis(0.0)
		if enemy != null:
			var enemy_state := String(enemy.get_meta("ai_state", ""))
			windup_seen = windup_seen or enemy_state == "windup"
			attack_seen = attack_seen or enemy_state == "attack"
		if frame % 3 == 0 or windup_seen or frame == 35:
			_record_sample("enemy_lunge_tell", game, player, enemy, _input_state(1.0 if frame < 24 else 0.0, false, false, false), {
				"tell_probe_frame": frame + 1,
			})
	player.e2e_set_axis(0.0)
	route_log.append({
		"phase": "enemy_lunge_tell",
		"windup_seen": windup_seen,
		"attack_seen": attack_seen,
		"reason": "windup_state_seen_before_lunge" if windup_seen else "windup_state_not_observed",
	})
	screenshots.append(await _capture("enemy_lunge_tell-after_tell", scene))

func _run_boss_three_hits_scenario(game: Node, player: CharacterBody2D, scene: Node, route_log: Array, screenshots: Array) -> void:
	var boss := _first_boss()
	if boss == null:
		route_log.append({
			"phase": "boss_three_hits",
			"found": false,
			"hits_landed": 0,
			"reason": "boss_not_found",
		})
		return
	player.global_position = boss.global_position + Vector2(-92, 29)
	player.velocity = Vector2.ZERO
	player.e2e_set_axis(0.0)
	await _wait_physics_frames(4)
	screenshots.append(await _capture("boss_three_hits-start", scene))
	var hp_before := int(boss.get_meta("hit_points", 0))
	var last_hp := hp_before
	var hits_landed := 0
	for attempt in range(5):
		player.global_position = boss.global_position + Vector2(-92, 29)
		player.velocity = Vector2.ZERO
		player.set("facing_left", false)
		await _wait_physics_frames(4)
		var entry := await _run_attack_probe(game, player, boss, "boss_three_hits", 0.0)
		var current_hp := int(boss.get_meta("hit_points", 0))
		if current_hp < last_hp or bool(boss.get_meta("destroyed", false)):
			hits_landed += maxi(last_hp - current_hp, 1)
		last_hp = current_hp
		entry["attempt"] = attempt + 1
		route_log.append(entry)
		if hits_landed >= 3:
			break
		await _wait_physics_frames(18)
	var hp_after := int(boss.get_meta("hit_points", 0))
	route_log.append({
		"phase": "boss_three_hits",
		"found": true,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"hits_landed": hits_landed,
		"boss_destroyed": bool(boss.get_meta("destroyed", false)),
		"reason": "boss_hit_with_real_attacks" if hits_landed > 0 else "boss_not_hit_by_real_attacks",
	})
	screenshots.append(await _capture("boss_three_hits-after_attacks", scene))

func _first_standard_enemy() -> Area2D:
	for node in get_nodes_in_group("enemies"):
		var enemy := node as Area2D
		if enemy != null and not enemy.is_in_group("bosses"):
			return enemy
	return null

func _first_boss() -> Area2D:
	for node in get_nodes_in_group("bosses"):
		var boss := node as Area2D
		if boss != null:
			return boss
	return null

func _capture(label: String, scene: Node) -> Dictionary:
	await _wait_frames(2)
	var image := Image.create(960, 540, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.018, 0.02, 0.024, 1.0))
	_draw_floor_band(image)
	_draw_scene_markers(image, scene)
	_draw_state_map_legend(image)
	var absolute_path := "%s/%s.png" % [evidence_dir, label]
	var error := image.save_png(absolute_path)
	return {
		"label": label,
		"path": absolute_path,
		"width": image.get_width(),
		"height": image.get_height(),
		"status": "pass" if error == OK else "fail",
	}

func _draw_floor_band(image: Image) -> void:
	image.fill_rect(Rect2i(0, 382, image.get_width(), 24), Color(0.20, 0.22, 0.26, 1.0))
	image.fill_rect(Rect2i(0, 406, image.get_width(), 38), Color(0.09, 0.10, 0.13, 1.0))

func _draw_scene_markers(image: Image, scene: Node) -> void:
	var player := scene.get_node_or_null("Player") as Node2D
	if player != null:
		_draw_marker(image, player.global_position, _legend_color("player"), Vector2i(10, 28))
		var hitbox := player.get_node_or_null("AttackHitbox") as Area2D
		if hitbox != null and hitbox.monitoring:
			_draw_marker(image, hitbox.global_position, _legend_color("attack"), Vector2i(34, 20))
	for node in get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var color := _legend_color("enemy") if not enemy.is_in_group("bosses") else _legend_color("boss")
		_draw_marker(image, enemy.global_position, color, Vector2i(12, 30))
	for node in get_nodes_in_group("sigils"):
		var sigil := node as Node2D
		if sigil != null and sigil.visible:
			_draw_marker(image, sigil.global_position, _legend_color("sigil"), Vector2i(8, 8))
	var goal := scene.get_node_or_null("Goal") as Node2D
	if goal != null:
		_draw_marker(image, goal.global_position, _legend_color("gate"), Vector2i(14, 34))

func _draw_state_map_legend(image: Image) -> void:
	var keys := ["player", "enemy", "boss", "attack", "sigil", "gate"]
	for index in range(keys.size()):
		var y := 18 + index * 14
		image.fill_rect(Rect2i(16, y, 10, 10), _legend_color(keys[index]))
		image.fill_rect(Rect2i(30, y + 3, 42, 4), Color(0.36, 0.38, 0.42, 1.0))

func _draw_marker(image: Image, world_position: Vector2, color: Color, size: Vector2i) -> void:
	var point := _world_to_image(world_position, image.get_size())
	var rect := Rect2i(point - size / 2, size)
	image.fill_rect(rect, color)

func _world_to_image(world_position: Vector2, image_size: Vector2i) -> Vector2i:
	var x := clampi(int(remap(world_position.x, 0.0, 2800.0, 32.0, float(image_size.x - 32))), 0, image_size.x - 1)
	var y := clampi(int(remap(world_position.y, 160.0, 650.0, 80.0, float(image_size.y - 80))), 0, image_size.y - 1)
	return Vector2i(x, y)

func _world_rect_to_image(rect: Dictionary, image_size: Vector2i) -> Rect2i:
	var top_left := _world_to_image(Vector2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0))), image_size)
	var bottom_right := _world_to_image(
		Vector2(float(rect.get("x", 0.0)) + float(rect.get("width", 0.0)), float(rect.get("y", 0.0)) + float(rect.get("height", 0.0))),
		image_size
	)
	var position := Vector2i(mini(top_left.x, bottom_right.x), mini(top_left.y, bottom_right.y))
	var size := Vector2i(maxi(absi(bottom_right.x - top_left.x), 4), maxi(absi(bottom_right.y - top_left.y), 4))
	return Rect2i(position, size)

func _valid_screenshots(screenshots: Array) -> Array:
	var valid: Array = []
	for entry in screenshots:
		var shot: Dictionary = entry
		if String(shot.get("status", "")) == "pass":
			valid.append(shot)
	return valid

func _wait_frames(frame_count: int) -> void:
	for frame in range(frame_count):
		await process_frame

func _wait_physics_frames(frame_count: int) -> void:
	for frame in range(frame_count):
		await physics_frame

func _vector_to_dict(value: Vector2) -> Dictionary:
	return {
		"x": snapped(value.x, 0.01),
		"y": snapped(value.y, 0.01),
	}

func _prepare_evidence_dir() -> void:
	run_id = _make_run_id()
	var base_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	evidence_dir = "%s/%s" % [base_dir, run_id]
	DirAccess.make_dir_recursive_absolute(evidence_dir)

func _make_run_id() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d-%02d%02d%02d-manual-play" % [
		int(now["year"]),
		int(now["month"]),
		int(now["day"]),
		int(now["hour"]),
		int(now["minute"]),
		int(now["second"]),
	]

func _input_state(axis: float, jump: bool, attack: bool, shoot: bool) -> Dictionary:
	return {
		"axis": snapped(axis, 0.01),
		"jump": jump,
		"attack": attack,
		"shoot": shoot,
	}

func _record_sample(phase: String, game: Node, player: CharacterBody2D, enemy: Area2D, input_state: Dictionary, result: Dictionary) -> void:
	timeline.append({
		"index": timeline.size(),
		"phase": phase,
		"input": input_state,
		"player": _player_state(game, player),
		"attack": _attack_state(player),
		"enemy": _enemy_state(player, enemy),
		"result": result,
	})

func _player_state(game: Node, player: CharacterBody2D) -> Dictionary:
	return {
		"position": _vector_to_dict(player.global_position),
		"velocity": _vector_to_dict(player.velocity),
		"facing": "left" if bool(player.get("facing_left")) else "right",
		"health": int(game.get("player_health")),
		"state": _player_state_name(player),
	}

func _player_state_name(player: CharacterBody2D) -> String:
	if bool(player.call("is_attacking")):
		return "attack"
	if bool(player.call("is_shooting")):
		return "shoot"
	if not player.is_on_floor():
		return "airborne"
	if absf(player.velocity.x) > 8.0:
		return "move"
	return "idle"

func _attack_state(player: CharacterBody2D) -> Dictionary:
	var hitbox := player.get_node_or_null("AttackHitbox") as Area2D
	var rect := {}
	if hitbox != null:
		rect = _hitbox_rect(hitbox)
	return {
		"combo_step": int(player.get("current_attack_step")),
		"attack_frame": int(player.call("current_attack_frame")),
		"active": _attack_active(player),
		"hitbox_rect": rect,
	}

func _attack_active(player: CharacterBody2D) -> bool:
	var hitbox := player.get_node_or_null("AttackHitbox") as Area2D
	return hitbox != null and hitbox.monitoring

func _hitbox_rect(hitbox: Area2D) -> Dictionary:
	var collision_shape := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var size := Vector2.ZERO
	if collision_shape != null:
		var rectangle := collision_shape.shape as RectangleShape2D
		if rectangle != null:
			size = rectangle.size
	var center := hitbox.global_position
	return {
		"x": snapped(center.x - size.x / 2.0, 0.01),
		"y": snapped(center.y - size.y / 2.0, 0.01),
		"width": snapped(size.x, 0.01),
		"height": snapped(size.y, 0.01),
	}

func _enemy_state(player: CharacterBody2D, enemy: Area2D) -> Dictionary:
	if enemy == null:
		return {}
	return {
		"name": enemy.name,
		"position": _vector_to_dict(enemy.global_position),
		"state": String(enemy.get_meta("ai_state", "")),
		"health": int(enemy.get_meta("hit_points", 0)),
		"destroyed": bool(enemy.get_meta("destroyed", false)),
		"distance_to_player": snapped(enemy.global_position.distance_to(player.global_position), 0.01),
	}

func _build_verdict(route_log: Array, failures: Array) -> Dictionary:
	var reason := "manual probe did not record a scenario reason"
	for index in range(route_log.size() - 1, -1, -1):
		var route_entry: Dictionary = route_log[index]
		if route_entry.has("reason"):
			reason = String(route_entry.get("reason", reason))
			break
	var attack_entry := {}
	for entry in route_log:
		var route_entry: Dictionary = entry
		if String(route_entry.get("phase", "")) == "attack":
			attack_entry = route_entry
			break
	if not attack_entry.is_empty():
		reason = String(attack_entry.get("reason", reason))
	return {
		"status": "pass" if failures.is_empty() else "fail",
		"reason": reason,
		"evidence": "timeline_json_and_state_map_frames",
	}

func _scenario_metrics(scenario_name: String, route_log: Array) -> Dictionary:
	match scenario_name:
		"jump_buffer_or_coyote":
			var jump_entry := _last_route_entry(route_log, "jump_buffer_or_coyote")
			return {
				"jump_velocity_after_input": snapped(float(jump_entry.get("jump_velocity_after_input", 0.0)), 0.01),
				"airborne_seen": bool(jump_entry.get("airborne_seen", false)),
				"buffered_jump_triggered": bool(jump_entry.get("buffered_jump_triggered", false)),
			}
		"enemy_lunge_tell":
			var tell_entry := _last_route_entry(route_log, "enemy_lunge_tell")
			return {
				"windup_seen": bool(tell_entry.get("windup_seen", false)),
				"attack_seen": bool(tell_entry.get("attack_seen", false)),
			}
		"boss_three_hits":
			var boss_entry := _last_route_entry(route_log, "boss_three_hits")
			return {
				"hits_landed": int(boss_entry.get("hits_landed", 0)),
				"boss_destroyed": bool(boss_entry.get("boss_destroyed", false)),
			}
		"attack_while_moving":
			var attack_entry := _last_route_entry(route_log, "attack_while_moving")
			return {
				"hit": bool(attack_entry.get("hit", false)),
				"player_damage_taken": int(attack_entry.get("player_damage_taken", 0)),
			}
		_:
			var movement_entry := _last_route_entry(route_log, "movement")
			var first_attack_entry := _last_route_entry(route_log, "attack")
			return {
				"moved_by": snapped(float(movement_entry.get("moved_by", 0.0)), 0.01),
				"hit": bool(first_attack_entry.get("hit", false)),
			}

func _validate_scenario_result(scenario_name: String, metrics: Dictionary, failures: Array) -> void:
	match scenario_name:
		"jump_buffer_or_coyote":
			pass
		"enemy_lunge_tell":
			if not bool(metrics.get("windup_seen", false)):
				failures.append("enemy lunge scenario should observe windup before attack")
		"boss_three_hits":
			if int(metrics.get("hits_landed", 0)) < 3:
				failures.append("boss scenario should land three real attacks")
		_:
			pass

func _last_route_entry(route_log: Array, phase_name: String) -> Dictionary:
	for index in range(route_log.size() - 1, -1, -1):
		var entry: Dictionary = route_log[index]
		if String(entry.get("phase", "")) == phase_name:
			return entry
	return {}

func _write_json_file(file_name: String, value) -> String:
	var absolute_path := "%s/%s" % [evidence_dir, file_name]
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return absolute_path
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	return absolute_path

func _write_frame_sequence(scenarios: Array) -> Array:
	var frames: Array = []
	for scenario_value in scenarios:
		var scenario: Dictionary = scenario_value
		var scenario_name := String(scenario.get("name", "scenario"))
		var scenario_timeline: Array = scenario.get("timeline", [])
		var selected_indexes := _selected_frame_indexes(scenario_timeline)
		for selected_index in selected_indexes:
			var sample: Dictionary = scenario_timeline[selected_index]
			var label := _frame_label(scenario_name, sample)
			var path := _write_sample_frame(label, sample)
			frames.append({
				"label": label,
				"path": path,
				"scenario": scenario_name,
				"timeline_index": int(sample.get("index", selected_index)),
			})
	return frames

func _selected_frame_indexes(samples: Array) -> Array[int]:
	var selected: Array[int] = []
	if samples.is_empty():
		return selected
	selected.append(0)
	for index in range(samples.size()):
		var sample: Dictionary = samples[index]
		if bool(sample.get("attack", {}).get("active", false)):
			selected.append(index)
		var enemy: Dictionary = sample.get("enemy", {})
		if String(enemy.get("state", "")) == "windup":
			selected.append(index)
		if selected.size() >= 4:
			break
	if not selected.has(samples.size() - 1):
		selected.append(samples.size() - 1)
	return selected

func _frame_label(scenario_name: String, sample: Dictionary) -> String:
	var label := "%s-%03d" % [scenario_name, int(sample.get("index", 0))]
	if bool(sample.get("attack", {}).get("active", false)):
		label += "-attack-active"
	var enemy: Dictionary = sample.get("enemy", {})
	if bool(enemy.get("destroyed", false)):
		label += "-hit"
	elif String(sample.get("phase", "")).contains("attack") and not bool(sample.get("attack", {}).get("active", false)):
		label += "-miss-window"
	if String(enemy.get("state", "")) == "windup":
		label += "-windup"
	return label

func _write_sample_frame(label: String, sample: Dictionary) -> String:
	var image := Image.create(960, 540, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.018, 0.02, 0.024, 1.0))
	_draw_floor_band(image)
	_draw_state_map_legend(image)
	var player: Dictionary = sample.get("player", {})
	if not player.is_empty():
		_draw_marker(image, _dict_to_vector(player.get("position", {})), _legend_color("player"), Vector2i(10, 28))
	var enemy: Dictionary = sample.get("enemy", {})
	if not enemy.is_empty():
		var enemy_key := "boss" if String(enemy.get("name", "")).to_lower().contains("boss") else "enemy"
		_draw_marker(image, _dict_to_vector(enemy.get("position", {})), _legend_color(enemy_key), Vector2i(12, 30))
	var attack: Dictionary = sample.get("attack", {})
	var rect: Dictionary = attack.get("hitbox_rect", {})
	if not rect.is_empty():
		var image_rect := _world_rect_to_image(rect, image.get_size())
		var color := _legend_color("attack")
		color.a = 0.92 if bool(attack.get("active", false)) else 0.35
		image.fill_rect(image_rect, color)
	var path := "%s/%s.png" % [evidence_dir, label]
	image.save_png(path)
	return path

func _dict_to_vector(value) -> Vector2:
	var dict: Dictionary = value if value is Dictionary else {}
	return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))

func _state_map_legend() -> Dictionary:
	return {
		"player": {"label": "player", "color": "#e6e8ef"},
		"enemy": {"label": "enemy", "color": "#d43a42"},
		"boss": {"label": "boss", "color": "#ff6a4a"},
		"attack": {"label": "attack hitbox", "color": "#64d2ff"},
		"sigil": {"label": "sigil", "color": "#ffd166"},
		"gate": {"label": "gate", "color": "#b26cff"},
	}

func _legend_color(key: String) -> Color:
	match key:
		"player":
			return Color(0.90, 0.91, 0.94, 1.0)
		"enemy":
			return Color(0.83, 0.23, 0.26, 1.0)
		"boss":
			return Color(1.0, 0.42, 0.29, 1.0)
		"attack":
			return Color(0.39, 0.82, 1.0, 1.0)
		"sigil":
			return Color(1.0, 0.82, 0.40, 1.0)
		"gate":
			return Color(0.70, 0.42, 1.0, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)

func _capture_diagnostics() -> Dictionary:
	return {
		"status": "unavailable",
		"method": "godot_headless_state_map_fallback",
		"reason": "manual play probe runs in Godot --headless, so real window capture is not available from this command",
	}

func _ui_evidence(game: Node) -> Dictionary:
	var tutorial := game.get_node_or_null("CanvasLayer/TutorialLabel") as Label
	var sigils := game.get_node_or_null("CanvasLayer/HUDPanel/SigilCountLabel") as Label
	var boss := game.get_node_or_null("CanvasLayer/BossHealthPanel/BossHealthLabel") as Label
	return {
		"objective_text": tutorial.text if tutorial != null else "",
		"sigil_text": sigils.text if sigils != null else "",
		"boss_text": boss.text if boss != null else "",
	}

func _stdout_summary(summary: Dictionary) -> Dictionary:
	return {
		"mode": summary.get("mode", MODE),
		"status": summary.get("status", "fail"),
		"run_id": summary.get("run_id", run_id),
		"evidence_dir": summary.get("evidence_dir", evidence_dir),
		"summary_path": summary.get("summary_path", ""),
		"timeline_path": summary.get("timeline_path", ""),
		"scenario_names": summary.get("scenario_names", []),
		"input_model": summary.get("input_model", "held_e2e_player_inputs"),
		"direct_damage_used": summary.get("direct_damage_used", false),
	}

func _finish(status: String, failures: Array, screenshots: Array, route_log: Array, stage: Dictionary, message: String) -> void:
	if run_id.is_empty():
		_prepare_evidence_dir()
	failures.append(message)
	var summary := {
		"mode": MODE,
		"status": status,
		"run_id": run_id,
		"evidence_dir": evidence_dir,
		"input_model": "held_e2e_player_inputs",
		"direct_damage_used": false,
		"stage": stage,
		"route_log": route_log,
		"timeline": timeline,
		"timeline_path": _write_json_file("timeline.json", timeline),
		"screenshots": screenshots,
		"verdict": {
			"status": "fail",
			"reason": message,
			"evidence": "startup_failure",
		},
		"failures": failures,
	}
	summary["summary_path"] = _write_json_file("summary.json", summary)
	_write_json_file("summary.json", summary)
	print("MANUAL_PLAY_JSON " + JSON.stringify(_stdout_summary(summary)))
	quit(1)
