extends CharacterBody2D

const SPEED := 245.0
const JUMP_VELOCITY := -660.0
const GRAVITY := 1900.0
const MAX_FALL := 980.0
const FRAME_SIZE := Vector2i(192, 384)
const ATTACK_FRAME_SIZE := Vector2i(128, 128)
const IDLE_FRAME_COUNT := 10
const WALK_FRAME_COUNT := 24
const ATTACK_FRAME_COUNT := 8
const ATTACK_DURATION := 0.34
const ATTACK_ACTIVE_START := 0.08
const ATTACK_ACTIVE_END := 0.22
const ATTACK_RECOVERY_SPEED_SCALE := 0.35
const IDLE_TEXTURE := preload("res://assets/player-idle-sheet-10.png")
const WALK_TEXTURE := preload("res://assets/player-walk-sheet-24.png")
const ATTACK_TEXTURE := preload("res://assets/axe-swing-sheet-8.png")

@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var attack_arc: AnimatedSprite2D = $AttackArc
@onready var attack_hitbox: Area2D = $AttackHitbox

var spawn_position := Vector2.ZERO
var forced_axis := 0.0
var force_jump := false
var force_attack := false
var e2e_control := false
var facing_left := false
var attack_timer := 0.0
var hit_targets := {}

func _ready() -> void:
	spawn_position = global_position
	_setup_animations()
	_setup_attack_animation()
	attack_hitbox.area_entered.connect(_on_attack_area_entered)
	_update_animation()

func _physics_process(delta: float) -> void:
	var axis := forced_axis if e2e_control else Input.get_axis("move_left", "move_right")

	if force_attack or Input.is_action_just_pressed("attack"):
		attack()
	force_attack = false

	var speed_scale := ATTACK_RECOVERY_SPEED_SCALE if is_attacking() else 1.0
	velocity.x = axis * SPEED * speed_scale
	if axis != 0.0:
		facing_left = axis < 0.0

	if (force_jump or Input.is_action_just_pressed("jump")) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	force_jump = false

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	_update_attack(delta)
	_update_animation()

func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	e2e_control = false
	forced_axis = 0.0
	force_jump = false
	force_attack = false
	attack_timer = 0.0
	attack_hitbox.monitoring = false
	attack_arc.visible = false
	_update_animation()

func e2e_set_axis(axis: float) -> void:
	e2e_control = true
	forced_axis = clampf(axis, -1.0, 1.0)

func e2e_jump() -> void:
	force_jump = true

func e2e_attack() -> void:
	force_attack = true

func attack() -> void:
	if is_attacking():
		return
	attack_timer = ATTACK_DURATION
	hit_targets = {}
	attack_arc.visible = true
	attack_arc.play("swing")

func is_attacking() -> bool:
	return attack_timer > 0.0

func _setup_animations() -> void:
	var sprite_frames := SpriteFrames.new()
	_add_sheet_animation(sprite_frames, "idle", IDLE_TEXTURE, IDLE_FRAME_COUNT, 7.0)
	_add_sheet_animation(sprite_frames, "walk", WALK_TEXTURE, WALK_FRAME_COUNT, 18.0)
	player_sprite.sprite_frames = sprite_frames
	player_sprite.play("idle")

func _setup_attack_animation() -> void:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("swing")
	sprite_frames.set_animation_loop("swing", false)
	sprite_frames.set_animation_speed("swing", 24.0)
	for frame in range(ATTACK_FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = ATTACK_TEXTURE
		atlas.region = Rect2(frame * ATTACK_FRAME_SIZE.x, 0, ATTACK_FRAME_SIZE.x, ATTACK_FRAME_SIZE.y)
		sprite_frames.add_frame("swing", atlas)
	attack_arc.sprite_frames = sprite_frames
	attack_arc.visible = false

func _update_animation() -> void:
	var walking := absf(velocity.x) > 1.0 and is_on_floor()
	player_sprite.flip_h = facing_left
	attack_arc.flip_h = facing_left
	attack_arc.position.x = -44.0 if facing_left else 44.0
	attack_hitbox.position.x = -62.0 if facing_left else 62.0
	if walking:
		player_sprite.speed_scale = clampf(absf(velocity.x) / SPEED, 0.85, 1.35)
		if player_sprite.animation != "walk":
			player_sprite.play("walk")
	else:
		player_sprite.speed_scale = 1.0
		if player_sprite.animation != "idle":
			player_sprite.play("idle")

func _update_attack(delta: float) -> void:
	if attack_timer <= 0.0:
		attack_hitbox.monitoring = false
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	var elapsed := ATTACK_DURATION - attack_timer
	attack_hitbox.monitoring = elapsed >= ATTACK_ACTIVE_START and elapsed <= ATTACK_ACTIVE_END
	if attack_hitbox.monitoring:
		_strike_overlapping_targets()
	if attack_timer <= 0.0:
		attack_hitbox.monitoring = false
		attack_arc.visible = false

func _on_attack_area_entered(area: Area2D) -> void:
	_strike_target(area)

func _strike_overlapping_targets() -> void:
	for area: Area2D in attack_hitbox.get_overlapping_areas():
		_strike_target(area)

func _strike_target(area: Area2D) -> void:
	if not attack_hitbox.monitoring or not area.is_in_group("attack_targets"):
		return
	var target_id := area.get_instance_id()
	if hit_targets.has(target_id):
		return
	hit_targets[target_id] = true
	area.set_meta("destroyed", true)
	area.visible = false
	area.set_deferred("monitoring", false)
	area.set_deferred("monitorable", false)

func _add_sheet_animation(sprite_frames: SpriteFrames, animation_name: StringName, texture: Texture2D, frame_count: int, speed: float) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, true)
	sprite_frames.set_animation_speed(animation_name, speed)
	for frame in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		sprite_frames.add_frame(animation_name, atlas)
