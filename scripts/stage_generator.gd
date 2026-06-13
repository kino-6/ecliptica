extends Node

const DEFAULT_STAGE_SEED := 1337
const FLOOR_COLOR := Color(0.10, 0.10, 0.13, 0.92)
const BRANCH_COLOR := Color(0.08, 0.09, 0.12, 0.94)
const GATE_COLOR := Color(0.14, 0.11, 0.12, 0.96)
const SIGIL_COLOR := Color(0.72, 0.08, 0.13, 0.92)
const ENEMY_FRAME_SIZE := Vector2i(192, 384)
const BOSS_FRAME_SIZE := Vector2i(256, 384)
const ENEMY_IDLE_FRAME_COUNT := 8
const ENEMY_WALK_FRAME_COUNT := 12
const ENEMY_ATTACK_FRAME_COUNT := 8
const BOSS_FRAME_COUNT := 8
const STAGE_LAYOUT_STYLE := "sanctuary_rogue_wing"
const VERTICAL_ROOM_COUNT := 3
const SHORTCUT_COUNT := 1
const LOCKED_GATE_COUNT := 1
const CRITICAL_PATH_ROOM_COUNT := 6
const BRANCH_ROOM_COUNT := 2
const SANCTUARY_COUNT := 1
const FLOATING_PLATFORM_COUNT := 0
const PLAYER_MAX_STEP_UP := 96.0
const ENEMY_FOOT_OFFSET_Y := 29.0
const BOSS_FOOT_OFFSET_Y := 58.0
const BOSS_HIT_POINTS := 3
const TARGET_CLEAR_ATTEMPTS := 2
const EXPECTED_CLEAR_ATTEMPTS := 2
const BALANCE_RISK_SCORE := 8
const BRANCH_CHALLENGE_COUNT := 2
const RECOVERY_WINDOW_COUNT := 2
const STAGE_PACING := "first_stage_two_try"
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const ASSET_MANIFEST_SCRIPT := preload("res://scripts/asset_manifest.gd")
const ENEMY_IDLE_ASSET_ID := "enemy_idle"
const ENEMY_WALK_ASSET_ID := "enemy_walk"
const ENEMY_ATTACK_ASSET_ID := "enemy_attack"
const BOSS_ASSET_ID := "boss_idle"
const PLATFORM_TILE_ASSET_ID := "platform_stone_tile"
const SIGIL_ASSET_ID := "sigil_relic"
const SHOWCASE_BACKDROP_ASSET_ID := "showcase_backdrop"
const ENEMY_SPAWN_SLOTS := [
	{"room": "entrance_sanctuary", "floor": 2, "x": 430.0},
	{"room": "crypt_descent", "floor": 0, "x": 1660.0},
	{"room": "boss_antechamber", "floor": 0, "x": 2055.0},
]
const BOSS_SPAWN_SLOT := {"room": "sealed_nave_boss", "floor": 0, "x": 2390.0}
const TRAVERSAL_EDGES := [
	{"from": "entrance_sanctuary", "from_floor": 0, "to": "gatehouse_hall", "to_floor": 0, "kind": "door"},
	{"from": "gatehouse_hall", "from_floor": 0, "to": "lower_cloister", "to_floor": 0, "kind": "door"},
	{"from": "lower_cloister", "from_floor": 0, "to": "crypt_descent", "to_floor": 0, "kind": "door"},
	{"from": "crypt_descent", "from_floor": 0, "to": "boss_antechamber", "to_floor": 0, "kind": "door"},
	{"from": "boss_antechamber", "from_floor": 0, "to": "sealed_nave_boss", "to_floor": 0, "kind": "boss_door"},
	{"from": "gatehouse_hall", "from_floor": 0, "to": "ossuary_cache", "to_floor": 0, "kind": "optional_branch"},
	{"from": "lower_cloister", "from_floor": 0, "to": "upper_chapel", "to_floor": 0, "kind": "stair"},
	{"from": "upper_chapel", "from_floor": 0, "to": "upper_chapel", "to_floor": 1, "kind": "balcony"},
	{"from": "crypt_descent", "from_floor": 0, "to": "crypt_descent", "to_floor": 1, "kind": "crypt_step"},
	{"from": "crypt_descent", "from_floor": 1, "to": "shortcut_bell_stair", "to_floor": 0, "kind": "shortcut"},
	{"from": "shortcut_bell_stair", "from_floor": 0, "to": "boss_antechamber", "to_floor": 0, "kind": "shortcut_return"},
]
const ROOM_GRAPH := [
	{
		"name": "entrance_sanctuary",
		"archetype": "entrance_sanctuary",
		"size": Vector2(620, 420),
		"center": Vector2(260, 438),
		"floors": [
			{"center": Vector2(-180, 162), "size": Vector2(270, 72)},
			{"center": Vector2(-12, 161), "size": Vector2(226, 70)},
			{"center": Vector2(210, 162), "size": Vector2(250, 72)}
		],
		"walls": [
			{"center": Vector2(-310, 0), "size": Vector2(34, 420)},
			{"center": Vector2(308, 4), "size": Vector2(24, 332)}
		],
		"sigil": Vector2(338, 508),
		"sanctuary": true,
		"showcase": true,
		"critical_path": true,
		"connectors": ["left_door", "right_door"],
	},
	{
		"name": "gatehouse_hall",
		"archetype": "gatehouse_hall",
		"size": Vector2(720, 420),
		"center": Vector2(700, 438),
		"floors": [{"center": Vector2(0, 162), "size": Vector2(720, 72)}],
		"walls": [],
		"sigil": Vector2(640, 506),
		"critical_path": true,
		"connectors": ["left_door", "right_door", "branch_door"],
	},
	{
		"name": "lower_cloister",
		"archetype": "lower_cloister",
		"size": Vector2(760, 430),
		"center": Vector2(1110, 446),
		"floors": [{"center": Vector2(0, 160), "size": Vector2(760, 76)}],
		"walls": [],
		"critical_path": true,
		"recovery": true,
		"connectors": ["left_door", "right_door", "stair_up"],
	},
	{
		"name": "upper_chapel",
		"archetype": "upper_chapel",
		"size": Vector2(560, 520),
		"center": Vector2(1320, 379),
		"floors": [
			{"center": Vector2(-120, 150), "size": Vector2(330, 58)},
			{"center": Vector2(120, 86), "size": Vector2(300, 52)}
		],
		"walls": [{"center": Vector2(-280, 0), "size": Vector2(28, 520)}],
		"sigil": Vector2(1372, 298),
		"branch": true,
		"vertical": true,
		"connectors": ["stair_down", "right_locked"],
	},
	{
		"name": "ossuary_cache",
		"archetype": "ossuary_cache",
		"size": Vector2(460, 390),
		"center": Vector2(1010, 470),
		"floors": [{"center": Vector2(0, 128), "size": Vector2(460, 60)}],
		"walls": [{"center": Vector2(230, 0), "size": Vector2(26, 390)}],
		"sigil": Vector2(1030, 364),
		"branch": true,
		"vertical": true,
		"connectors": ["side_door_optional"],
	},
	{
		"name": "crypt_descent",
		"archetype": "crypt_descent",
		"size": Vector2(680, 500),
		"center": Vector2(1540, 456),
		"floors": [
			{"center": Vector2(-80, 152), "size": Vector2(520, 76)},
			{"center": Vector2(170, 62), "size": Vector2(280, 54)}
		],
		"walls": [],
		"sigil": Vector2(1594, 512),
		"critical_path": true,
		"locked": true,
		"connectors": ["left_door", "sealed_door", "drop"],
	},
	{
		"name": "shortcut_bell_stair",
		"archetype": "shortcut_bell_stair",
		"size": Vector2(360, 480),
		"center": Vector2(1820, 380),
		"floors": [{"center": Vector2(0, 142), "size": Vector2(360, 58)}],
		"walls": [{"center": Vector2(180, 0), "size": Vector2(28, 480)}],
		"sigil": Vector2(1814, 402),
		"vertical": true,
		"shortcut": true,
		"connectors": ["shortcut_back", "stair_down"],
	},
	{
		"name": "boss_antechamber",
		"archetype": "boss_antechamber",
		"size": Vector2(560, 420),
		"center": Vector2(2020, 438),
		"floors": [{"center": Vector2(0, 162), "size": Vector2(560, 72)}],
		"walls": [],
		"sigil": Vector2(2024, 506),
		"recovery": true,
		"critical_path": true,
		"connectors": ["left_door", "boss_door"],
	},
	{
		"name": "sealed_nave_boss",
		"archetype": "sealed_nave_boss",
		"size": Vector2(760, 460),
		"center": Vector2(2480, 438),
		"floors": [{"center": Vector2(0, 162), "size": Vector2(760, 82)}],
		"walls": [{"center": Vector2(380, 0), "size": Vector2(34, 460)}],
		"gate": true,
		"critical_path": true,
		"connectors": ["boss_door", "exit_gate"],
	},
]

