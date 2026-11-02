extends CharacterBody2D

@export var speed := 550.0
@export var paddle: Node2D
signal brick_broken
var launched := false

func _physics_process(delta: float) -> void:
	if not launched:
		var paddlePosition = paddle.position
		# Half the paddle's height (8) plus the ball's radius (16): resting on top, no gap.
		paddlePosition.y = paddlePosition.y - 24
		position = paddlePosition
		if  Input.is_action_just_pressed("launch"):
			launched = true;
			# Mostly straight up, with a small random lean left or right.
			velocity = Vector2(randf_range(-0.3, 0.3), -1).normalized() * speed
		return
		
	var collision := move_and_collide(velocity * delta)

	if collision:
		var hit := collision.get_collider()

		if hit.is_in_group("paddle"):
			var ball_x: float = collision.get_position().x
			# global_position: measured from the screen, like the collision point above.
			var paddle_x: float = hit.global_position.x

			var current_speed = velocity.length()

			var x_dir: float = (ball_x - paddle_x) / 64.0

			velocity = Vector2(x_dir, -1.0).normalized() * current_speed
		else:
			velocity = velocity.bounce(collision.get_normal())
			if hit.is_in_group("brick"):
				_break_brick(hit)

func _break_brick(brick: Node) -> void:
	# queue_free() leaves the collider alive until the frame ends.
	if brick.is_queued_for_deletion():
		return
	brick.queue_free()
	brick_broken.emit()

func reset() -> void:
	launched = false
