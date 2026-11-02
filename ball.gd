extends CharacterBody2D

const BallRules = preload("res://ball_rules.gd")

@export var speed := 550.0
@export var paddle: Node2D
signal brick_broken
var launched := false

func _physics_process(delta: float) -> void:
	if not launched:
		_rest_on_paddle()
		if  Input.is_action_just_pressed("launch"):
			launched = true;
			# Mostly straight up, with a small random lean left or right.
			velocity = BallRules.launch_direction() * speed
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

			velocity = BallRules.paddle_direction(x_dir) * current_speed
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

func _rest_on_paddle() -> void:
	# Half the paddle's height (8) plus the ball's radius (16): resting on top, no gap.
	position = paddle.position + Vector2(0, -24)

func reset() -> void:
	launched = false
	# Winning stops physics, so placement cannot wait for the next physics tick.
	_rest_on_paddle()
