extends SceneTree

const MODE := "window_manual_play_probe"
const OUTPUT_DIR := "res://artifacts/window-manual-play"
const SCENE_PATH := "res://scenes/main.tscn"

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
	route_log.append(await _run_movement_probe(player))
	screenshots.append(await _capture_viewport("window-after_movement"))
	var enemy := _first_standard_enemy()
	route_log.append(_describe_first_enemy(player, enemy))
	route_log.append(await _run_attack_probe(game, player, enemy))
	screenshots.append(await _capture_viewport("window-after_attack"))

	var saved_screenshots := _valid_screenshots(screenshots)
	if saved_screenshots.size() < 3:
		failures.append("window manual play should save three viewport screenshots")
	var attack_entry: Dictionary = route_log[-1] if not route_log.is_empty() else {}
	if not bool(attack_entry.get("hit", false)):
		failures.append("window manual play should hit the first enemy with real attack input")

	var summary := {
		"mode": MODE,
		"status": "pass" if failures.is_empty() else "fail",
		"run_id": run_id,
		"evidence_dir": evidence_dir,
		"display_name": DisplayServer.get_name(),
		"input_model": "held_e2e_player_inputs",
		"direct_damage_used": false,
		"window": _window_info(),
		"route_log": route_log,
		"screenshots": saved_screenshots,
		"failures": failures,
	}
	summary["summary_path"] = _write_json_file("summary.json", summary)
	_write_json_file("summary.json", summary)
	print("WINDOW_MANUAL_PLAY_JSON " + JSON.stringify(_stdout_summary(summary)))
	quit(0 if failures.is_empty() else 1)

func _run_movement_probe(player: CharacterBody2D) -> Dictionary:
	var start_position := player.global_position
	var held_frames := 54
	player.e2e_set_axis(1.0)
	await _wait_physics_frames(held_frames)
	player.e2e_set_axis(0.0)
	await _wait_physics_frames(8)
	return {
		"phase": "movement",
		"held_frames": held_frames,
		"start": _vector_to_dict(start_position),
		"end": _vector_to_dict(player.global_position),
		"moved_by": snapped(player.global_position.x - start_position.x, 0.01),
	}

func _run_attack_probe(game: Node, player: CharacterBody2D, enemy: Area2D) -> Dictionary:
	var health_before := int(game.get("player_health"))
	var enemy_hp_before := 0
	if enemy != null:
		enemy_hp_before = int(enemy.get_meta("hit_points", 0))
	player.e2e_attack()
	await _wait_physics_frames(44)
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

func _capture_viewport(label: String) -> Dictionary:
	await _wait_frames(3)
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
		"route_log": route_log,
		"screenshots": screenshots,
		"failures": failures,
	}
	summary["summary_path"] = _write_json_file("summary.json", summary)
	_write_json_file("summary.json", summary)
	print("WINDOW_MANUAL_PLAY_JSON " + JSON.stringify(_stdout_summary(summary)))
	quit(1)
