extends Area2D

const PATROL_STATE := "walk"
const WINDUP_STATE := "windup"
const ATTACK_STATE := "attack"
const GRAVITY := 1600.0
const MAX_FALL_SPEED := 780.0
const FLOOR_SNAP_DISTANCE := 12.0
const FLOOR_PROBE_UP := 28.0
const FLOOR_PROBE_DOWN := 96.0
const FOOT_OFFSET_Y := 29.0
const HIT_FLASH_DURATION := 0.12
const HIT_REACTION_DURATION := 0.16
const DEATH_HOLD_DURATION := 0.22
const WINDUP_DURATION := 0.18
const WINDUP_TELL_COLOR := Color(1.0, 0.30, 0.12, 0.76)
const WINDUP_RIM_COLOR := Color(1.0, 0.60, 0.32, 0.70)

var patrol_origin := Vector2.ZERO
var patrol_radius := 74.0
var patrol_speed := 34.0
var detection_distance := 270.0
var lunge_speed := 104.0
var facing_left := true
var direction := -1.0
var vertical_velocity := 0.0
var grounded := false
var hit_flash_timer := 0.0
var hit_reaction_timer := 0.0
var hit_knockback_velocity := 0.0
var death_hold_timer := 0.0
var windup_timer := 0.0
var windup_direction := -1.0
var windup_tell: Node2D

@onready var sprite: AnimatedSprite2D = get_node_or_null("EnemySprite")

func _ready() -> void:
	_ensure_windup_tell()
	if patrol_origin == Vector2.ZERO:
		patrol_origin = global_position
	_set_state(PATROL_STATE)

func configure_patrol(radius: float, speed: float, detection: float, lunge: float) -> void:
	patrol_origin = global_position
	patrol_radius = radius
	patrol_speed = speed
	detection_distance = detection
	lunge_speed = lunge

func _physics_process(delta: float) -> void:
	if not visible:
		return
	if bool(get_meta("destroyed", false)):
		_update_hit_reaction(delta)
		_update_hit_feedback(delta)
		_update_windup_visual()
		_update_death_hold(delta)
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var previous_y := global_position.y
	if windup_timer > 0.0:
		_update_windup(delta)
	elif _should_lunge_after_windup(player):
		_update_lunge(player, delta)
	elif _can_lunge_at(player):
		if get_meta("ai_state", "") == ATTACK_STATE:
			_update_lunge(player, delta)
		else:
			_start_windup(player)
	else:
		_update_patrol(delta)
	_update_hit_reaction(delta)
	_apply_gravity(delta, previous_y)
	_update_hit_feedback(delta)
	_update_facing()
	_update_windup_visual()

func _can_lunge_at(player: Node2D) -> bool:
	if player == null:
		return false
	var to_player := player.global_position - global_position
	return absf(to_player.x) <= detection_distance and absf(to_player.y) <= 92.0

func _update_lunge(player: Node2D, delta: float) -> void:
	direction = -1.0 if player.global_position.x < global_position.x else 1.0
	var proposed_x := global_position.x + direction * lunge_speed * delta
	if _can_move_to_x(proposed_x):
		global_position.x = proposed_x
	else:
		direction *= -1.0
	_set_state(ATTACK_STATE)

func _start_windup(player: Node2D) -> void:
	windup_direction = -1.0 if player.global_position.x < global_position.x else 1.0
	direction = windup_direction
	windup_timer = WINDUP_DURATION
	set_meta("windup_started", true)
	_set_state(WINDUP_STATE)

func _update_windup(delta: float) -> void:
	windup_timer = maxf(windup_timer - delta, 0.0)
	direction = windup_direction
	_set_state(WINDUP_STATE)

func _ensure_windup_tell() -> void:
	if windup_tell != null:
		return
	windup_tell = Node2D.new()
	windup_tell.name = "WindupTell"
	windup_tell.visible = false
	windup_tell.z_index = 6
	add_child(windup_tell)

	var foot := Line2D.new()
	foot.name = "FootTell"
	foot.width = 7.0
	foot.default_color = WINDUP_TELL_COLOR
	foot.joint_mode = Line2D.LINE_JOINT_ROUND
	foot.begin_cap_mode = Line2D.LINE_CAP_ROUND
	foot.end_cap_mode = Line2D.LINE_CAP_ROUND
	foot.points = PackedVector2Array([
		Vector2(-20.0, 29.0),
		Vector2(14.0, 29.0),
		Vector2(36.0, 23.0),
	])
	windup_tell.add_child(foot)

	var rim := Line2D.new()
	rim.name = "RimTell"
	rim.width = 3.0
	rim.default_color = WINDUP_RIM_COLOR
	rim.joint_mode = Line2D.LINE_JOINT_ROUND
	rim.begin_cap_mode = Line2D.LINE_CAP_ROUND
	rim.end_cap_mode = Line2D.LINE_CAP_ROUND
	rim.points = PackedVector2Array([
		Vector2(16.0, -74.0),
		Vector2(24.0, -42.0),
		Vector2(18.0, -8.0),
	])
	windup_tell.add_child(rim)

