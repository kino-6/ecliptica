extends SceneTree

const MODE := "window_manual_play_probe"
const OUTPUT_DIR := "res://artifacts/window-manual-play"
const SCENE_PATH := "res://scenes/main.tscn"
const SCENARIO_NAMES := ["first_enemy", "first_sigil", "boss_reveal"]

var run_id := ""
var evidence_dir := ""

func _init() -> void:
	call_deferred("run_probe")

func run_probe() -> void:
	_prepare_evidence_dir()
	var failures: Array = []
	var screenshots: Array = []
	var route_log: Array = []
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		_finish("fail", failures, screenshots, route_log, "main scene should load")
		return

	print("WINDOW_MANUAL_PLAY_START display=%s" % [DisplayServer.get_name()])
	if DisplayServer.get_name() == "headless":
		_finish("fail", failures, screenshots, route_log, "window manual play must run without --headless")
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await _wait_frames(8)

	var game: Node = scene
	var player: CharacterBody2D = scene.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		_finish("fail", failures, screenshots, route_log, "player should exist")
		return

	screenshots.append(await _capture_viewport("window-start"))
	var start_ui_evidence := _ui_evidence(game)
	var enemy := _first_standard_enemy()
	var windup_evidence := _empty_windup_evidence()
	route_log.append(await _run_movement_probe(player, enemy, screenshots, windup_evidence))
	screenshots.append(await _capture_viewport("window-after_movement"))
	route_log.append(_describe_first_enemy(player, enemy))
	if not bool(windup_evidence.get("windup_frame_captured", false)):
		windup_evidence["reason"] = "windup_state_not_observed"
		if enemy != null:
			windup_evidence["enemy_state"] = String(enemy.get_meta("ai_state", ""))
	route_log.append(windup_evidence)
	var attack_entry: Dictionary = await _run_attack_probe(game, player, enemy, screenshots)
	route_log.append(attack_entry)
	screenshots.append(await _capture_viewport("window-after_attack"))
	screenshots.append(await _capture_viewport("window-after_first_enemy"))
	var sigil_evidence: Dictionary = await _run_first_sigil_probe(game, player, screenshots)
	route_log.append(sigil_evidence)
	var boss_evidence: Dictionary = await _run_boss_reveal_probe(game, player, screenshots)
	route_log.append(boss_evidence)

	var saved_screenshots := _valid_screenshots(screenshots)
	if saved_screenshots.size() < 7:
		failures.append("window manual play should save movement and attack moment viewport screenshots")
	if not bool(windup_evidence.get("windup_frame_captured", false)):
		failures.append("window manual play should capture an enemy windup frame")
	if not bool(attack_entry.get("hit", false)):
		failures.append("window manual play should hit the first enemy with real attack input")
	var hit_evidence: Dictionary = attack_entry.get("hit_evidence", {})
	if not bool(hit_evidence.get("attack_active_captured", false)):
		failures.append("window manual play should capture an active attack frame")
	if not bool(hit_evidence.get("hit_frame_captured", false)):
		failures.append("window manual play should capture the hit frame")
	if not bool(sigil_evidence.get("next_sigil_visible", false)):
		failures.append("window manual play should capture the next sigil in the real viewport")
	if not bool(sigil_evidence.get("pickup_captured", false)):
		failures.append("window manual play should collect the first sigil after the first enemy")
	if not bool(boss_evidence.get("boss_hp_visible", false)):
		failures.append("window manual play should capture boss HP reveal evidence")

	var summary := {
		"mode": MODE,
		"status": "pass" if failures.is_empty() else "fail",
		"run_id": run_id,
		"evidence_dir": evidence_dir,
		"display_name": DisplayServer.get_name(),
		"scenario_names": SCENARIO_NAMES,
		"input_model": "held_e2e_player_inputs",
		"direct_damage_used": false,
		"window": _window_info(),
		"ui_evidence": start_ui_evidence,
		"hit_evidence": hit_evidence,
		"sigil_evidence": sigil_evidence,
		"boss_evidence": boss_evidence,
		"windup_evidence": windup_evidence,
		"route_log": route_log,
		"screenshots": saved_screenshots,
		"failures": failures,
	}
	summary["summary_path"] = _write_json_file("summary.json", summary)
	_write_json_file("summary.json", summary)
	print("WINDOW_MANUAL_PLAY_JSON " + JSON.stringify(_stdout_summary(summary)))
	quit(0 if failures.is_empty() else 1)