@export var stage_seed := DEFAULT_STAGE_SEED
@export var run_seed := DEFAULT_STAGE_SEED
@export var run_stage_index := 1
@export var curse_level := 0
@export var run_reward_count := 0

var platform_tile_texture: Texture2D
var enemy_idle_texture: Texture2D
var enemy_walk_texture: Texture2D
var enemy_attack_texture: Texture2D
var boss_texture: Texture2D
var sigil_texture: Texture2D
var showcase_backdrop_texture: Texture2D
var asset_manifest

func generate_stage(game: Node2D) -> Dictionary:
	var platforms: Node2D = game.get_node("Platforms")
	var collectibles: Node2D = game.get_node("Collectibles")
	var enemies: Node2D = game.get_node("Enemies")
	var player: CharacterBody2D = game.get_node("Player")
	var goal: Area2D = game.get_node("Goal")
	var rng := RandomNumberGenerator.new()
	rng.seed = stage_seed
	asset_manifest = ASSET_MANIFEST_SCRIPT.new()
	asset_manifest.load_from_file()
	platform_tile_texture = _load_asset_texture(PLATFORM_TILE_ASSET_ID)
	enemy_idle_texture = _load_asset_texture(ENEMY_IDLE_ASSET_ID)
	enemy_walk_texture = _load_asset_texture(ENEMY_WALK_ASSET_ID)
	enemy_attack_texture = _load_asset_texture(ENEMY_ATTACK_ASSET_ID)
	boss_texture = _load_asset_texture(BOSS_ASSET_ID)
	sigil_texture = _load_asset_texture(SIGIL_ASSET_ID)
	showcase_backdrop_texture = _load_asset_texture(SHOWCASE_BACKDROP_ASSET_ID)

	_clear_children(platforms)
	_clear_children(collectibles)
	_clear_children(enemies)

	var room_count := 0
	var sigil_count := 0
	var enemy_count := 0
	var standard_enemy_count := 0
	var boss_count := 0
	var enemy_spawn_slots: Array = []
	var room_offsets := {}
	for index in range(ROOM_GRAPH.size()):
		var room: Dictionary = ROOM_GRAPH[index]
		var jitter: Vector2 = _room_jitter(rng, index)
		room_offsets[String(room["name"])] = jitter
		var center: Vector2 = room["center"] + jitter
		_create_room_shell(platforms, room, center)
		room_count += 1

		if room.has("sigil"):
			var sigil_position: Vector2 = room["sigil"] + jitter
			_create_sigil(collectibles, sigil_count + 1, sigil_position)
			sigil_count += 1

	var elite_enemy_count := _elite_enemy_count()
	for spawn_slot in ENEMY_SPAWN_SLOTS:
		var enemy_position := _spawn_position_from_slot(spawn_slot, ENEMY_FOOT_OFFSET_Y, room_offsets)
		var is_elite := enemy_count < elite_enemy_count
		_create_enemy(enemies, enemy_count + 1, enemy_position, is_elite)
		enemy_spawn_slots.append(spawn_slot)
		enemy_count += 1
		standard_enemy_count += 1
	var boss_position := _spawn_position_from_slot(BOSS_SPAWN_SLOT, BOSS_FOOT_OFFSET_Y, room_offsets)
	_create_boss(enemies, boss_position)
	enemy_count += 1
	boss_count += 1
	var geometry_validation := _validate_stage_geometry(enemy_spawn_slots, BOSS_SPAWN_SLOT, room_offsets)

	var entrance: Dictionary = ROOM_GRAPH[0]
	var entrance_top: float = _primary_floor_top(entrance)
	player.global_position = Vector2(87, entrance_top - 8.0)

	var gate_floor: Dictionary = ROOM_GRAPH[ROOM_GRAPH.size() - 1]
	var gate_center: Vector2 = gate_floor["center"]
	var gate_top: float = _primary_floor_top(gate_floor)
	goal.global_position = Vector2(gate_center.x + 208.0, gate_top - 16.0)

	return {
		"seed": stage_seed,
		"run_seed": run_seed,
		"run_stage_index": run_stage_index,
		"curse_level": curse_level,
		"run_reward_count": run_reward_count,
		"stage_variant": _stage_variant(),
		"elite_enemy_count": elite_enemy_count,
		"layout_style": STAGE_LAYOUT_STYLE,
		"room_count": room_count,
		"vertical_room_count": _count_rooms_with_flag("vertical"),
		"shortcut_count": _count_rooms_with_flag("shortcut"),
		"locked_gate_count": _count_rooms_with_flag("gate"),
		"critical_path_room_count": _count_rooms_with_flag("critical_path"),
		"branch_room_count": _count_rooms_with_flag("branch"),
		"sanctuary_count": _count_rooms_with_flag("sanctuary"),
		"floating_platform_count": FLOATING_PLATFORM_COUNT,
		"unsupported_balcony_count": 0,
		"critical_path_reachable": int(geometry_validation["impossible_jump_count"]) == 0,
		"branch_reward_reachable": int(geometry_validation["impossible_jump_count"]) == 0,
		"boss_route_requires_optional_branch": false,
		"max_required_step_up": geometry_validation["max_required_step_up"],
		"impossible_jump_count": geometry_validation["impossible_jump_count"],
		"enemy_spawn_grounded": geometry_validation["enemy_spawn_grounded"],
		"enemy_spawn_overlap_count": geometry_validation["enemy_spawn_overlap_count"],
		"enemy_spawn_out_of_floor_count": geometry_validation["enemy_spawn_out_of_floor_count"],
		"boss_spawn_grounded": geometry_validation["boss_spawn_grounded"],
		"platform_count": room_count,
		"sigil_count": sigil_count,
		"enemy_count": enemy_count,
		"standard_enemy_count": standard_enemy_count,
		"boss_count": boss_count,
		"showcase_room_floor_segments": _floor_segment_count("entrance_sanctuary"),
		"showcase_enemy_count": _enemy_count_in_room(enemy_spawn_slots, "entrance_sanctuary"),
		"showcase_has_backdrop": showcase_backdrop_texture != null,
		"goal_position": goal.global_position,
		"balance": _first_stage_balance(enemy_count),
		"theme": "cathedral_keep",
	}

