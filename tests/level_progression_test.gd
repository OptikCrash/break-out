extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1920, 1080)
	for input_kind in ["keyboard", "mouse", "gamepad"]:
		var game = preload("res://main.tscn").instantiate()
		root.add_child(game)
		game.lives = 2
		var total := 0
		for index in game.levels.size():
			_check(game.current_level_index == index, "Sequence index advances once")
			_check(game.get_node("Hud/Level").text == "Level: %d" % (index + 1), "HUD follows sequence")
			_check(game.bricks.level == game.levels[index], "Loader uses sequence resource")
			game.paddle.position.x = 700
			game.ball.launched = true
			for brick in game.bricks.get_children():
				if brick.definition.destructible:
					total += brick.definition.points
					while not brick.is_queued_for_deletion():
						game.ball._break_brick(brick)
			_check(game.score == total and game.lives == 2, "Clearing keeps score and lives")
			_check(not game.ball.launched and not game.ball.is_physics_processing(), "Splash stops ball immediately")
			if index == game.levels.size() - 1:
				_check(game.reset_ready and not game.level_complete, "Final level ends the game")
				_check(game.get_node("Hud/MessageLabel").text == "You Win!", "Final level keeps win message")
				_check(game.get_node("Hud/EndButtons").visible and not game.get_node("Hud/Continue").visible, "Final level offers end buttons")
				break
			_check(game.get_node("Hud/MessageLabel").text == "Level %d Complete!" % (index + 1), "Splash names cleared level")
			await process_frame
			var event: InputEvent
			if input_kind == "mouse":
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.position = game.get_node("Hud/Continue").get_global_rect().get_center()
				click.global_position = click.position
				event = click
			elif input_kind == "gamepad":
				var button := InputEventJoypadButton.new()
				button.button_index = JOY_BUTTON_A
				event = button
			else:
				var key := InputEventKey.new()
				key.keycode = KEY_SPACE
				key.physical_keycode = KEY_SPACE
				event = key
			event.pressed = true
			Input.parse_input_event(event)
			await physics_frame
			event.pressed = false
			Input.parse_input_event(event)
			await physics_frame
			await physics_frame
			_check(not game.ball.launched, "Continue input must not launch the next ball")
			_check(game.paddle.position == game.paddle_start, "Continue resets paddle")
			_check(game.ball.position == game.paddle.position + Vector2(0, -24), "Continue rests ball on paddle")
			_check(game.lives == 2 and game.score == total, "Continue preserves lives and score")
		game.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