func _run_movement_probe(player: CharacterBody2D, enemy: Area2D, screenshots: Array, windup_evidence: Dictionary) -> Dictionary:
	var start_position := player.global_position
	var held_frames := 54
	player.e2e_set_axis(1.0)
	for frame in range(held_frames):
		await physics_frame
		if not bool(windup_evidence.get("windup_frame_captured", false)) and enemy != null:
			var state := String(enemy.get_meta("ai_state", ""))
			if state == "windup":
				screenshots.append(await _capture_viewport("window-enemy-windup"))
				windup_evidence["windup_frame_captured"] = true
				windup_evidence["frame"] = frame + 1
				windup_evidence["enemy_state"] = state
				windup_evidence["tell_visible"] = bool(enemy.get_meta("windup_tell_visible", false))
				windup_evidence["windup_direction"] = String(enemy.get_meta("windup_direction", ""))
				windup_evidence["reason"] = "windup_state_seen_during_approach"
	player.e2e_set_axis(0.0)
	await _wait_physics_frames(8)
	return {
		"phase": "movement",
		"held_frames": held_frames,
		"start": _vector_to_dict(start_position),
		"end": _vector_to_dict(player.global_position),
		"moved_by": snapped(player.global_position.x - start_position.x, 0.01),
	}

func _empty_windup_evidence() -> Dictionary:
	return {
		"phase": "enemy_windup",
		"windup_frame_captured": false,
		"tell_visible": false,
		"windup_direction": "",
		"reason": "not_checked",
	}

func _run_attack_probe(game: Node, player: CharacterBody2D, enemy: Area2D, screenshots: Array) -> Dictionary:
	var health_before := int(game.get("player_health"))
	var enemy_hp_before := 0
	if enemy != null:
		enemy_hp_before = int(enemy.get_meta("hit_points", 0))
	player.e2e_attack()
	screenshots.append(await _capture_viewport("window-attack-start"))
	var attack_active_captured := false
	var hit_frame_captured := false
	var follow_through_captured := false
	var hit_spark_visible := false
	var enemy_reaction_visible := false
	var hit_frame := -1
	var follow_through_frame := -1
	for frame in range(44):
		await physics_frame
		if not attack_active_captured and _attack_active(player):
			screenshots.append(await _capture_viewport("window-attack-active"))
			attack_active_captured = true
		var attack_frame := int(player.call("current_attack_frame"))
		if not follow_through_captured and attack_frame >= 6:
			screenshots.append(await _capture_viewport("window-attack-follow-through"))
			follow_through_captured = true
			follow_through_frame = frame + 1
		if enemy != null:
			var current_hp := int(enemy.get_meta("hit_points", 0))
			var destroyed := bool(enemy.get_meta("destroyed", false))
			if not hit_frame_captured and (current_hp < enemy_hp_before or destroyed):
				hit_spark_visible = _hit_spark_visible(game)
				enemy_reaction_visible = enemy.visible and bool(enemy.get_meta("hit_flash_started", false))
				screenshots.append(await _capture_viewport("window-hit-frame", 1))
				hit_spark_visible = hit_spark_visible or _hit_spark_visible(game)
				enemy_reaction_visible = enemy_reaction_visible or (enemy.visible and bool(enemy.get_meta("hit_flash_started", false)))
				screenshots.append(await _capture_viewport("window-hit-spark", 1))
				hit_spark_visible = hit_spark_visible or _hit_spark_visible(game)
				enemy_reaction_visible = enemy_reaction_visible or (enemy.visible and bool(enemy.get_meta("hit_flash_started", false)))
				hit_frame_captured = true
				hit_frame = frame + 1
				if not follow_through_captured:
					screenshots.append(await _capture_viewport("window-attack-follow-through", 4))
					follow_through_captured = true
					follow_through_frame = frame + 5
	var enemy_destroyed := false
	var enemy_hp_after := 0
	if enemy != null:
		enemy_destroyed = bool(enemy.get_meta("destroyed", false))
		enemy_hp_after = int(enemy.get_meta("hit_points", 0))
	return {
		"phase": "attack",
		"used_input": "e2e_attack",
		"enemy_hp_before": enemy_hp_before,
		"enemy_hp_after": enemy_hp_after,
		"enemy_destroyed": enemy_destroyed,
		"hit": enemy_hp_after < enemy_hp_before or enemy_destroyed,
		"player_damage_taken": health_before - int(game.get("player_health")),
		"reason": "hit_landed_in_real_window" if enemy_hp_after < enemy_hp_before or enemy_destroyed else "missed_in_real_window",
		"hit_evidence": {
			"attack_active_captured": attack_active_captured,
			"hit_frame_captured": hit_frame_captured,
			"follow_through_captured": follow_through_captured,
			"hit_frame": hit_frame,
			"follow_through_frame": follow_through_frame,
			"hit_spark_visible": hit_spark_visible,
			"enemy_reaction_visible": enemy_reaction_visible,
		},
	}