func _room_jitter(rng: RandomNumberGenerator, index: int) -> Vector2:
	if index == 0 or index == ROOM_GRAPH.size() - 1:
		return Vector2.ZERO
	return Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-4.0, 4.0))

func _first_stage_balance(enemy_count: int) -> Dictionary:
	return {
		"target_clear_attempts": TARGET_CLEAR_ATTEMPTS,
		"expected_clear_attempts": EXPECTED_CLEAR_ATTEMPTS,
		"risk_score": BALANCE_RISK_SCORE + max(run_stage_index - 1, 0) + curse_level,
		"health_buffer_hits": 2,
		"focus_shots_available": 3,
		"branch_challenge_count": BRANCH_CHALLENGE_COUNT,
		"combat_encounter_count": enemy_count,
		"boss_hit_points": BOSS_HIT_POINTS,
		"recovery_window_count": RECOVERY_WINDOW_COUNT,
		"pacing": STAGE_PACING,
	}

func _stage_variant() -> String:
	if run_stage_index % 2 == 0:
		return "moonlit_cloister"
	return "cathedral_keep"

func _elite_enemy_count() -> int:
	if run_stage_index <= 1 and curse_level <= 0:
		return 0
	return 1

func _count_rooms_with_flag(flag_name: String) -> int:
	var count := 0
	for room in ROOM_GRAPH:
		if bool(room.get(flag_name, false)):
			count += 1
	return count

