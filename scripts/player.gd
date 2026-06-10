extends CharacterBody2D

const SPEED := 245.0
const JUMP_VELOCITY := -660.0
const GRAVITY := 1900.0
const MAX_FALL := 980.0
const FRAME_SIZE := Vector2i(192, 384)
const IDLE_FRAME_COUNT := 10
const WALK_FRAME_COUNT := 24
const ATTACK_BODY_FRAME_COUNT := 8
const COMBO_STEP_COUNT := 3
const SHOOT_FRAME_COUNT := 8
const ATTACK_ANIMATION_FPS := 16.0
const ATTACK_DURATION := 0.50
const ATTACK_ACTIVE_START := 0.25
const ATTACK_ACTIVE_END := 0.37
const ATTACK_HITBOX_OFFSETS := [Vector2(76, -48), Vector2(82, -58), Vector2(88, -42)]
const ATTACK_HITBOX_SIZES := [Vector2(126, 88), Vector2(136, 104), Vector2(146, 96)]
const AXE_BASE_POSITION := Vector2(-2, -68)
const AXE_ATTACK_POSITION := Vector2(28, -70)
const AXE_BASE_SCALE := Vector2(0.3, 0.3)
const AXE_ATTACK_SCALE := Vector2(0.52, 0.52)
const KNOCKBACK_DURATION := 0.24
const KNOCKBACK_VELOCITY := Vector2(360, -260)
const ATTACK_RECOVERY_SPEED_SCALE := 0.35
const COMBO_RESET_TIME := 1.5
const SHOOT_DURATION := 0.28
const FOCUS_MAX := 3.0
const FOCUS_REGEN_PER_SECOND := 0.75
const SHOT_COST := 1.0
const SHOT_SPEED := 820.0
const SHOT_LIFETIME := 0.85
const SHOT_OFFSET := Vector2(86, -45)
const SHOT_SIZE := Vector2(54, 18)
const SHOT_FRAME_SIZE := Vector2i(160, 72)
const SHOT_VFX_FRAME_COUNT := 6
const SHOT_VFX_FPS := 24.0
const IDLE_TEXTURE := preload("res://assets/player-idle-sheet-10.png")
const WALK_TEXTURE := preload("res://assets/player-walk-sheet-24.png")
const ATTACK_BODY_TEXTURE_PATH := "res://assets/player-attack-combo-sheet-24.png"
const SHOOT_TEXTURE := preload("res://assets/player-shoot-sheet-8.png")
const AXE_IDLE_TEXTURE_PATH := "res://assets/player-axe-idle-sheet-10.png"
const AXE_WALK_TEXTURE_PATH := "res://assets/player-axe-walk-sheet-24.png"
const AXE_ATTACK_TEXTURE_PATH := "res://assets/player-axe-attack-combo-sheet-24.png"
const AXE_SHOOT_TEXTURE_PATH := "res://assets/player-axe-shoot-sheet-8.png"
const SHOT_TEXTURE_PATH := "res://assets/player-shot-sheet-6.png"

@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var axe_sprite: AnimatedSprite2D = $AxeSprite
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var projectile_container: Node2D = $"../Projectiles"

var spawn_position := Vector2.ZERO
var forced_axis := 0.0
var force_jump := false
var force_attack := false
var force_shoot := false
var e2e_control := false
var facing_left := false
var attack_timer := 0.0
var combo_reset_timer := 0.0
var current_attack_step := 0
var shoot_timer := 0.0
var shoot_focus := FOCUS_MAX
var knockback_timer := 0.0
var knockback_velocity := Vector2.ZERO
var hit_targets := {}
var shot_texture: Texture2D
var attack_body_texture: Texture2D
var axe_idle_texture: Texture2D
var axe_walk_texture: Texture2D
var axe_attack_texture: Texture2D
var axe_shoot_texture: Texture2D

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	attack_body_texture = _load_png_texture(ATTACK_BODY_TEXTURE_PATH)
	shot_texture = _load_png_texture(SHOT_TEXTURE_PATH)
	axe_idle_texture = _load_png_texture(AXE_IDLE_TEXTURE_PATH)
	axe_walk_texture = _load_png_texture(AXE_WALK_TEXTURE_PATH)
	axe_attack_texture = _load_png_texture(AXE_ATTACK_TEXTURE_PATH)
	axe_shoot_texture = _load_png_texture(AXE_SHOOT_TEXTURE_PATH)
	_setup_animations()
	_configure_attack_hitbox_shape()
	attack_hitbox.area_entered.connect(_on_attack_area_entered)
	_update_animation()

