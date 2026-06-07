extends Node

const DEFAULT_STAGE_SEED := 1337
const FLOOR_COLOR := Color(0.10, 0.10, 0.13, 0.92)
const BRANCH_COLOR := Color(0.08, 0.09, 0.12, 0.94)
const GATE_COLOR := Color(0.14, 0.11, 0.12, 0.96)
const SIGIL_COLOR := Color(0.72, 0.08, 0.13, 0.92)
const ENEMY_FRAME_SIZE := Vector2i(96, 96)
const BOSS_FRAME_SIZE := Vector2i(192, 160)
const ACTOR_FRAME_COUNT := 8
const CASTLE_LAYOUT_STYLE := "castle_keep"
const VERTICAL_ROOM_COUNT := 3
const SHORTCUT_COUNT := 1
const LOCKED_GATE_COUNT := 1
const CRITICAL_PATH_ROOM_COUNT := 6
const BOSS_HIT_POINTS := 3
const TARGET_CLEAR_ATTEMPTS := 2
const EXPECTED_CLEAR_ATTEMPTS := 2
const BALANCE_RISK_SCORE := 8
const BRANCH_CHALLENGE_COUNT := 2
const RECOVERY_WINDOW_COUNT := 2
const STAGE_PACING := "first_stage_two_try"
const ENEMY_TEXTURE := preload("res://assets/enemy-idle-sheet-8.png")
const BOSS_TEXTURE := preload("res://assets/boss-idle-sheet-8.png")
const ENEMY_LIBRARY := [
	Vector2(960, 432),
	Vector2(1715, 352),
	Vector2(2205, 402),
]
const BOSS_POSITION := Vector2(2390, 414)
const ROOM_LIBRARY := [
	{
		"name": "outer_gate",
		"platform": Vector2(520, 60),
		"center": Vector2(260, 510),
		"sigil": Vector2(330, 424),
		"critical_path": true,
	},
	{
		"name": "entry_stair",
		"platform": Vector2(260, 42),
		"center": Vector2(690, 470),
		"sigil": Vector2(660, 394),
		"critical_path": true,
	},
	{
		"name": "lower_cloister",
		"platform": Vector2(340, 72),
		"center": Vector2(1000, 516),
		"critical_path": true,
		"recovery": true,
	},
	{
		"name": "chapel_balcony",
		"platform": Vector2(240, 38),
		"center": Vector2(1210, 414),
		"sigil": Vector2(1215, 342),
		"branch": true,
		"vertical": true,
	},
	{
		"name": "library_landing",
		"platform": Vector2(260, 38),
		"center": Vector2(1450, 335),
		"sigil": Vector2(1450, 264),
		"branch": true,
		"vertical": true,
	},
	{
		"name": "crypt_drop",
		"platform": Vector2(400, 74),
		"center": Vector2(1530, 522),
		"sigil": Vector2(1585, 432),
		"critical_path": true,
	},
	{
		"name": "bell_tower",
		"platform": Vector2(250, 38),
		"center": Vector2(1785, 420),
		"sigil": Vector2(1780, 346),
		"branch": true,
		"vertical": true,
		"shortcut": true,
	},
	{
		"name": "recovery_gallery",
		"platform": Vector2(340, 60),
		"center": Vector2(1945, 492),
		"recovery": true,
	},
	{
		"name": "boss_antechamber",
		"platform": Vector2(300, 60),
		"center": Vector2(2225, 472),
		"critical_path": true,
	},
	{
		"name": "gate_hall",
		"platform": Vector2(480, 86),
		"center": Vector2(2565, 502),
		"gate": true,
		"critical_path": true,
	},
]

@export var stage_seed := DEFAULT_STAGE_SEED