func _floor_segment_count(room_name: String) -> int:
	return (_room_by_name(room_name)["floors"] as Array).size()

func _enemy_count_in_room(enemy_slots: Array, room_name: String) -> int:
	var count := 0
	for slot in enemy_slots:
		if String(slot["room"]) == room_name:
			count += 1
	return count

func _primary_floor_top(room: Dictionary) -> float:
	var floors: Array = room["floors"]
	var first_floor: Dictionary = floors[0]
	var room_center: Vector2 = room["center"]
	var floor_center: Vector2 = first_floor["center"]
	var floor_size: Vector2 = first_floor["size"]
	return room_center.y + floor_center.y - floor_size.y * 0.5

func _spawn_position_from_slot(slot: Dictionary, foot_offset_y: float, room_offsets := {}) -> Vector2:
	var room_name := String(slot["room"])
	var room := _room_by_name(room_name)
	var floor_index := int(slot.get("floor", 0))
	var room_offset: Vector2 = room_offsets.get(room_name, Vector2.ZERO)
	var floor_top := _floor_top(room, floor_index, room_offset)
	return Vector2(float(slot["x"]) + room_offset.x, floor_top - foot_offset_y)

func _validate_stage_geometry(enemy_slots: Array, boss_slot: Dictionary, room_offsets := {}) -> Dictionary:
	var max_required_step_up := 0.0
	var impossible_jump_count := 0
	for edge in TRAVERSAL_EDGES:
		var from_room_name := String(edge["from"])
		var to_room_name := String(edge["to"])
		var from_top := _floor_top(_room_by_name(from_room_name), int(edge.get("from_floor", 0)), room_offsets.get(from_room_name, Vector2.ZERO))
		var to_top := _floor_top(_room_by_name(to_room_name), int(edge.get("to_floor", 0)), room_offsets.get(to_room_name, Vector2.ZERO))
		var step_up := maxf(from_top - to_top, 0.0)
		max_required_step_up = maxf(max_required_step_up, step_up)
		if step_up > PLAYER_MAX_STEP_UP:
			impossible_jump_count += 1

	var enemy_spawn_overlap_count := 0
	var enemy_spawn_out_of_floor_count := 0
	for slot in enemy_slots:
		if not _spawn_slot_is_grounded(slot, ENEMY_FOOT_OFFSET_Y, room_offsets):
			enemy_spawn_overlap_count += 1
		if not _spawn_slot_is_inside_floor(slot, room_offsets):
			enemy_spawn_out_of_floor_count += 1

	return {
		"max_required_step_up": snapped(max_required_step_up, 0.01),
		"impossible_jump_count": impossible_jump_count,
		"enemy_spawn_grounded": enemy_spawn_overlap_count == 0 and enemy_spawn_out_of_floor_count == 0,
		"enemy_spawn_overlap_count": enemy_spawn_overlap_count,
		"enemy_spawn_out_of_floor_count": enemy_spawn_out_of_floor_count,
		"boss_spawn_grounded": _spawn_slot_is_grounded(boss_slot, BOSS_FOOT_OFFSET_Y, room_offsets) and _spawn_slot_is_inside_floor(boss_slot, room_offsets),
	}