func _attack_active(player: CharacterBody2D) -> bool:
	var hitbox := player.get_node_or_null("AttackHitbox") as Area2D
	return hitbox != null and hitbox.monitoring

func _hit_spark_visible(game: Node) -> bool:
	var projectiles := game.get_node_or_null("Projectiles")
	if projectiles == null:
		return false
	if bool(projectiles.get_meta("hit_spark_visible", false)):
		return true
	for child in projectiles.get_children():
		if String(child.name).begins_with("HitSpark") and child.visible:
			return true
	return false

func _run_first_sigil_probe(game: Node, player: CharacterBody2D, screenshots: Array) -> Dictionary:
	var start_collected := int(game.get("sigils_collected"))
	var sigil := _nearest_uncollected_sigil(player)
	var next_sigil_visible := sigil != null and sigil.visible and _is_world_point_visible(game, sigil.global_position)
	if sigil != null:
		next_sigil_visible = next_sigil_visible and bool(sigil.get_meta("next_cue_visible", false))
	screenshots.append(await _capture_viewport("window-next-sigil-visible"))
	var pickup_captured := false
	if sigil != null:
		for _frame in range(96):
			var delta_x := sigil.global_position.x - player.global_position.x
			if absf(delta_x) <= 8.0:
				player.e2e_set_axis(0.0)
			else:
				player.e2e_set_axis(1.0 if delta_x > 0.0 else -1.0)
			await physics_frame
			if int(game.get("sigils_collected")) > start_collected:
				pickup_captured = true
				break
	player.e2e_set_axis(0.0)
	await _wait_physics_frames(6)
	screenshots.append(await _capture_viewport("window-after_sigil_pickup"))
	return {
		"phase": "first_sigil",
		"setup": "real_input_after_first_enemy",
		"next_sigil_found": sigil != null,
		"next_sigil_visible": next_sigil_visible,
		"pickup_captured": pickup_captured,
		"sigils_collected_before": start_collected,
		"sigils_collected_after": int(game.get("sigils_collected")),
		"sigil_text_after": String(_ui_evidence(game).get("sigil_text", "")),
		"reason": "first_sigil_collected_with_real_movement" if pickup_captured else "first_sigil_not_collected",
	}