func _physics_process(delta: float) -> void:
	var axis := forced_axis if e2e_control else Input.get_axis("move_left", "move_right")

	if force_attack or Input.is_action_just_pressed("attack"):
		attack()
	force_attack = false

	if force_shoot or Input.is_action_just_pressed("shoot"):
		shoot()
	force_shoot = false

	var speed_scale := ATTACK_RECOVERY_SPEED_SCALE if is_attacking() else 1.0
	if axis != 0.0:
		facing_left = axis < 0.0

	if (force_jump or Input.is_action_just_pressed("jump")) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	force_jump = false

	var knockback_factor := _update_knockback(delta)
	var control_x := axis * SPEED * speed_scale
	velocity.x = control_x + knockback_velocity.x * knockback_factor
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	_update_focus(delta)
	_update_projectiles(delta)
	_update_combo(delta)
	_update_shoot(delta)
	_update_attack(delta)
	_update_animation()

func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	e2e_control = false
	forced_axis = 0.0
	force_jump = false
	force_attack = false
	force_shoot = false
	attack_timer = 0.0
	combo_reset_timer = 0.0
	current_attack_step = 0
	shoot_timer = 0.0
	knockback_timer = 0.0
	knockback_velocity = Vector2.ZERO
	attack_hitbox.monitoring = false
	_update_animation()

func e2e_set_axis(axis: float) -> void:
	e2e_control = true
	forced_axis = clampf(axis, -1.0, 1.0)

func e2e_jump() -> void:
	force_jump = true

func e2e_attack() -> void:
	force_attack = true

func e2e_shoot() -> void:
	force_shoot = true

func attack() -> void:
	if is_attacking():
		return
	current_attack_step = _advance_combo_step()
	attack_timer = ATTACK_DURATION
	combo_reset_timer = COMBO_RESET_TIME
	hit_targets = {}
	_play_attack_body_animation(current_attack_step)
	_sync_attack_geometry()

func shoot() -> bool:
	if not can_shoot():
		return false
	shoot_focus = maxf(shoot_focus - SHOT_COST, 0.0)
	shoot_timer = SHOOT_DURATION
	_play_shoot_body_animation()
	_create_projectile()
	return true

func can_shoot() -> bool:
	return shoot_focus >= SHOT_COST

func is_attacking() -> bool:
	return attack_timer > 0.0

func is_shooting() -> bool:
	return shoot_timer > 0.0

func apply_damage_knockback(source_position: Vector2) -> void:
	var direction := -1.0 if global_position.x < source_position.x else 1.0
	knockback_velocity = Vector2(KNOCKBACK_VELOCITY.x * direction, KNOCKBACK_VELOCITY.y)
	knockback_timer = KNOCKBACK_DURATION
	velocity = knockback_velocity

func _setup_animations() -> void:
	var sprite_frames := SpriteFrames.new()
	_add_sheet_animation(sprite_frames, "idle", IDLE_TEXTURE, IDLE_FRAME_COUNT, 7.0)
	_add_sheet_animation(sprite_frames, "walk", WALK_TEXTURE, WALK_FRAME_COUNT, 18.0)
	for step in range(COMBO_STEP_COUNT):
		_add_sheet_animation_range(
			sprite_frames,
			StringName("attack%d" % [step + 1]),
			attack_body_texture,
			step * ATTACK_BODY_FRAME_COUNT,
			ATTACK_BODY_FRAME_COUNT,
			ATTACK_ANIMATION_FPS,
			false,
		)
	_add_sheet_animation(sprite_frames, "shoot", SHOOT_TEXTURE, SHOOT_FRAME_COUNT, 22.0, false)
	player_sprite.sprite_frames = sprite_frames
	player_sprite.play("idle")
	_setup_axe_animations()

func _setup_axe_animations() -> void:
	var sprite_frames := SpriteFrames.new()
	_add_sheet_animation(sprite_frames, "idle", axe_idle_texture, IDLE_FRAME_COUNT, 7.0)
	_add_sheet_animation(sprite_frames, "walk", axe_walk_texture, WALK_FRAME_COUNT, 18.0)
	for step in range(COMBO_STEP_COUNT):
		_add_sheet_animation_range(
			sprite_frames,
			StringName("attack%d" % [step + 1]),
			axe_attack_texture,
			step * ATTACK_BODY_FRAME_COUNT,
			ATTACK_BODY_FRAME_COUNT,
			ATTACK_ANIMATION_FPS,
			false,
		)
	_add_sheet_animation(sprite_frames, "shoot", axe_shoot_texture, SHOOT_FRAME_COUNT, 22.0, false)
	axe_sprite.sprite_frames = sprite_frames
	axe_sprite.play("idle")