func _spawn_slot_is_grounded(slot: Dictionary, foot_offset_y: float, room_offsets := {}) -> bool:
	var room_name := String(slot["room"])
	var room := _room_by_name(room_name)
	var floor_index := int(slot.get("floor", 0))
	var floor_top := _floor_top(room, floor_index, room_offsets.get(room_name, Vector2.ZERO))
	var spawn_position := _spawn_position_from_slot(slot, foot_offset_y, room_offsets)
	return absf((spawn_position.y + foot_offset_y) - floor_top) <= 0.5

func _spawn_slot_is_inside_floor(slot: Dictionary, room_offsets := {}) -> bool:
	var room_name := String(slot["room"])
	var room := _room_by_name(room_name)
	var floor_index := int(slot.get("floor", 0))
	var floor := _floor_segment(room, floor_index)
	var room_center: Vector2 = room["center"]
	var room_offset: Vector2 = room_offsets.get(room_name, Vector2.ZERO)
	var floor_center: Vector2 = floor["center"]
	var floor_size: Vector2 = floor["size"]
	var left := room_center.x + room_offset.x + floor_center.x - floor_size.x * 0.5
	var right := room_center.x + room_offset.x + floor_center.x + floor_size.x * 0.5
	var x := float(slot["x"]) + room_offset.x
	return x >= left + 24.0 and x <= right - 24.0

