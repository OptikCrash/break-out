extends CharacterBody2D

const BrickDamage = preload("res://brick_damage.gd")
signal brick_broken(points: int)
var speed: float = preload("res://effects/blaster.tres").bolt_speed

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	# Sweep instead of overlap detection so fast bolts cannot skip thin bricks.
	var collision := move_and_collide(Vector2.UP * speed * delta)
	if collision:
		var hit := collision.get_collider()
		if hit.is_in_group("brick"):
			BrickDamage.hit(hit, true, brick_broken.emit)
		queue_free()
	elif position.y < 0.0:
		queue_free()
