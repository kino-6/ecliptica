extends Node

const DEFAULT_STAGE_SEED := 1337
const FLOOR_COLOR := Color(0.10, 0.10, 0.13, 0.92)
const BRANCH_COLOR := Color(0.08, 0.09, 0.12, 0.94)
const SIGIL_COLOR := Color(0.72, 0.08, 0.13, 0.92)
const ROOM_LIBRARY := [
	{
		"name": "entrance",
		"platform": Vector2(520, 60),
		"center": Vector2(260, 510),
		"sigil": Vector2(330, 424),
	},
	{
		"name": "lower_walk",
		"platform": Vector2(300, 82),
		"center": Vector2(760, 499),
		"sigil": Vector2(700, 402),
	},
	{
		"name": "raised_floor",
		"platform": Vector2(250, 110),
		"center": Vector2(1105, 485),
		"sigil": Vector2(1090, 374),
	},
	{
		"name": "upper_branch",
		"platform": Vector2(190, 34),
		"center": Vector2(1375, 391),
		"sigil": Vector2(1355, 318),
		"branch": true,
	},
	{
		"name": "recovery_floor",
		"platform": Vector2(320, 108),
		"center": Vector2(1700, 486),
		"sigil": Vector2(1655, 376),
	},
	{
		"name": "second_branch",
		"platform": Vector2(180, 34),
		"center": Vector2(2020, 407),
		"sigil": Vector2(2000, 334),
		"branch": true,
	},
	{
		"name": "gate_floor",
		"platform": Vector2(420, 88),
		"center": Vector2(2390, 496),
	},
]

@export var stage_seed := DEFAULT_STAGE_SEED

func generate_stage(game: Node2D) -> Dictionary:
	var platforms: Node2D = game.get_node("Platforms")
	var collectibles: Node2D = game.get_node("Collectibles")
	var player: CharacterBody2D = game.get_node("Player")
	var goal: Area2D = game.get_node("Goal")
	var rng := RandomNumberGenerator.new()
	rng.seed = stage_seed

	_clear_children(platforms)
	_clear_children(collectibles)

	var platform_count := 0
	var sigil_count := 0
	for index in range(ROOM_LIBRARY.size()):
		var room: Dictionary = ROOM_LIBRARY[index]
		var jitter: Vector2 = _room_jitter(rng, index)
		var center: Vector2 = room["center"] + jitter
		var size: Vector2 = room["platform"]
		var is_branch: bool = room.get("branch", false)
		var room_name: String = room["name"]
		_create_platform(platforms, room_name, center, size, is_branch)
		platform_count += 1

		if room.has("sigil"):
			var sigil_position: Vector2 = room["sigil"] + jitter
			_create_sigil(collectibles, sigil_count + 1, sigil_position)
			sigil_count += 1

	var entrance: Dictionary = ROOM_LIBRARY[0]
	var entrance_center: Vector2 = entrance["center"]
	var entrance_size: Vector2 = entrance["platform"]
	var entrance_top: float = entrance_center.y - entrance_size.y * 0.5
	player.global_position = Vector2(87, entrance_top - 8.0)

	var gate_floor: Dictionary = ROOM_LIBRARY[ROOM_LIBRARY.size() - 1]
	var gate_center: Vector2 = gate_floor["center"]
	var gate_size: Vector2 = gate_floor["platform"]
	var gate_top: float = gate_center.y - gate_size.y * 0.5
	goal.global_position = Vector2(2460, gate_top - 16.0)

	return {
		"seed": stage_seed,
		"platform_count": platform_count,
		"sigil_count": sigil_count,
		"goal_position": goal.global_position,
		"theme": "cathedral_forest",
	}

func _room_jitter(rng: RandomNumberGenerator, index: int) -> Vector2:
	if index == 0 or index == ROOM_LIBRARY.size() - 1:
		return Vector2.ZERO
	return Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-4.0, 4.0))

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.free()

func _create_platform(parent: Node2D, room_name: String, center: Vector2, size: Vector2, is_branch: bool) -> void:
	var platform := StaticBody2D.new()
	platform.name = "%s_platform" % room_name
	platform.position = center
	parent.add_child(platform)

	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.offset_left = -size.x * 0.5
	visual.offset_top = -size.y * 0.5
	visual.offset_right = size.x * 0.5
	visual.offset_bottom = size.y * 0.5
	visual.color = BRANCH_COLOR if is_branch else FLOOR_COLOR
	platform.add_child(visual)

	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	platform.add_child(collision)

func _create_sigil(parent: Node2D, index: int, position: Vector2) -> void:
	var sigil := Area2D.new()
	sigil.name = "GeneratedSigil%d" % index
	sigil.position = position
	sigil.add_to_group("sigils")
	parent.add_child(sigil)

	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.offset_left = -8.0
	visual.offset_top = -12.0
	visual.offset_right = 8.0
	visual.offset_bottom = 12.0
	visual.color = SIGIL_COLOR
	sigil.add_child(visual)

	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	sigil.add_child(collision)