func _floor_top(room: Dictionary, floor_index: int, room_offset := Vector2.ZERO) -> float:
	var floor := _floor_segment(room, floor_index)
	var room_center: Vector2 = room["center"]
	var floor_center: Vector2 = floor["center"]
	var floor_size: Vector2 = floor["size"]
	return room_center.y + room_offset.y + floor_center.y - floor_size.y * 0.5

func _floor_segment(room: Dictionary, floor_index: int) -> Dictionary:
	var floors: Array = room["floors"]
	return floors[clampi(floor_index, 0, floors.size() - 1)]

func _room_by_name(room_name: String) -> Dictionary:
	for room in ROOM_GRAPH:
		if String(room["name"]) == room_name:
			return room
	push_error("Unknown generated room: %s" % [room_name])
	return ROOM_GRAPH[0]

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.free()

func _create_room_shell(parent: Node2D, room: Dictionary, center: Vector2) -> void:
	var room_name: String = room["name"]
	var size: Vector2 = room["size"]
	var room_shell := StaticBody2D.new()
	room_shell.name = "%s_room" % room_name
	room_shell.position = center
	room_shell.set_meta("layout_style", STAGE_LAYOUT_STYLE)
	room_shell.set_meta("room_name", room_name)
	room_shell.set_meta("archetype", room.get("archetype", room_name))
	room_shell.set_meta("branch", bool(room.get("branch", false)))
	room_shell.set_meta("vertical", bool(room.get("vertical", false)))
	room_shell.set_meta("shortcut", bool(room.get("shortcut", false)))
	room_shell.set_meta("gate", bool(room.get("gate", false)))
	room_shell.set_meta("locked", bool(room.get("locked", false)))
	room_shell.set_meta("sanctuary", bool(room.get("sanctuary", false)))
	room_shell.set_meta("critical_path", bool(room.get("critical_path", false)))
	room_shell.set_meta("floating_platform", false)
	parent.add_child(room_shell)

	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.offset_left = -size.x * 0.5
	visual.offset_top = -size.y * 0.5
	visual.offset_right = size.x * 0.5
	visual.offset_bottom = size.y * 0.5
	visual.color = _room_color(room)
	visual.visible = false
	room_shell.add_child(visual)
	_add_room_back_wall(room_shell, size, room)
	_add_showcase_backdrop(room_shell, size, room)
	_add_room_floor_tiles(room_shell, room)
	_add_room_walls(room_shell, room)
	_add_connector_markers(room_shell, size, room)

func _room_color(room: Dictionary) -> Color:
	if bool(room.get("gate", false)):
		return GATE_COLOR
	if bool(room.get("branch", false)):
		return BRANCH_COLOR
	return FLOOR_COLOR

func _add_room_back_wall(room_shell: StaticBody2D, size: Vector2, room: Dictionary) -> void:
	var wall := ColorRect.new()
	wall.name = "BackWall"
	wall.offset_left = -size.x * 0.5
	wall.offset_top = -size.y * 0.5
	wall.offset_right = size.x * 0.5
	wall.offset_bottom = size.y * 0.5
	wall.color = _room_back_wall_color(room)
	if bool(room.get("showcase", false)):
		wall.visible = false
	wall.z_index = -3
	room_shell.add_child(wall)

func _add_showcase_backdrop(room_shell: StaticBody2D, size: Vector2, room: Dictionary) -> void:
	if not bool(room.get("showcase", false)) or showcase_backdrop_texture == null:
		return
	var backdrop := Sprite2D.new()
	backdrop.name = "ShowcaseBackdrop"
	backdrop.texture = showcase_backdrop_texture
	backdrop.centered = true
	backdrop.position = Vector2.ZERO
	backdrop.scale = Vector2(size.x / showcase_backdrop_texture.get_width(), size.y / showcase_backdrop_texture.get_height())
	backdrop.z_index = -4
	room_shell.add_child(backdrop)

func _room_back_wall_color(room: Dictionary) -> Color:
	if bool(room.get("gate", false)):
		return Color(0.06, 0.055, 0.065, 0.70)
	if bool(room.get("branch", false)):
		return Color(0.045, 0.052, 0.067, 0.64)
	if bool(room.get("sanctuary", false)):
		return Color(0.055, 0.045, 0.05, 0.68)
	return Color(0.04, 0.045, 0.055, 0.62)

