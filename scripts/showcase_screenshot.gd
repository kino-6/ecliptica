extends SceneTree

const OUTPUT_PATH := "res://artifacts/showcase/showcase-room.png"
const WIDTH := 1920
const HEIGHT := 1080
const ASSET_MANIFEST_SCRIPT := preload("res://scripts/asset_manifest.gd")

var asset_manifest

func _init() -> void:
	call_deferred("capture_showcase")

func capture_showcase() -> void:
	asset_manifest = ASSET_MANIFEST_SCRIPT.new()
	asset_manifest.load_from_file()
	var canvas := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.018, 0.02, 0.024, 1.0))

	_draw_backdrop(canvas)
	_draw_floor(canvas)
	_draw_actor(canvas, "player_idle", Rect2i(0, 0, 192, 384), Vector2i(720, 458), Vector2i(150, 300))
	_draw_actor(canvas, "enemy_idle", Rect2i(0, 0, 192, 384), Vector2i(1090, 505), Vector2i(170, 340))

	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := canvas.save_png(absolute_path)
	if error != OK:
		_finish("fail", "showcase screenshot should save", absolute_path)
		return
	print("SHOWCASE_SCREENSHOT_JSON " + JSON.stringify({
		"status": "pass",
		"path": absolute_path,
		"width": canvas.get_width(),
		"height": canvas.get_height(),
	}))
	quit(0)

func _draw_backdrop(canvas: Image) -> void:
	var backdrop := _load_asset_png("showcase_backdrop")
	if backdrop == null:
		return
	backdrop.resize(WIDTH, HEIGHT, Image.INTERPOLATE_LANCZOS)
	canvas.blend_rect(backdrop, Rect2i(Vector2i.ZERO, backdrop.get_size()), Vector2i.ZERO)

func _draw_floor(canvas: Image) -> void:
	var tile := _load_asset_png("platform_stone_tile")
	if tile == null:
		return
	var floor_y := 760
	for y in range(floor_y, HEIGHT, tile.get_height()):
		for x in range(0, WIDTH, tile.get_width()):
			canvas.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(x, y))

func _draw_actor(canvas: Image, asset_id: String, region: Rect2i, position: Vector2i, size: Vector2i) -> void:
	var sheet := _load_asset_png(asset_id)
	if sheet == null:
		return
	var frame := sheet.get_region(region)
	frame.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	canvas.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), position)

func _load_asset_png(asset_id: String) -> Image:
	return _load_png(asset_manifest.texture_path(asset_id))

func _load_png(path: String) -> Image:
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if error != OK:
		push_error("Failed to load showcase screenshot image: %s" % [path])
		return null
	return image

func _finish(status: String, message: String, path: String) -> void:
	print("SHOWCASE_SCREENSHOT_JSON " + JSON.stringify({
		"status": status,
		"message": message,
		"path": path,
	}))
	quit(1)