func _update_animation() -> void:
	var walking := absf(velocity.x) > 1.0 and is_on_floor()
	player_sprite.flip_h = facing_left
	axe_sprite.flip_h = facing_left
	_sync_attack_geometry()
	if is_attacking():
		player_sprite.speed_scale = 1.0
		axe_sprite.speed_scale = 1.0
		return
	if is_shooting():
		player_sprite.speed_scale = 1.0
		axe_sprite.speed_scale = 1.0
		if player_sprite.animation != "shoot":
			player_sprite.play("shoot")
		if axe_sprite.animation != "shoot":
			axe_sprite.play("shoot")
		return
	if walking:
		player_sprite.speed_scale = clampf(absf(velocity.x) / SPEED, 0.85, 1.35)
		axe_sprite.speed_scale = player_sprite.speed_scale
		if player_sprite.animation != "walk":
			player_sprite.play("walk")
		if axe_sprite.animation != "walk":
			axe_sprite.play("walk")
	else:
		player_sprite.speed_scale = 1.0
		axe_sprite.speed_scale = 1.0
		if player_sprite.animation != "idle":
			player_sprite.play("idle")
		if axe_sprite.animation != "idle":
			axe_sprite.play("idle")

func _configure_attack_hitbox_shape() -> void:
	_set_attack_hitbox_size(ATTACK_HITBOX_SIZES[0])

func _set_attack_hitbox_size(size: Vector2) -> void:
	var collision_shape := attack_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = size

func _sync_attack_geometry() -> void:
	var direction := -1.0 if facing_left else 1.0
	var profile_index := clampi(current_attack_step - 1, 0, COMBO_STEP_COUNT - 1)
	var hitbox_offset: Vector2 = ATTACK_HITBOX_OFFSETS[profile_index]
	var hitbox_size: Vector2 = ATTACK_HITBOX_SIZES[profile_index]
	attack_hitbox.position = Vector2(hitbox_offset.x * direction, hitbox_offset.y)
	_set_attack_hitbox_size(hitbox_size)
	if is_attacking():
		axe_sprite.position = Vector2(AXE_ATTACK_POSITION.x * direction, AXE_ATTACK_POSITION.y)
		axe_sprite.scale = AXE_ATTACK_SCALE
	else:
		axe_sprite.position = Vector2(AXE_BASE_POSITION.x * direction, AXE_BASE_POSITION.y)
		axe_sprite.scale = AXE_BASE_SCALE

func _update_knockback(delta: float) -> float:
	if knockback_timer <= 0.0:
		knockback_velocity = Vector2.ZERO
		return 0.0
	var factor := knockback_timer / KNOCKBACK_DURATION
	knockback_timer = maxf(knockback_timer - delta, 0.0)
	if knockback_timer <= 0.0:
		knockback_velocity = Vector2.ZERO
	return factor

func _advance_combo_step() -> int:
	if combo_reset_timer <= 0.0:
		return 1
	return (current_attack_step % COMBO_STEP_COUNT) + 1

func _play_attack_body_animation(step: int) -> void:
	player_sprite.speed_scale = 1.0
	axe_sprite.speed_scale = 1.0
	var animation_name := StringName("attack%d" % [clampi(step, 1, COMBO_STEP_COUNT)])
	player_sprite.play(animation_name)
	axe_sprite.play(animation_name)

func _play_shoot_body_animation() -> void:
	player_sprite.speed_scale = 1.0
	axe_sprite.speed_scale = 1.0
	player_sprite.play("shoot")
	axe_sprite.play("shoot")

func _update_combo(delta: float) -> void:
	if combo_reset_timer <= 0.0:
		current_attack_step = 0
		return
	combo_reset_timer = maxf(combo_reset_timer - delta, 0.0)
	if combo_reset_timer <= 0.0 and not is_attacking():
		current_attack_step = 0

func _update_shoot(delta: float) -> void:
	if shoot_timer > 0.0:
		shoot_timer = maxf(shoot_timer - delta, 0.0)

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
		_sync_attack_geometry()

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
	_damage_attack_target(area)

func _update_focus(delta: float) -> void:
	shoot_focus = minf(shoot_focus + FOCUS_REGEN_PER_SECOND * delta, FOCUS_MAX)