func _run_boss_reveal_probe(game: Node, player: CharacterBody2D, screenshots: Array) -> Dictionary:
	var boss := _first_boss()
	if boss == null:
		return {
			"phase": "boss_reveal",
			"boss_found": false,
			"boss_hp_visible": false,
			"reason": "boss_not_found",
		}
	player.global_position = boss.global_position + Vector2(-188.0, 29.0)
	player.velocity = Vector2.ZERO
	player.e2e_set_axis(0.0)
	player.set("facing_left", false)
	if game.has_method("_update_camera"):
		game.call("_update_camera")
	if game.has_method("_update_hud"):
		game.call("_update_hud")
	await _wait_physics_frames(4)
	if game.has_method("_update_camera"):
		game.call("_update_camera")
	if game.has_method("_update_hud"):
		game.call("_update_hud")
	screenshots.append(await _capture_viewport("window-boss-hp-visible"))
	var ui := _ui_evidence(game)
	var health_before := int(game.get("player_health"))
	var contact_damage_captured := false
	var contact_position := player.global_position
	for _frame in range(96):
		player.e2e_set_axis(1.0)
		await physics_frame
		if int(game.get("player_health")) < health_before:
			contact_damage_captured = true
			contact_position = player.global_position
			break
	player.e2e_set_axis(0.0)
	var max_contact_displacement := 0.0
	var max_contact_velocity_x := 0.0
	var contact_recovery_frames := -1
	if contact_damage_captured:
		for frame in range(24):
			await physics_frame
			max_contact_displacement = maxf(max_contact_displacement, absf(player.global_position.x - contact_position.x))
			max_contact_velocity_x = maxf(max_contact_velocity_x, absf(player.velocity.x))
			if contact_recovery_frames < 0 and absf(player.velocity.x) <= 72.0:
				contact_recovery_frames = frame + 1
	else:
		await _wait_physics_frames(4)
	screenshots.append(await _capture_viewport("window-boss-contact-damage"))
	return {
		"phase": "boss_reveal",
		"setup": "positioned_near_boss_for_window_evidence",
		"boss_found": true,
		"boss_position": _vector_to_dict(boss.global_position),
		"player_position": _vector_to_dict(player.global_position),
		"boss_hp_visible": bool(ui.get("boss_hp_visible", false)),
		"boss_text": String(ui.get("boss_text", "")),
		"contact_damage_captured": contact_damage_captured,
		"player_damage_taken": health_before - int(game.get("player_health")),
		"contact_knockback_max_displacement_x": snapped(max_contact_displacement, 0.01),
		"contact_knockback_max_velocity_x": snapped(max_contact_velocity_x, 0.01),
		"contact_knockback_control_recovery_frames": contact_recovery_frames,
		"reason": "boss_hp_revealed_in_real_window" if bool(ui.get("boss_hp_visible", false)) else "boss_hp_not_visible",
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

func _nearest_uncollected_sigil(player: Node2D) -> Area2D:
	var nearest: Area2D = null
	var nearest_distance := INF
	for node in get_nodes_in_group("sigils"):
		var sigil := node as Area2D
		if sigil == null or bool(sigil.get_meta("collected", false)):
			continue
		var distance := sigil.global_position.distance_squared_to(player.global_position)
		if distance < nearest_distance:
			nearest = sigil
			nearest_distance = distance
	return nearest

func _is_world_point_visible(game: Node, world_position: Vector2) -> bool:
	var camera := game.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return false
	var window := root.get_window()
	var half_width := float(window.content_scale_size.x) / (2.0 * camera.zoom.x)
	var half_height := float(window.content_scale_size.y) / (2.0 * camera.zoom.y)
	return absf(world_position.x - camera.global_position.x) <= half_width and absf(world_position.y - camera.global_position.y) <= half_height

func _capture_viewport(label: String, frame_delay := 3) -> Dictionary:
	await _wait_frames(frame_delay)
	var image := root.get_texture().get_image()
	var absolute_path := "%s/%s.png" % [evidence_dir, label]
	var error := image.save_png(absolute_path)
	return {
		"label": label,
		"path": absolute_path,
		"width": image.get_width(),
		"height": image.get_height(),
		"status": "pass" if error == OK else "fail",
		"source": "non_headless_root_viewport",
	}

func _valid_screenshots(screenshots: Array) -> Array:
	var valid: Array = []
	for entry in screenshots:
		var shot: Dictionary = entry
		if String(shot.get("status", "")) == "pass":
			valid.append(shot)
	return valid

func _window_info() -> Dictionary:
	var window := root.get_window()
	return {
		"mode": int(DisplayServer.window_get_mode()),
		"size": _vectori_to_dict(DisplayServer.window_get_size()),
		"decorated_size": _vectori_to_dict(DisplayServer.window_get_size_with_decorations()),
		"content_scale_size": _vectori_to_dict(window.content_scale_size),
		"root_size": _vectori_to_dict(root.size),
	}

func _ui_evidence(game: Node) -> Dictionary:
	var tutorial := game.get_node_or_null("CanvasLayer/TutorialLabel") as Label
	var sigils := game.get_node_or_null("CanvasLayer/HUDPanel/SigilCountLabel") as Label
	var state := game.get_node_or_null("CanvasLayer/HUDPanel/StateLabel") as Label
	var boss_panel := game.get_node_or_null("CanvasLayer/BossHealthPanel") as Control
	var boss := game.get_node_or_null("CanvasLayer/BossHealthPanel/BossHealthLabel") as Label
	return {
		"objective_text": tutorial.text if tutorial != null else "",
		"sigil_text": sigils.text if sigils != null else "",
		"state_text": state.text if state != null else "",
		"boss_text": boss.text if boss != null else "",
		"boss_hp_visible": boss_panel.visible if boss_panel != null else false,
	}

func _prepare_evidence_dir() -> void:
	run_id = _make_run_id()
	var base_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	evidence_dir = "%s/%s" % [base_dir, run_id]
	DirAccess.make_dir_recursive_absolute(evidence_dir)

func _make_run_id() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d-%02d%02d%02d-window-manual" % [
		int(now["year"]),
		int(now["month"]),
		int(now["day"]),
		int(now["hour"]),
		int(now["minute"]),
		int(now["second"]),
	]

