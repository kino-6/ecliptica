extends SceneTree

const TARGET_LOGICAL_WINDOW_SIZE := Vector2i(1920, 1080)

func _init() -> void:
	call_deferred("run_window_e2e")

func run_window_e2e() -> void:
	if not _expect(DisplayServer.get_name() != "headless", "window E2E must run without --headless"):
		return

	var packed: PackedScene = load("res://scenes/main.tscn")
	if not _expect(packed != null, "main scene should load"):
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame
	await process_frame

	var screen := DisplayServer.window_get_current_screen()
	var scale := maxf(DisplayServer.screen_get_scale(screen), 1.0)
	var physical_size := DisplayServer.window_get_size()
	var logical_size := Vector2(physical_size) / scale
	var camera: Camera2D = scene.get_node("Camera2D")

	if not _expect(logical_size.x >= TARGET_LOGICAL_WINDOW_SIZE.x - 1, "runtime window logical width should be 1920"):
		return
	if not _expect(logical_size.y >= TARGET_LOGICAL_WINDOW_SIZE.y - 1, "runtime window logical height should be 1080"):
		return
	if not _expect(root.size == TARGET_LOGICAL_WINDOW_SIZE, "root viewport should stay 1920x1080"):
		return
	if not _expect(camera.zoom == Vector2.ONE, "camera should stay at 1x zoom"):
		return

	print("WINDOW_E2E_OK scale=%.2f physical=%s logical=%s root=%s" % [scale, physical_size, logical_size, root.size])
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
