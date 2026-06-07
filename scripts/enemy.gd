extends Area2D

const PATROL_STATE := "walk"
const ATTACK_STATE := "attack"

var patrol_origin := Vector2.ZERO
var patrol_radius := 74.0
var patrol_speed := 34.0
var detection_distance := 270.0
var lunge_speed := 104.0
var facing_left := true
var direction := -1.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("EnemySprite")

func _ready() -> void:
	if patrol_origin == Vector2.ZERO:
		patrol_origin = global_position
	_set_state(PATROL_STATE)

func configure_patrol(radius: float, speed: float, detection: float, lunge: float) -> void:
	patrol_origin = global_position
	patrol_radius = radius
	patrol_speed = speed
	detection_distance = detection
	lunge_speed = lunge

func _process(delta: float) -> void:
	if bool(get_meta("destroyed", false)) or not visible:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if _can_lunge_at(player):
		_update_lunge(player, delta)
	else:
		_update_patrol(delta)
	_update_facing()

func _can_lunge_at(player: Node2D) -> bool:
	if player == null:
		return false
	var to_player := player.global_position - global_position
	return absf(to_player.x) <= detection_distance and absf(to_player.y) <= 92.0

func _update_lunge(player: Node2D, delta: float) -> void:
	direction = -1.0 if player.global_position.x < global_position.x else 1.0
	global_position.x += direction * lunge_speed * delta
	_set_state(ATTACK_STATE)

func _update_patrol(delta: float) -> void:
	global_position.x += direction * patrol_speed * delta
	var offset_x := global_position.x - patrol_origin.x
	if offset_x <= -patrol_radius:
		direction = 1.0
	elif offset_x >= patrol_radius:
		direction = -1.0
	_set_state(PATROL_STATE)

func _update_facing() -> void:
	facing_left = direction < 0.0
	if sprite != null:
		sprite.flip_h = not facing_left

func _set_state(state: StringName) -> void:
	set_meta("ai_state", state)
	if sprite == null:
		return
	if sprite.animation != state:
		sprite.play(state)
