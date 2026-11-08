extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1920, 1080)
	# Exercise both fast headless frames and several physics steps per GUI frame.
	for frame_limit in [0, 10]:
		Engine.max_fps = frame_limit
		for input_kind in ["keyboard", "mouse", "gamepad"]:
			var game = preload("res://main.tscn").instantiate()
			game.high_score_store = preload("res://tests/helpers/non_qualifying_store.gd").new()
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
					# Resistant is optional and Breaker-only, so clearing skips it.
					if brick.definition.destructible and brick.definition.counts_for_completion:
						total += brick.definition.points
						for hit in brick.definition.hit_points:
							game.ball._break_brick(brick)
						_check(brick.is_queued_for_deletion(), "Clearing destroys each destructible brick")
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
				# GUI input needs a process frame; physics steps alone can share one.
				Input.flush_buffered_events()
				await physics_frame
				await process_frame
				event.pressed = false
				Input.parse_input_event(event)
				Input.flush_buffered_events()
				await physics_frame
				await process_frame
				await physics_frame
				_check(not game.ball.launched, "Continue input must not launch the next ball")
				_check(game.paddle.position == game.paddle_start, "Continue resets paddle")
				_check(game.ball.position == game.paddle.position + Vector2(0, -24), "Continue rests ball on paddle")
				_check(game.lives == 2 and game.score == total, "Continue preserves lives and score")
			game.free()
	Engine.max_fps = 0
	_test_custom_sequence()
	quit(1 if failures else 0)

func _test_custom_sequence() -> void:
	var first := Level.new()
	first.grid = "#o"
	var last := Level.new()
	last.grid = "ox"
	var game = preload("res://main.tscn").instantiate()
	game.high_score_store = preload("res://tests/helpers/non_qualifying_store.gd").new()
	game.levels.assign([first, last])
	# main owns the first level, so Bricks must not build a default layout first.
	var built := [0]
	game.get_node("PlayArea/Bricks").child_entered_tree.connect(func(_brick): built[0] += 1)
	root.add_child(game)
	_check(built[0] == 2, "First layout is built once, from main.levels[0]")
	_check(game.bricks.level == first and game.bricks_left == 1, "Custom first level loads and excludes Indestructible bricks")
	game.ball._break_brick(game.bricks.get_child(0))
	_check(game.level_complete and game.bricks_left == 0, "Surviving Indestructible brick does not block completion")
	# A collision callback can arrive after the last brick in the same frame.
	game._on_death_zone_body_entered(game.ball)
	game._on_ball_brick_broken(10)
	_check(game.lives == 3 and game.score == 10, "Splash ignores late death and score callbacks")
	game.continue_level()
	game.continue_level()
	_check(game.current_level_index == 1 and game.bricks.level == last, "Duplicate Continue advances only once")
	_check(game.bricks.get_child_count() == 2 and game.bricks_left == 1, "Same-frame replacement excludes detached old bricks")
	var reinforced = game.bricks.get_child(1)
	game.ball._break_brick(reinforced)
	_check(not game.reset_ready and game.score == 10, "Intermediate reinforced hit does not win or score")
	game.ball._break_brick(reinforced)
	_check(game.reset_ready and not game.level_complete and game.score == 30, "Custom final level wins with Indestructible brick remaining")
	game.continue_level()
	_check(game.current_level_index == 1, "Continue cannot advance beyond final level")
	game.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
