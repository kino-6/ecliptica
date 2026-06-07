extends SceneTree

const MODE := "enemy_gravity_capture"

func _init() -> void:
	call_deferred("run_capture")

func run_capture() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("ENEMY_GRAVITY_JSON %s" % [JSON.stringify({"mode": MODE, "error": "main scene should load"})])
		quit(1)
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player: CharacterBody2D = scene.get_node("Player")
	var enemies := get_nodes_in_group("enemies")
	if enemies.is_empty():
		print("ENEMY_GRAVITY_JSON %s" % [JSON.stringify({"mode": MODE, "error": "enemy should exist"})])
		quit(1)
		return

	var enemy := enemies[0] as Area2D
	enemy.visible = true
	enemy.monitoring = true
	enemy.monitorable = true
	enemy.set_meta("destroyed", false)
	enemy.global_position = player.global_position + Vector2(180.0, -80.0)
	if enemy.has_method("configure_patrol"):
		enemy.configure_patrol(180.0, 0.0, 300.0, 110.0)

	var start := enemy.global_position
	var samples: Array[Dictionary] = []
	for index in range(36):
		await physics_frame
		await process_frame
		samples.append({
			"index": index,
			"x": snappedf(enemy.global_position.x, 0.001),
			"y": snappedf(enemy.global_position.y, 0.001),
			"state": String(enemy.get_meta("ai_state", "")),
		})

	var end := enemy.global_position
	print("ENEMY_GRAVITY_JSON %s" % [JSON.stringify({
		"mode": MODE,
		"start": {"x": snappedf(start.x, 0.001), "y": snappedf(start.y, 0.001)},
		"end": {"x": snappedf(end.x, 0.001), "y": snappedf(end.y, 0.001)},
		"delta": {"x": snappedf(end.x - start.x, 0.001), "y": snappedf(end.y - start.y, 0.001)},
		"samples": samples,
	})])
	quit(0)
