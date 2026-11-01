extends CharacterBody2D

@export var speed := 400.0
@export var paddle: Node2D
signal brick_broken
var launched := false

func _physics_process(delta: float) -> void:
	if not launched:
		var paddlePosition = paddle.position
		paddlePosition.y = paddlePosition.y - 28
		position = paddlePosition
		if  Input.is_action_just_pressed("launch"):
			launched = true;
			velocity = Vector2(1, -1).normalized() * speed
		return
		
	var collision := move_and_collide(velocity * delta)

	if collision:
		var hit := collision.get_collider()

		if hit.is_in_group("paddle"):
			var ball_x: float = collision.get_position().x
			var paddle_x: float = hit.get_position().x

			var current_speed = velocity.length()

			var x_dir: float = (ball_x - paddle_x) / 80.0

			velocity = Vector2(x_dir, -1.0).normalized() * current_speed
		else:
			velocity = velocity.bounce(collision.get_normal())
			if hit.is_in_group("brick"):
				hit.queue_free()
				brick_broken.emit()

func reset() -> void:
	launched = false
