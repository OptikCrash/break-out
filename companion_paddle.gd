extends "res://paddle.gd"

const Rules = preload("res://effect_rules.gd")
signal destroyed
var main_paddle: Node2D
var health := 0
var offset := Vector2.ZERO
var follow_speed := 0.0
# World-space inner wall edges, supplied by the owning gameplay scene.
var horizontal_bounds := Vector2(-INF, INF)
# Companions are half the main paddle's width. Set through set_width_multiplier()
# so the collider, sprite and half_width (used for bounces and clamping) stay in sync;
# the shared shape resource is scaled, never replaced.
const WIDTH_MULTIPLIER := 0.5

func _ready() -> void:
	set_width_multiplier(WIDTH_MULTIPLIER)

# Reuse the paddle shape and bounce contract, without reading player input.
func _input(_event: InputEvent) -> void:
	pass

func _physics_process(delta: float) -> void:
	if not is_instance_valid(main_paddle):
		return
	var target := main_paddle.global_position + offset
	global_position.x = Rules.companion_clamp_x(
		Rules.companion_follow_x(global_position.x, target.x, follow_speed, delta),
		horizontal_bounds, half_width)
	global_position.y = target.y

func take_hit() -> void:
	if is_queued_for_deletion():
		return
	health = Rules.companion_health_after_hit(health)
	if health == 0:
		queue_free()
		destroyed.emit()
