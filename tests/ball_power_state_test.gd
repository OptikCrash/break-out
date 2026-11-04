extends SceneTree

const Rules = preload("res://ball_rules.gd")
var failures := 0

func _initialize() -> void:
	var ball = preload("res://ball.gd").new()
	var paddle := Node2D.new()
	ball.paddle = paddle
	_check(not ball.breaker_active and ball.breaker_time_left == 0.0, "Breaker starts inactive")
	ball.breaker_active = true
	_check(ball.breaker_time_left == 10.0, "Breaker lasts exactly 10 seconds")
	ball._physics_process(2.5)
	_check(ball.breaker_active and ball.breaker_time_left == 7.5, "Resting balls tick their own timer")
	ball.breaker_active = true
	_check(ball.breaker_time_left == 10.0, "Reactivation refreshes to 10 seconds")
	ball._physics_process(10.0)
	_check(not ball.breaker_active and ball.breaker_time_left == 0.0, "Breaker expires at the exact boundary")
	_check(Rules.tick_breaker(0.5, 1.0) == 0.0, "Overshoot clamps to zero")
	ball.breaker_active = true
	ball.breaker_active = false
	_check(ball.breaker_time_left == 0.0, "Disabling clears the timer")
	ball.free()
	paddle.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
