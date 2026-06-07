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
	var decorated_physical_size := DisplayServer.window_get_size_with_decorations()
	var logical_size := Vector2(physical_size) / scale
	var decorated_logical_size := Vector2(decorated_physical_size) / scale
	var camera: Camera2D = scene.get_node("Camera2D")
	var window := root.get_window()

	print("WINDOW_E2E_PROBE scale=%.2f physical=%s decorated=%s logical=%s decorated_logical=%s root=%s content_scale=%s" % [scale, physical_size, decorated_physical_size, logical_size, decorated_logical_size, root.size, window.content_scale_size])

	if not _expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "runtime window should start fullscreen"):
		return
	if not _expect(window.content_scale_size == TARGET_LOGICAL_WINDOW_SIZE, "fullscreen content scale should stay 1920x1080"):
		return
	if not _expect(camera.zoom == Vector2(2.2, 2.2), "camera should use close gothic action framing"):
		return
	if not _expect(TARGET_LOGICAL_WINDOW_SIZE.x / camera.zoom.x <= 900.0, "camera should keep the visible world width tight enough to read character detail"):
		return

	print("WINDOW_E2E_OK scale=%.2f physical=%s decorated=%s logical=%s decorated_logical=%s content_scale=%s" % [scale, physical_size, decorated_physical_size, logical_size, decorated_logical_size, window.content_scale_size])
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