func generate_stage(game: Node2D) -> Dictionary:
	var platforms: Node2D = game.get_node("Platforms")
	var collectibles: Node2D = game.get_node("Collectibles")
	var enemies: Node2D = game.get_node("Enemies")
	var player: CharacterBody2D = game.get_node("Player")
	var goal: Area2D = game.get_node("Goal")
	var rng := RandomNumberGenerator.new()
	rng.seed = stage_seed

	_clear_children(platforms)
	_clear_children(collectibles)
	_clear_children(enemies)

	var platform_count := 0
	var sigil_count := 0
	var enemy_count := 0
	var boss_count := 0
	for index in range(ROOM_LIBRARY.size()):
		var room: Dictionary = ROOM_LIBRARY[index]
		var jitter: Vector2 = _room_jitter(rng, index)
		var center: Vector2 = room["center"] + jitter
		_create_platform(platforms, room, center)
		platform_count += 1

		if room.has("sigil"):
			var sigil_position: Vector2 = room["sigil"] + jitter
			_create_sigil(collectibles, sigil_count + 1, sigil_position)
			sigil_count += 1

	for enemy_position in ENEMY_LIBRARY:
		_create_enemy(enemies, enemy_count + 1, enemy_position)
		enemy_count += 1
	_create_boss(enemies, BOSS_POSITION)
	enemy_count += 1
	boss_count += 1

	var entrance: Dictionary = ROOM_LIBRARY[0]
	var entrance_center: Vector2 = entrance["center"]
	var entrance_size: Vector2 = entrance["platform"]
	var entrance_top: float = entrance_center.y - entrance_size.y * 0.5
	player.global_position = Vector2(87, entrance_top - 8.0)

	var gate_floor: Dictionary = ROOM_LIBRARY[ROOM_LIBRARY.size() - 1]
	var gate_center: Vector2 = gate_floor["center"]
	var gate_size: Vector2 = gate_floor["platform"]
	var gate_top: float = gate_center.y - gate_size.y * 0.5
	goal.global_position = Vector2(gate_center.x + 120.0, gate_top - 16.0)

	return {
		"seed": stage_seed,
		"layout_style": CASTLE_LAYOUT_STYLE,
		"vertical_room_count": _count_rooms_with_flag("vertical"),
		"shortcut_count": _count_rooms_with_flag("shortcut"),
		"locked_gate_count": _count_rooms_with_flag("gate"),
		"critical_path_room_count": _count_rooms_with_flag("critical_path"),
		"platform_count": platform_count,
		"sigil_count": sigil_count,
		"enemy_count": enemy_count,
		"boss_count": boss_count,
		"goal_position": goal.global_position,
		"balance": _first_stage_balance(enemy_count),
		"theme": "cathedral_keep",
	}

func _room_jitter(rng: RandomNumberGenerator, index: int) -> Vector2:
	if index == 0 or index == ROOM_LIBRARY.size() - 1:
		return Vector2.ZERO
	return Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-4.0, 4.0))

func _first_stage_balance(enemy_count: int) -> Dictionary:
	return {
		"target_clear_attempts": TARGET_CLEAR_ATTEMPTS,
		"expected_clear_attempts": EXPECTED_CLEAR_ATTEMPTS,
		"risk_score": BALANCE_RISK_SCORE,
		"health_buffer_hits": 2,
		"focus_shots_available": 3,
		"branch_challenge_count": BRANCH_CHALLENGE_COUNT,
		"combat_encounter_count": enemy_count,
		"boss_hit_points": BOSS_HIT_POINTS,
		"recovery_window_count": RECOVERY_WINDOW_COUNT,
		"pacing": STAGE_PACING,
	}

func _count_rooms_with_flag(flag_name: String) -> int:
	var count := 0
	for room in ROOM_LIBRARY:
		if bool(room.get(flag_name, false)):
			count += 1
	return count

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.free()

func _create_platform(parent: Node2D, room: Dictionary, center: Vector2) -> void:
	var room_name: String = room["name"]
	var size: Vector2 = room["platform"]
	var platform := StaticBody2D.new()
	platform.name = "%s_platform" % room_name
	platform.position = center
	platform.set_meta("layout_style", CASTLE_LAYOUT_STYLE)
	platform.set_meta("room_name", room_name)
	platform.set_meta("branch", bool(room.get("branch", false)))
	platform.set_meta("vertical", bool(room.get("vertical", false)))
	platform.set_meta("shortcut", bool(room.get("shortcut", false)))
	platform.set_meta("gate", bool(room.get("gate", false)))
	platform.set_meta("critical_path", bool(room.get("critical_path", false)))
	parent.add_child(platform)

	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.offset_left = -size.x * 0.5
	visual.offset_top = -size.y * 0.5
	visual.offset_right = size.x * 0.5
	visual.offset_bottom = size.y * 0.5
	visual.color = _room_color(room)
	platform.add_child(visual)

	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	platform.add_child(collision)

func _room_color(room: Dictionary) -> Color:
	if bool(room.get("gate", false)):
		return GATE_COLOR
	if bool(room.get("branch", false)):
		return BRANCH_COLOR
	return FLOOR_COLOR

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

func _create_enemy(parent: Node2D, index: int, position: Vector2) -> void:
	var enemy := Area2D.new()
	enemy.name = "GeneratedEnemy%d" % index
	enemy.position = position
	enemy.add_to_group("enemies")
	enemy.add_to_group("attack_targets")
	enemy.set_meta("hit_points", 1)
	enemy.set_meta("max_hit_points", 1)
	parent.add_child(enemy)

	var sprite := _create_actor_sprite("EnemySprite", ENEMY_TEXTURE, ENEMY_FRAME_SIZE, 8.0)
	sprite.position = Vector2(0, -8)
	enemy.add_child(sprite)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(42, 58)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	enemy.add_child(collision)

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

	var sprite := _create_actor_sprite("BossSprite", BOSS_TEXTURE, BOSS_FRAME_SIZE, 5.5)
	sprite.position = Vector2(0, -22)
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
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", speed)
	for frame in range(ACTOR_FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame("idle", atlas)
	sprite.sprite_frames = frames
	sprite.play("idle")
	return sprite
