extends SceneTree

const Rules = preload("res://ball_rules.gd")
const BOUNCE_STEP := 0.02
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(Rules.boosted_total(0.0, 800.0) == 200.0, "Velocity weighting is 25 percent")
	_check(Rules.boosted_total(200.0, -800.0) == 400.0, "Both directions add")
	_check(Rules.boosted_total(400.0, 10000.0) == 550.0, "Boost cap is 550")
	_check(Rules.BOOST_DURATION == 3.0, "Full fade is three seconds")
	_check(Rules.tick_boost(200.0, 100.0, 3.0) == 0.0, "Decay cannot go negative")
	var paddle = preload("res://paddle.tscn").instantiate()
	root.add_child(paddle)
	paddle.set_physics_process(false)
	paddle.position = Vector2(960, 900)
	var ball = preload("res://ball.tscn").instantiate()
	ball.paddle = paddle
	root.add_child(ball)
	ball.set_physics_process(false)
	ball.launched = true
	await physics_frame
	await process_frame
	paddle.recent_velocity_x = 800.0
	await _bounce(ball, paddle)
	_check(is_equal_approx(ball.boost, 200.0) and is_equal_approx(ball.velocity.length(), 750.0), "Real moving-paddle hit adds 200 speed")
	var direction: Vector2 = ball.velocity.normalized()
	_check(direction.is_equal_approx(Rules.paddle_direction(0.5)), "Boost leaves contact angle unchanged")
	ball.tick_boost(1.5)
	_check(is_equal_approx(ball.boost, 100.0), "Half-duration linear fade")
	await _bounce(ball, paddle)
	var stacked_boost := 100.0 - (200.0 / 3.0) * BOUNCE_STEP + 200.0
	_check(is_equal_approx(ball.boost, stacked_boost) and ball.boost_time_left == 3.0, "Second hit adds after step decay and restarts full clock")
	ball.set_speed_multiplier(0.75)
	_check(is_equal_approx(ball.velocity.length(), 412.5 + stacked_boost), "Slow scales base only")
	ball.set_speed_multiplier(1.5)
	_check(is_equal_approx(ball.velocity.length(), 825.0 + stacked_boost), "Speed-up scales base only")
	ball.tick_boost(1.0)
	var expected_rate := stacked_boost / 3.0
	var expected_boost := stacked_boost - expected_rate * (1.0 + BOUNCE_STEP)
	paddle.recent_velocity_x = 0.0
	await _bounce(ball, paddle)
	_check(ball.velocity.y < 0.0, "Stationary paddle collision actually bounces")
	_check(is_equal_approx(ball.boost, expected_boost), "Stationary hit only applies normal step decay")
	_check(is_equal_approx(ball.boost_time_left, 2.0 - BOUNCE_STEP), "Stationary hit does not restart clock")
	_check(is_equal_approx(ball.boost_decay_rate, expected_rate), "Stationary hit preserves decay rate")
	_check(is_equal_approx(ball.velocity.length(), 825.0 + expected_boost), "Stationary bounce retains multiplied base plus decayed boost")
	ball.tick_boost(2.0)
	_check(ball.boost == 0.0 and is_equal_approx(ball.velocity.length(), 825.0), "Full fade restores multiplied base")
	ball.tick_boost(10.0)
	ball.set_speed_multiplier(1.0)
	_check(is_equal_approx(ball.velocity.length(), 550.0), "No boost cannot lower base")
	ball.sticky_active = true
	paddle.recent_velocity_x = 800.0
	await _bounce(ball, paddle)
	_check(ball.caught and ball.boost == 0.0, "Sticky catch adds no boost")
	ball.release_catch()
	ball.apply_paddle_boost(800.0)
	ball.catch_on_paddle(0.5)
	ball.set_speed_multiplier(0.75)
	ball.tick_boost(3.0)
	_check(is_equal_approx(ball.caught_speed, 412.5), "Caught boost fades and multiplier affects base only")
	ball.release_catch()
	ball.apply_paddle_boost(10000.0)
	_check(ball.boost == 550.0, "Ball accumulator clamps to cap")
	ball.tick_boost(1.0)
	ball.apply_paddle_boost(10000.0)
	_check(ball.boost == 550.0 and ball.boost_time_left == 3.0, "Capped hit restarts full fade")
	ball.reset()
	_check(ball.boost == 0.0 and not ball.boost_active, "Reset clears boost")
	ball.free()
	paddle.free()
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.paddle.set_physics_process(false)
	var source = game.ball
	source.set_physics_process(false)
	source.launched = true
	source.velocity = Vector2.UP * 550.0
	source.apply_paddle_boost(800.0)
	source.tick_boost(1.0)
	game._add_split_balls(source, preload("res://effects/multi_ball.tres"), game.split_generation)
	for copy in game.get_balls():
		copy.set_physics_process(false)
		_check(is_equal_approx(copy.boost, 200.0 * 2.0 / 3.0) and copy.boost_time_left == 2.0, "Multi-ball inherits bonus and remaining fade")
		_check(is_equal_approx(copy.boost_decay_rate, 200.0 / 3.0), "Multi-ball inherits original fade rate")
		copy.tick_boost(2.0)
		_check(copy.boost == 0.0 and is_equal_approx(copy.velocity.length(), 550.0), "Copied boost cannot become permanent")
	game.free()
	quit(1 if failures else 0)

func _bounce(ball, paddle) -> void:
	ball.position = paddle.position + Vector2(32, -30)
	ball.velocity = Vector2.DOWN * (ball.speed * ball.speed_multiplier + ball.boost)
	await physics_frame
	await process_frame
	ball._physics_process(BOUNCE_STEP)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