func _create_projectile() -> Area2D:
	var projectile := Area2D.new()
	var direction := -1.0 if facing_left else 1.0
	projectile.name = "PlayerShot"
	projectile.global_position = global_position + Vector2(SHOT_OFFSET.x * direction, SHOT_OFFSET.y)
	projectile.add_to_group("player_projectiles")
	projectile.set_meta("direction", direction)
	projectile.set_meta("age", 0.0)
	projectile.area_entered.connect(_on_projectile_area_entered.bind(projectile))
	projectile_container.add_child(projectile)

	var visual := AnimatedSprite2D.new()
	visual.name = "Visual"
	visual.sprite_frames = _build_projectile_sprite_frames()
	visual.play("fly")
	visual.flip_h = direction < 0.0
	visual.z_index = 8
	projectile.add_child(visual)

	var shape := RectangleShape2D.new()
	shape.size = SHOT_SIZE
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	projectile.add_child(collision)
	return projectile

func _build_projectile_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	var animation_name := StringName("fly")
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, false)
	sprite_frames.set_animation_speed(animation_name, SHOT_VFX_FPS)
	for frame in range(SHOT_VFX_FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = shot_texture
		atlas.region = Rect2(frame * SHOT_FRAME_SIZE.x, 0, SHOT_FRAME_SIZE.x, SHOT_FRAME_SIZE.y)
		sprite_frames.add_frame(animation_name, atlas)
	return sprite_frames

func _update_projectiles(delta: float) -> void:
	if projectile_container == null:
		return
	for projectile: Area2D in projectile_container.get_children():
		var direction: float = float(projectile.get_meta("direction", 1.0))
		var age: float = float(projectile.get_meta("age", 0.0)) + delta
		var previous_x := projectile.global_position.x
		projectile.set_meta("age", age)
		projectile.global_position.x += direction * SHOT_SPEED * delta
		_hit_projectile_sweep(projectile, previous_x, projectile.global_position.x)
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		_hit_projectile_overlaps(projectile)
		if age >= SHOT_LIFETIME and is_instance_valid(projectile):
			projectile.queue_free()

func _hit_projectile_sweep(projectile: Area2D, previous_x: float, current_x: float) -> void:
	var min_x := minf(previous_x, current_x) - SHOT_SIZE.x
	var max_x := maxf(previous_x, current_x) + SHOT_SIZE.x
	for area: Area2D in get_tree().get_nodes_in_group("attack_targets"):
		if area.get_meta("destroyed", false) or not area.visible:
			continue
		var horizontal_hit := area.global_position.x >= min_x and area.global_position.x <= max_x
		var vertical_hit := absf(area.global_position.y - projectile.global_position.y) <= 36.0
		if horizontal_hit and vertical_hit:
			_hit_projectile_target(projectile, area)
			return

func _on_projectile_area_entered(area: Area2D, projectile: Area2D) -> void:
	_hit_projectile_target(projectile, area)

func _hit_projectile_overlaps(projectile: Area2D) -> void:
	for area: Area2D in projectile.get_overlapping_areas():
		_hit_projectile_target(projectile, area)
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			return

func _hit_projectile_target(projectile: Area2D, area: Area2D) -> void:
	if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
		return
	if not area.is_in_group("attack_targets") or area.get_meta("destroyed", false):
		return
	_damage_attack_target(area)
	projectile.queue_free()

func _damage_attack_target(area: Area2D) -> void:
	var hit_points := int(area.get_meta("hit_points", 1)) - 1
	area.set_meta("hit_points", hit_points)
	if hit_points > 0:
		area.modulate = Color(1.25, 0.82, 0.82, 1.0)
		return
	_destroy_attack_target(area)

func _destroy_attack_target(area: Area2D) -> void:
	area.set_meta("destroyed", true)
	area.visible = false
	area.set_deferred("monitoring", false)
	area.set_deferred("monitorable", false)

func _add_sheet_animation(sprite_frames: SpriteFrames, animation_name: StringName, texture: Texture2D, frame_count: int, speed: float, loop := true) -> void:
	_add_sheet_animation_range(sprite_frames, animation_name, texture, 0, frame_count, speed, loop)

func _add_sheet_animation_range(sprite_frames: SpriteFrames, animation_name: StringName, texture: Texture2D, start_frame: int, frame_count: int, speed: float, loop := true) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, loop)
	sprite_frames.set_animation_speed(animation_name, speed)
	for frame in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((start_frame + frame) * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		sprite_frames.add_frame(animation_name, atlas)

func _load_png_texture(path: String) -> Texture2D:
	var image := Image.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	var error := image.load_png_from_buffer(bytes)
	if error != OK:
		push_error("Failed to load player projectile texture: %s" % [path])
		return null
	return ImageTexture.create_from_image(image)
