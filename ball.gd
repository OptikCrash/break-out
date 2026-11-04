extends CharacterBody2D

const BrickDamage = preload("res://brick_damage.gd")
const BallRules = preload("res://ball_rules.gd")

@export var speed := 550.0
@export var paddle: Node2D
signal brick_broken(points: int)
signal sound_requested(cue: StringName)
var launched := false
var speed_multiplier := 1.0
var boost := 0.0
var boost_time_left := 0.0
var boost_decay_rate := 0.0
var boost_active: bool:
	get:
		return boost_time_left > 0.0
	set(value):
		if value:
			boost_time_left = BallRules.BOOST_DURATION
			boost_decay_rate = boost / BallRules.BOOST_DURATION
		else:
			_change_boost(0.0)
			boost_time_left = 0.0
			boost_decay_rate = 0.0
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
	tick_boost(delta)
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
		# Floating paddles can be hit from below: reflect away instead of
		# steering upward into the same surface again on the next step.
		if hit.is_in_group("companion") and collision.get_normal().y >= 0.0:
			_hit_surface(hit, collision.get_normal())
			return

		if hit.is_in_group("paddle"):
			sound_requested.emit(&"paddle_bounce")
			hit.play_feedback()
			var ball_x: float = collision.get_position().x
			# global_position: measured from the screen, like the collision point above.
			var paddle_x: float = hit.global_position.x

			var x_dir: float = (ball_x - paddle_x) / hit.half_width

			if sticky_active and not hit.is_in_group("companion"):
				catch_on_paddle(x_dir)
			else:
				apply_paddle_boost(hit.recent_velocity_x)
				velocity = BallRules.paddle_direction(x_dir) * velocity.length()
			if hit.is_in_group("companion"):
				hit.take_hit()
		else:
			_hit_surface(hit, collision.get_normal())

func _hit_surface(hit: Node, normal: Vector2) -> void:
	var passes_through := false
	var brick_broke := false
	if hit.is_in_group("brick"):
		# A queued brick can still collide in another physics step this frame.
		passes_through = breaker_active and hit.definition.requires_breaker
		brick_broke = _break_brick(hit)
	if not passes_through:
		# Destruction already requests brick_break through Bricks' signal.
		if not brick_broke:
			sound_requested.emit(&"paddle_bounce" if hit.is_in_group("paddle") else &"wall_bounce")
		velocity = velocity.bounce(normal)

func _break_brick(brick: Node) -> bool:
	return BrickDamage.hit(brick, breaker_active, brick_broken.emit)

func _rest_on_paddle() -> void:
	# Half the paddle's height (8) plus the ball's radius (16): resting on top, no gap.
	position = paddle.position + Vector2(0, -24)

func reset() -> void:
	boost_active = false
	launched = false
	caught = false
	release_rotation = 0.0
	velocity = Vector2.ZERO
	# Winning stops physics, so placement cannot wait for the next physics tick.
	_rest_on_paddle()

# Change magnitude only; the paddle contact still owns direction.
func _change_boost(total: float) -> void:
	var difference := total - boost
	if caught:
		caught_speed = maxf(0.0, caught_speed + difference)
	elif not velocity.is_zero_approx():
		velocity = velocity.normalized() * maxf(0.0, velocity.length() + difference)
	boost = total

func apply_paddle_boost(paddle_velocity: float) -> void:
	if paddle_velocity == 0.0:
		return
	_change_boost(BallRules.boosted_total(boost, paddle_velocity))
	boost_active = true

func tick_boost(delta: float) -> void:
	if not boost_active:
		return
	boost_time_left = maxf(0.0, boost_time_left - delta)
	_change_boost(BallRules.tick_boost(boost, boost_decay_rate, delta) if boost_time_left > 0.0 else 0.0)
	if boost_time_left == 0.0:
		boost_decay_rate = 0.0

func set_speed_multiplier(multiplier: float) -> void:
	# Remove the additive boost before scaling, then put it back unchanged.
	if caught:
		caught_speed = BallRules.changed_multiplier_speed(caught_speed, boost, speed_multiplier, multiplier)
	if not velocity.is_zero_approx():
		velocity = velocity.normalized() * BallRules.changed_multiplier_speed(velocity.length(), boost, speed_multiplier, multiplier)
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