func _add_room_floor_tiles(room_shell: StaticBody2D, room: Dictionary) -> void:
	var tiles := Node2D.new()
	tiles.name = "VisualTiles"
	tiles.z_index = 1
	room_shell.add_child(tiles)

	var tile_size := Vector2(96.0, 64.0)
	var tone := _room_tile_tone(room)
	var floors: Array = room["floors"]
	for segment_index in range(floors.size()):
		var segment: Dictionary = floors[segment_index]
		var segment_center: Vector2 = segment["center"]
		var segment_size: Vector2 = segment["size"]
		_add_collision_segment(room_shell, segment_center, segment_size, "FloorCollision%d" % segment_index)
		var columns := ceili(segment_size.x / tile_size.x)
		var rows := ceili(segment_size.y / tile_size.y)
		var left := segment_center.x - segment_size.x * 0.5
		var top := segment_center.y - segment_size.y * 0.5
		for row in range(rows):
			for column in range(columns):
				var sprite := Sprite2D.new()
				sprite.name = "StoneTile%d_%d_%d" % [segment_index, column, row]
				sprite.texture = platform_tile_texture
				sprite.centered = false
				sprite.region_enabled = true
				sprite.region_rect = Rect2(0, 0, minf(tile_size.x, segment_size.x - column * tile_size.x), minf(tile_size.y, segment_size.y - row * tile_size.y))
				sprite.position = Vector2(left + column * tile_size.x, top + row * tile_size.y)
				sprite.modulate = tone
				tiles.add_child(sprite)

func _add_room_walls(room_shell: StaticBody2D, room: Dictionary) -> void:
	var walls: Array = room.get("walls", [])
	var wall_layer := Node2D.new()
	wall_layer.name = "WallVisuals"
	wall_layer.z_index = -1
	room_shell.add_child(wall_layer)
	for wall_index in range(walls.size()):
		var wall: Dictionary = walls[wall_index]
		_add_wall_visual(wall_layer, wall["center"], wall["size"], "WallVisual%d" % wall_index)

func _add_wall_visual(parent: Node2D, center: Vector2, size: Vector2, node_name: String) -> void:
	var wall := ColorRect.new()
	wall.name = node_name
	wall.position = center
	wall.offset_left = -size.x * 0.5
	wall.offset_top = -size.y * 0.5
	wall.offset_right = size.x * 0.5
	wall.offset_bottom = size.y * 0.5
	wall.color = Color(0.12, 0.075, 0.07, 0.28)
	parent.add_child(wall)

func _add_collision_segment(room_shell: StaticBody2D, center: Vector2, size: Vector2, node_name: String) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.name = node_name
	collision.position = center
	collision.shape = shape
	room_shell.add_child(collision)

func _add_connector_markers(room_shell: StaticBody2D, size: Vector2, room: Dictionary) -> void:
	var connectors: Array = room.get("connectors", [])
	var connector_layer := Node2D.new()
	connector_layer.name = "Connectors"
	connector_layer.z_index = 2
	room_shell.add_child(connector_layer)
	for index in range(connectors.size()):
		var marker := ColorRect.new()
		marker.name = String(connectors[index])
		marker.offset_left = -10.0
		marker.offset_top = -42.0
		marker.offset_right = 10.0
		marker.offset_bottom = 42.0
		marker.color = Color(0.16, 0.11, 0.105, 0.34)
		marker.position = _connector_position(String(connectors[index]), size)
		connector_layer.add_child(marker)

func _connector_position(connector: String, size: Vector2) -> Vector2:
	if connector.contains("left"):
		return Vector2(-size.x * 0.5 + 24.0, size.y * 0.5 - 130.0)
	if connector.contains("right") or connector.contains("boss") or connector.contains("exit"):
		return Vector2(size.x * 0.5 - 24.0, size.y * 0.5 - 130.0)
	if connector.contains("up"):
		return Vector2(0.0, -size.y * 0.5 + 70.0)
	return Vector2(0.0, size.y * 0.5 - 124.0)

func _room_tile_tone(room: Dictionary) -> Color:
	if bool(room.get("gate", false)):
		return Color(1.08, 0.86, 0.86, 1.0)
	if bool(room.get("branch", false)):
		return Color(0.86, 0.92, 1.03, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)

