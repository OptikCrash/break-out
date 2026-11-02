extends SceneTree

var failures := 0

func _initialize() -> void:
	var ball = preload("res://ball.gd").new()
	var paddle := Node2D.new()
	ball.paddle = paddle
	# No tree or physics ticks: reset must place the ball synchronously.
	for paddle_position in [Vector2(576, 900), Vector2(800, 850)]:
		paddle.position = paddle_position
		ball.position = Vector2(300, 200)
		ball.launched = true
		ball.reset()
		_check(not ball.launched, "Reset clears the launch flag")
		_check(ball.position == paddle_position + Vector2(0, -24), "Reset rests 24 pixels above the current paddle position")
		ball.reset()
		_check(ball.position == paddle_position + Vector2(0, -24), "Repeated reset keeps the same resting position")
	ball.free()
	paddle.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
