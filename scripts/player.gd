extends CharacterBody2D

const SPEED := 245.0
const JUMP_VELOCITY := -660.0
const GRAVITY := 1900.0
const MAX_FALL := 980.0
const FRAME_SIZE := Vector2i(192, 384)
const IDLE_FRAME_COUNT := 10
const WALK_FRAME_COUNT := 24
const IDLE_TEXTURE := preload("res://assets/player-idle-sheet-10.png")
const WALK_TEXTURE := preload("res://assets/player-walk-sheet-24.png")

@onready var player_sprite: AnimatedSprite2D = $PlayerSprite

var spawn_position := Vector2.ZERO
var forced_axis := 0.0
var force_jump := false
var e2e_control := false
var facing_left := false

func _ready() -> void:
	spawn_position = global_position
	_setup_animations()
	_update_animation()

func _physics_process(delta: float) -> void:
	var axis := forced_axis if e2e_control else Input.get_axis("move_left", "move_right")

	velocity.x = axis * SPEED
	if axis != 0.0:
		facing_left = axis < 0.0

	if (force_jump or Input.is_action_just_pressed("jump")) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	force_jump = false

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	_update_animation()

func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	e2e_control = false
	forced_axis = 0.0
	force_jump = false
	_update_animation()

func e2e_set_axis(axis: float) -> void:
	e2e_control = true
	forced_axis = clampf(axis, -1.0, 1.0)

func e2e_jump() -> void:
	force_jump = true

func _setup_animations() -> void:
	var sprite_frames := SpriteFrames.new()
	_add_sheet_animation(sprite_frames, "idle", IDLE_TEXTURE, IDLE_FRAME_COUNT, 7.0)
	_add_sheet_animation(sprite_frames, "walk", WALK_TEXTURE, WALK_FRAME_COUNT, 18.0)
	player_sprite.sprite_frames = sprite_frames
	player_sprite.play("idle")

func _update_animation() -> void:
	var walking := absf(velocity.x) > 1.0 and is_on_floor()
	player_sprite.flip_h = facing_left
	if walking:
		player_sprite.speed_scale = clampf(absf(velocity.x) / SPEED, 0.85, 1.35)
		if player_sprite.animation != "walk":
			player_sprite.play("walk")
	else:
		player_sprite.speed_scale = 1.0
		if player_sprite.animation != "idle":
			player_sprite.play("idle")

func _add_sheet_animation(sprite_frames: SpriteFrames, animation_name: StringName, texture: Texture2D, frame_count: int, speed: float) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, true)
	sprite_frames.set_animation_speed(animation_name, speed)
	for frame in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		sprite_frames.add_frame(animation_name, atlas)
