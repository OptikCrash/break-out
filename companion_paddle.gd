extends "res://paddle.gd"

const Rules = preload("res://effect_rules.gd")
signal destroyed
var main_paddle: Node2D
var health := 0
var offset := Vector2.ZERO
var follow_speed := 0.0

# Reuse the paddle shape and bounce contract, without reading player input.
func _input(_event: InputEvent) -> void:
	pass

func _physics_process(delta: float) -> void:
	var target := main_paddle.global_position + offset
	global_position.x = Rules.companion_follow_x(global_position.x, target.x, follow_speed, delta)
	global_position.y = target.y

func take_hit() -> void:
	if is_queued_for_deletion():
		return
	health = Rules.companion_health_after_hit(health)
	if health == 0:
		queue_free()
		destroyed.emit()