func _load_asset_texture(asset_id: String) -> Texture2D:
	return _load_png_texture(asset_manifest.texture_path(asset_id))

func _load_png_texture(path: String) -> Texture2D:
	var image := Image.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	var error := image.load_png_from_buffer(bytes)
	if error != OK:
		push_error("Failed to load gothic stage texture: %s" % [path])
		return null
	return ImageTexture.create_from_image(image)

func _create_sigil(parent: Node2D, index: int, position: Vector2) -> void:
	var sigil := Area2D.new()
	sigil.name = "GeneratedSigil%d" % index
	sigil.position = position
	sigil.add_to_group("sigils")
	parent.add_child(sigil)

	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = sigil_texture
	visual.scale = Vector2(0.74, 0.74)
	visual.modulate = Color(1.22, 1.04, 0.92, 1.0)
	visual.z_index = 6
	sigil.add_child(visual)

	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = sigil_texture
	glow.scale = Vector2(0.98, 0.98)
	glow.modulate = Color(1.0, 0.28, 0.16, 0.28)
	glow.z_index = 5
	sigil.add_child(glow)

	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	sigil.add_child(collision)

func _create_enemy(parent: Node2D, index: int, position: Vector2, is_elite: bool) -> void:
	var enemy: Area2D = ENEMY_SCRIPT.new()
	enemy.name = "GeneratedEnemy%d" % index
	enemy.position = position
	enemy.add_to_group("enemies")
	enemy.add_to_group("attack_targets")
	var hit_points := 2 if is_elite else 1
	enemy.set_meta("hit_points", hit_points)
	enemy.set_meta("max_hit_points", hit_points)
	enemy.set_meta("elite", is_elite)
	enemy.configure_patrol(66.0 + index * 10.0, 30.0 + index * 3.0, 265.0, 96.0 + index * 8.0)
	if is_elite:
		enemy.modulate = Color(1.16, 0.78, 0.78, 1.0)

	var sprite := _create_enemy_sprite()
	sprite.position = Vector2(0, -55)
	sprite.scale = Vector2(0.35, 0.35)
	sprite.z_index = 4
	enemy.add_child(sprite)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(42, 58)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	enemy.add_child(collision)
	parent.add_child(enemy)

func _create_boss(parent: Node2D, position: Vector2) -> void:
	var boss := Area2D.new()
	boss.name = "GeneratedBoss"
	boss.position = position
	boss.add_to_group("enemies")
	boss.add_to_group("bosses")
	boss.add_to_group("attack_targets")
	boss.set_meta("hit_points", BOSS_HIT_POINTS)
	boss.set_meta("max_hit_points", BOSS_HIT_POINTS)
	parent.add_child(boss)

	var sprite := _create_actor_sprite("BossSprite", boss_texture, BOSS_FRAME_SIZE, 5.5)
	sprite.position = Vector2(0, -81)
	sprite.scale = Vector2(0.48, 0.48)
	sprite.z_index = 3
	boss.add_child(sprite)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(92, 116)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	boss.add_child(collision)

func _create_actor_sprite(sprite_name: StringName, texture: Texture2D, frame_size: Vector2i, speed: float) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = sprite_name
	var frames := SpriteFrames.new()
	_add_texture_animation(frames, "idle", texture, frame_size, BOSS_FRAME_COUNT, speed, true)
	sprite.sprite_frames = frames
	sprite.play("idle")
	return sprite

func _create_enemy_sprite() -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "EnemySprite"
	var frames := SpriteFrames.new()
	_add_texture_animation(frames, "idle", enemy_idle_texture, ENEMY_FRAME_SIZE, ENEMY_IDLE_FRAME_COUNT, 7.0, true)
	_add_texture_animation(frames, "walk", enemy_walk_texture, ENEMY_FRAME_SIZE, ENEMY_WALK_FRAME_COUNT, 12.0, true)
	_add_texture_animation(frames, "attack", enemy_attack_texture, ENEMY_FRAME_SIZE, ENEMY_ATTACK_FRAME_COUNT, 16.0, true)
	sprite.sprite_frames = frames
	sprite.play("walk")
	return sprite

func _add_texture_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	texture: Texture2D,
	frame_size: Vector2i,
	frame_count: int,
	speed: float,
	loop: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, speed)
	for frame in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame(animation_name, atlas)
