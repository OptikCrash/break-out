extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.paddle.set_physics_process(false)
	game.ball.set_physics_process(false)
	# Synchronize the physics space before manually stepping a real paddle contact.
	await physics_frame
	game.ball.global_position = game.paddle.global_position + Vector2(32, -30)
	game.ball.launched = true
	game.ball.velocity = Vector2(0, 550)
	game.ball._physics_process(0.03)
	_check(game.ball.velocity.y < 0.0, "Real paddle contact bounces upward")
	_check(game.paddle.feedback_tween != null and game.paddle.feedback_tween.is_running(), "Ball bounce starts feedback")
	# Exercise the shared ball/bolt damage path, including duplicate hits before deletion.
	for symbol in ["#", "x", "?", "r"]:
		var brick = game.bricks.get_child(0)
		brick.configure(symbol)
		var at: Vector2 = brick.get_node("CollisionShape2D").global_position
		var points: int = brick.definition.points
		var before := get_nodes_in_group("point_popup").size()
		if symbol == "x":
			game.ball._break_brick(brick)
			_check(get_nodes_in_group("point_popup").size() == before, "Non-final hit has no popup")
		game.ball.breaker_time_left = 10.0
		game.ball._break_brick(brick)
		game.ball._break_brick(brick)
		_check_popup(before, str(points), at)
		await process_frame

	# Use actual capsule catch signals so the popup uses the capsule's current position.
	for effect in [preload("res://effects/wide_paddle.tres"), preload("res://effects/shrink_paddle.tres"), preload("res://effects/force_field.tres"), preload("res://effects/speed_up_ball.tres")]:
		game._add_capsule(Vector2(900, 700))
		var capsule = game.get_node("PlayArea").get_children().back()
		capsule.effect = effect
		capsule.set_physics_process(false)
		capsule.global_position = Vector2(910, 720)
		var before := get_nodes_in_group("point_popup").size()
		capsule._on_body_entered(game.paddle)
		capsule._on_body_entered(game.paddle)
		_check_popup(before, "+0" if effect.hazard else "+25", Vector2(910, 720))
		_check(game.paddle.feedback_tween.is_running(), "Capsule catch starts feedback")
		await process_frame

	var paddle = game.paddle
	paddle.play_feedback()
	await create_timer(0.06).timeout
	_check(paddle.feedback_scale != Vector2.ONE, "Feedback changes sprite scale")
	var shape_scale: Vector2 = paddle.get_node("CollisionShape2D").scale
	paddle.set_width_multiplier(1.5)
	paddle.play_feedback()
	await create_timer(0.3).timeout
	_check(paddle.get_node("Sprite2D").scale.is_equal_approx(Vector2(1.5, 0.53125)), "Repeated feedback returns to current width")
	_check(paddle.half_width == 96.0 and paddle.get_node("CollisionShape2D").scale == Vector2(1.5, shape_scale.y), "Feedback leaves bounce width and collider untouched")

	var popup = preload("res://floating_points.tscn").instantiate()
	root.add_child(popup)
	var initial_y: float = popup.get_node("Label").position.y
	await create_timer(0.2).timeout
	_check(popup.get_node("Label").position.y < initial_y and popup.modulate.a < 1.0, "Popup rises and fades")
	paused = true
	var alpha: float = popup.modulate.a
	await create_timer(0.1).timeout
	_check(is_equal_approx(popup.modulate.a, alpha), "Popup pauses with gameplay")
	paused = false
	await create_timer(1.0).timeout
	_check(not is_instance_valid(popup), "Popup frees after tween")
	game.free()
	await process_frame
	quit(1 if failures else 0)

func _check_popup(before: int, text: String, at: Vector2) -> void:
	var popups := get_nodes_in_group("point_popup")
	_check(popups.size() == before + 1, "Exactly one popup per event")
	if popups.size() > before:
		_check(popups.back().get_node("Label").text == text, "Popup shows point delta")
		_check(popups.back().global_position.is_equal_approx(at), "Popup uses event position")

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
