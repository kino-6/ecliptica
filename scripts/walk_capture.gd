extends SceneTree

const MODE := "walk_capture"
const SAMPLE_FRAMES := 72

func _init() -> void:
	call_deferred("run_capture")

func run_capture() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("WALK_CAPTURE_JSON %s" % [JSON.stringify({"mode": MODE, "error": "main scene should load"})])
		quit(1)
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player: CharacterBody2D = scene.get_node("Player")
	var player_sprite: AnimatedSprite2D = scene.get_node("Player/PlayerSprite")
	var camera: Camera2D = scene.get_node("Camera2D")
	player.e2e_set_axis(1.0)
	for warmup in range(24):
		await physics_frame
		await process_frame

	var samples: Array[Dictionary] = []
	for index in range(SAMPLE_FRAMES):
		await physics_frame
		await process_frame
		var transform := player_sprite.get_global_transform_with_canvas()
		samples.append({
			"index": index,
			"animation": String(player_sprite.animation),
			"frame": int(player_sprite.frame),
			"player_x": snappedf(player.global_position.x, 0.001),
			"player_y": snappedf(player.global_position.y, 0.001),
			"sprite_screen_x": snappedf(transform.origin.x, 0.001),
			"sprite_screen_y": snappedf(transform.origin.y, 0.001),
			"sprite_screen_scale_x": snappedf(transform.x.length(), 0.001),
			"sprite_screen_scale_y": snappedf(transform.y.length(), 0.001),
			"camera_x": snappedf(camera.global_position.x, 0.001),
			"camera_y": snappedf(camera.global_position.y, 0.001),
		})

	player.e2e_set_axis(0.0)
	print("WALK_CAPTURE_JSON %s" % [JSON.stringify({
		"mode": MODE,
		"samples": samples,
	})])
	quit(0)