func _update_windup_visual() -> void:
	if windup_tell == null:
		return
	var active := windup_timer > 0.0 and not bool(get_meta("destroyed", false))
	windup_tell.visible = active
	if not active:
		set_meta("windup_tell_visible", false)
		return
	var progress := 1.0 - clampf(windup_timer / WINDUP_DURATION, 0.0, 1.0)
	windup_tell.scale = Vector2(windup_direction * (1.0 + progress * 0.08), 1.0)
	windup_tell.modulate = Color(1.0, 1.0, 1.0, 0.78 + progress * 0.22)
	set_meta("windup_tell_visible", true)
	set_meta("windup_direction", "left" if windup_direction < 0.0 else "right")

func _should_lunge_after_windup(player: Node2D) -> bool:
	return windup_timer <= 0.0 and get_meta("ai_state", "") == WINDUP_STATE and _can_lunge_at(player)

func _update_patrol(delta: float) -> void:
	var proposed_x := global_position.x + direction * patrol_speed * delta
	if _can_move_to_x(proposed_x):
		global_position.x = proposed_x
	else:
		direction *= -1.0
	var offset_x := global_position.x - patrol_origin.x
	if offset_x <= -patrol_radius:
		direction = 1.0
	elif offset_x >= patrol_radius:
		direction = -1.0
	_set_state(PATROL_STATE)

func _apply_gravity(delta: float, previous_y: float) -> void:
	vertical_velocity = minf(vertical_velocity + GRAVITY * delta, MAX_FALL_SPEED)
	global_position.y += vertical_velocity * delta
	grounded = false

	var ray_start := Vector2(global_position.x, previous_y + FOOT_OFFSET_Y - FLOOR_PROBE_UP)
	var ray_end := Vector2(global_position.x, global_position.y + FOOT_OFFSET_Y + FLOOR_SNAP_DISTANCE + FLOOR_PROBE_DOWN)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	if hit.get("collider") is StaticBody2D:
		global_position.y = float(hit["position"].y) - FOOT_OFFSET_Y
		vertical_velocity = 0.0
		grounded = true

func _update_facing() -> void:
	facing_left = direction < 0.0
	if sprite != null:
		sprite.flip_h = not facing_left

func apply_hit_reaction(source_position: Vector2, force: float, lethal: bool) -> void:
	hit_flash_timer = HIT_FLASH_DURATION
	hit_reaction_timer = HIT_REACTION_DURATION
	hit_knockback_velocity = force
	if source_position.x > global_position.x:
		direction = -1.0
	else:
		direction = 1.0
	if lethal:
		death_hold_timer = DEATH_HOLD_DURATION
	set_meta("hit_flash_started", true)
	set_meta("hit_knockback_started", true)

func _update_hit_reaction(delta: float) -> void:
	if hit_reaction_timer <= 0.0:
		hit_knockback_velocity = 0.0
		return
	var factor := hit_reaction_timer / HIT_REACTION_DURATION
	hit_reaction_timer = maxf(hit_reaction_timer - delta, 0.0)
	var proposed_x := global_position.x + hit_knockback_velocity * factor * delta
	if _can_move_to_x(proposed_x):
		global_position.x = proposed_x
	else:
		hit_reaction_timer = 0.0
		hit_knockback_velocity = 0.0

func _update_hit_feedback(delta: float) -> void:
	if hit_flash_timer <= 0.0:
		if windup_timer > 0.0:
			modulate = Color(1.28, 1.04, 0.82, 1.0)
			return
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
	modulate = Color(1.65, 1.58, 1.45, 1.0)

func _update_death_hold(delta: float) -> void:
	if death_hold_timer <= 0.0:
		visible = false
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		return
	death_hold_timer = maxf(death_hold_timer - delta, 0.0)

func _can_move_to_x(proposed_x: float) -> bool:
	if not grounded:
		return true
	return _has_floor_at(proposed_x + direction * 24.0)

func _has_floor_at(world_x: float) -> bool:
	var ray_start := Vector2(world_x, global_position.y + FOOT_OFFSET_Y - FLOOR_PROBE_UP)
	var ray_end := Vector2(world_x, global_position.y + FOOT_OFFSET_Y + FLOOR_SNAP_DISTANCE + FLOOR_PROBE_DOWN)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") is StaticBody2D

func _set_state(state: StringName) -> void:
	set_meta("ai_state", state)
	if sprite == null:
		return
	var animation_name := state
	if state == WINDUP_STATE:
		animation_name = ATTACK_STATE
	if sprite.animation != animation_name:
		sprite.play(animation_name)