func _write_json_file(file_name: String, value) -> String:
	var absolute_path := "%s/%s" % [evidence_dir, file_name]
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return absolute_path
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	return absolute_path

func _stdout_summary(summary: Dictionary) -> Dictionary:
	return {
		"mode": summary.get("mode", MODE),
		"status": summary.get("status", "fail"),
		"run_id": summary.get("run_id", run_id),
		"evidence_dir": summary.get("evidence_dir", evidence_dir),
		"display_name": summary.get("display_name", ""),
		"summary_path": summary.get("summary_path", ""),
	}

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

func _vectori_to_dict(value: Vector2i) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}

func _finish(status: String, failures: Array, screenshots: Array, route_log: Array, message: String) -> void:
	if run_id.is_empty():
		_prepare_evidence_dir()
	failures.append(message)
	var summary := {
		"mode": MODE,
		"status": status,
		"run_id": run_id,
		"evidence_dir": evidence_dir,
		"display_name": DisplayServer.get_name(),
		"input_model": "held_e2e_player_inputs",
		"direct_damage_used": false,
		"window": _window_info(),
		"ui_evidence": {},
		"hit_evidence": {},
		"sigil_evidence": {},
		"boss_evidence": {},
		"windup_evidence": {},
		"route_log": route_log,
		"screenshots": screenshots,
		"failures": failures,
	}
	summary["summary_path"] = _write_json_file("summary.json", summary)
	_write_json_file("summary.json", summary)
	print("WINDOW_MANUAL_PLAY_JSON " + JSON.stringify(_stdout_summary(summary)))
	quit(1)
