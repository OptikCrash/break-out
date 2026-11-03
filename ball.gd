extends CharacterBody2D

const BallRules = preload("res://ball_rules.gd")

@export var speed := 550.0
@export var paddle: Node2D
signal brick_broken(points: int)
var launched := false
var speed_multiplier := 1.0
var sticky_active := false
var caught := false
var catch_offset := 0.0
var caught_speed := 0.0
# One-use Multi-ball spread for copies created while caught.
var release_rotation := 0.0
# Each ball owns its independent duration.
var breaker_time_left := 0.0
var breaker_active: bool:
	get:
		return breaker_time_left > 0.0
	set(value):
		breaker_time_left = BallRules.BREAKER_DURATION if value else 0.0

func _physics_process(delta: float) -> void:
	breaker_time_left = BallRules.tick_breaker(breaker_time_left, delta)
	if caught:
		_rest_on_paddle()
		if Input.is_action_just_pressed("power_action"):
			release_catch()
		return
	if not launched:
		_rest_on_paddle()
		if  Input.is_action_just_pressed("launch"):
			launched = true;
			# Mostly straight up, with a small random lean left or right.
			velocity = BallRules.launch_direction() * speed * speed_multiplier
		return
		
	var collision := move_and_collide(velocity * delta)

	if collision:
		var hit := collision.get_collider()

		if hit.is_in_group("paddle"):
			var ball_x: float = collision.get_position().x
			# global_position: measured from the screen, like the collision point above.
			var paddle_x: float = hit.global_position.x

			var current_speed = velocity.length()

			var x_dir: float = (ball_x - paddle_x) / hit.half_width

			if sticky_active and not hit.is_in_group("companion"):
				catch_on_paddle(x_dir)
			else:
				velocity = BallRules.paddle_direction(x_dir) * current_speed
			if hit.is_in_group("companion"):
				hit.take_hit()
		else:
			_hit_surface(hit, collision.get_normal())

func _hit_surface(hit: Node, normal: Vector2) -> void:
	var passes_through := false
	if hit.is_in_group("brick"):
		# A queued brick can still collide in another physics step this frame.
		passes_through = breaker_active and hit.definition.requires_breaker
		_break_brick(hit)
	if not passes_through:
		velocity = velocity.bounce(normal)

func _break_brick(brick: Node) -> bool:
	if brick.take_hit(breaker_active):
		brick_broken.emit(brick.definition.points)
		return true
	return false

func _rest_on_paddle() -> void:
	# Half the paddle's height (8) plus the ball's radius (16): resting on top, no gap.
	position = paddle.position + Vector2(0, -24)

func reset() -> void:
	launched = false
	caught = false
	release_rotation = 0.0
	velocity = Vector2.ZERO
	# Winning stops physics, so placement cannot wait for the next physics tick.
	_rest_on_paddle()

func set_speed_multiplier(multiplier: float) -> void:
	# Scale the current velocity, preserving direction and any underlying speed changes.
	caught_speed *= multiplier / speed_multiplier
	velocity *= multiplier / speed_multiplier
	speed_multiplier = multiplier

func catch_on_paddle(offset: float) -> void:
	# Center visually, but preserve the contact point for the release angle.
	catch_offset = offset
	caught_speed = velocity.length()
	caught = true
	velocity = Vector2.ZERO
	_rest_on_paddle()

func release_catch() -> void:
	if not caught:
		return
	caught = false
	launched = true
	_rest_on_paddle()
	velocity = BallRules.sticky_release(catch_offset, caught_speed, paddle.recent_velocity_x).rotated(release_rotation)
	release_rotation = 0.0

func set_sticky_active(active: bool) -> void:
	sticky_active = active
	if not active:
		release_catch()
