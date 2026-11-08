extends SceneTree

var failures := 0

func _initialize() -> void:
	var paddle := Node2D.new()
	paddle.position = Vector2(960, 900)
	root.add_child(paddle)
	var ball = preload("res://ball.tscn").instantiate()
	ball.paddle = paddle
	root.add_child(ball)
	var sprite: AnimatedSprite2D = ball.get_node("Sprite2D")
	ball.reset()
	_check(not sprite.is_playing(), "Ball resting on the paddle does not roll")
	ball.launched = true
	ball.velocity = Vector2(0, -550)
	await physics_frame
	await physics_frame
	_check(sprite.is_playing(), "Launched ball rolls")
	ball.catch_on_paddle(0.0)
	await physics_frame
	await physics_frame
	_check(not sprite.is_playing(), "Sticky-caught ball does not roll")
	ball.reset()
	_check(not sprite.is_playing(), "Reset stops rolling synchronously")
	ball.free()
	paddle.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
