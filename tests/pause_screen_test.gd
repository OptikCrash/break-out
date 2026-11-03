extends SceneTree

const GAME := "res://main.tscn"
const TITLE := "res://TitleScreen.tscn"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check_input_map()
	await check_bare_scene()
	await check_gating()
	await check_pause_freezes_play()
	await check_layout()
	await check_gamepad_and_tab()
	await check_key_repeat()
	# Resume: Escape again, keyboard on the focused button, mouse click.
	await check_resume(_key(KEY_ESCAPE))
	await check_resume(_key(KEY_ENTER))
	await check_resume(null)
	# Restart: arrow down once, then Enter or Space (Space is also launch), or a click.
	await check_leave("Restart", 1, _key(KEY_ENTER), GAME)
	await check_leave("Restart", 1, _key(KEY_SPACE), GAME)
	await check_leave("Restart", 1, null, GAME)
	await check_leave("BackToTitle", 2, _key(KEY_ENTER), TITLE)
	await check_leave("BackToTitle", 2, null, TITLE)
	quit(1 if failures else 0)

func check_gamepad_and_tab() -> void:
	var game := await _start_game()
	await _launch(game)
	await _tap(_joy(JOY_BUTTON_START))
	_check(paused and game.pause_screen.visible, "Gamepad Start must open pause")
	await _tap(_joy(JOY_BUTTON_DPAD_DOWN))
	_check(game.pause_screen.get_node("Center/Menu/Restart").has_focus(),
		"Gamepad d-pad must focus Restart")
	await _tap(_joy(JOY_BUTTON_A))
	for i in 4:
		await physics_frame
	_check(not paused and current_scene != game and current_scene.scene_file_path == GAME,
		"Gamepad A must restart and unpause")
	game = current_scene
	await _launch(game)
	await _tap(_joy(JOY_BUTTON_START))
	await _tap(_joy(JOY_BUTTON_START))
	_check(not paused and not game.pause_screen.visible, "Gamepad Start must resume")
	await _tap(_joy(JOY_BUTTON_START))
	await _tap(_joy(JOY_BUTTON_A))
	_check(not paused, "Gamepad A on Resume must unpause")
	await _tap(_joy(JOY_BUTTON_START))
	await _tap(_joy(JOY_BUTTON_B))
	_check(not paused, "Gamepad B must resume")
	await _tap(_joy(JOY_BUTTON_START))
	await _tap(_key(KEY_TAB))
	await _tap(_key(KEY_TAB))
	_check(game.pause_screen.get_node("Center/Menu/BackToTitle").has_focus(),
		"Tab must navigate to Back to Title")
	await _tap(_joy(JOY_BUTTON_A))
	for i in 4:
		await physics_frame
	_check(not paused and current_scene.scene_file_path == TITLE,
		"Gamepad A after Tab navigation must return to title and unpause")

func check_key_repeat() -> void:
	var game := await _start_game()
	await _launch(game)
	var repeat := _key(KEY_ESCAPE)
	repeat.echo = true
	Input.parse_input_event(repeat)
	await process_frame
	_check(not paused, "An Escape repeat must not open pause")
	await _tap(_key(KEY_ESCAPE))
	Input.parse_input_event(repeat)
	await process_frame
	_check(paused, "Holding Escape must not close pause")
	Input.parse_input_event(_release(_key(KEY_ESCAPE)))
	await _tap(_key(KEY_ESCAPE))
	_check(not paused, "A fresh Escape press must still resume")

func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event

func check_input_map() -> void:
	var escape := _key(KEY_ESCAPE)
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	_check(InputMap.has_action("pause"), "pause action must exist")
	_check(InputMap.event_is_action(escape, "pause"), "Escape must be bound to pause")
	_check(InputMap.event_is_action(start, "pause"), "Gamepad Start must be bound to pause")

func check_bare_scene() -> void:
	# The script and process mode live on PauseScreen.tscn's root, not on main.tscn's instance.
	var overlay = load("res://PauseScreen.tscn").instantiate()
	root.add_child(overlay)
	await process_frame
	_check(overlay.has_method("open"), "PauseScreen.tscn root must have pause_screen.gd")
	_check(overlay.process_mode == Node.PROCESS_MODE_ALWAYS, "PauseScreen must process while paused")
	_check(not overlay.visible, "PauseScreen must start hidden")
	overlay.free()

func check_gating() -> void:
	var game := await _start_game()
	await _tap(_key(KEY_ESCAPE))
	_check(not paused, "Pause must not open before the ball is launched")
	await _launch(game)
	game.reset_ready = true
	game.ball.set_physics_process(false)
	game.hud.update_message("Game Over!\nPress R to restart")
	await _tap(_key(KEY_ESCAPE))
	_check(not paused and not game.pause_screen.visible,
		"Pause must not open over the game-over/win message")

func check_pause_freezes_play() -> void:
	var game := await _start_game()
	await _launch(game)
	await _tap(_key(KEY_ESCAPE))
	_check(paused, "Escape during play must pause the tree")
	_check(game.pause_screen.visible, "Pausing must show the overlay")
	var resume: Button = game.pause_screen.get_node("Center/Menu/Resume")
	_check(resume.has_focus(), "Resume must have focus when the overlay opens")
	var ball_position: Vector2 = game.ball.position
	var paddle: Node2D = game.get_node("PlayArea/Paddle")
	var paddle_position := paddle.position
	Input.parse_input_event(_key(KEY_D))
	for i in 5:
		await physics_frame
	_check(game.ball.position == ball_position, "Ball must not move while paused")
	_check(paddle.position == paddle_position, "Paddle must not move while paused")
	Input.parse_input_event(_release(_key(KEY_D)))
	await _tap(_key(KEY_R))
	_check(current_scene == game, "R must not restart while paused")
	paused = false

func check_layout() -> void:
	var game := await _start_game()
	await _launch(game)
	await _tap(_key(KEY_ESCAPE))
	var menu: Control = game.pause_screen.get_node("Center/Menu")
	for viewport_size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport_size
		await process_frame
		var viewport_rect := root.get_visible_rect()
		_check(menu.get_global_rect().get_center().distance_to(viewport_rect.get_center()) < 1.0,
			"Pause menu must be centred at %s" % viewport_size)
		for item in menu.get_children():
			_check(viewport_rect.encloses(item.get_global_rect()),
				"%s must fit on screen at %s" % [item.name, viewport_size])
	root.size = Vector2i(1920, 1080)
	paused = false

# event == null means click the button instead.
func check_resume(event: InputEvent) -> void:
	var game := await _start_game()
	await _launch(game)
	await _tap(_key(KEY_ESCAPE))
	var label := event.as_text() if event else "Click"
	if event:
		await _tap(event)
	else:
		await _click(game.pause_screen.get_node("Center/Menu/Resume"))
	_check(not paused, "%s must resume the game" % label)
	_check(not game.pause_screen.visible, "%s must hide the overlay" % label)
	_check(current_scene == game, "%s must keep the same game going" % label)
	var ball_position: Vector2 = game.ball.position
	await physics_frame
	await physics_frame
	_check(game.ball.position != ball_position, "Ball must move again after %s" % label)

func check_leave(button_name: String, downs: int, event: InputEvent, target: String) -> void:
	var game := await _start_game()
	await _launch(game)
	await _tap(_key(KEY_ESCAPE))
	var label := "%s by %s" % [button_name, event.as_text() if event else "click"]
	if event:
		for i in downs:
			await _tap(_key(KEY_DOWN))
		var button: Button = game.pause_screen.get_node("Center/Menu/" + button_name)
		_check(button.has_focus(), "Arrow down x%d must focus %s" % [downs, button_name])
		await _tap(event)
	else:
		await _click(game.pause_screen.get_node("Center/Menu/" + button_name))
	for i in 4:
		await physics_frame
	_check(not paused, "%s must unpause" % label)
	var scene := current_scene
	_check(scene != null and scene != game and scene.scene_file_path == target,
		"%s must load %s" % [label, target])
	if scene and scene.scene_file_path == GAME and scene != game:
		_check(not scene.get_node("PlayArea/Ball").launched, "%s must not launch the new ball" % label)

func _start_game() -> Node:
	paused = false
	change_scene_to_file(GAME)
	await process_frame
	await process_frame
	return current_scene

func _launch(game: Node) -> void:
	await _tap(_key(KEY_SPACE))
	_check(game.ball.launched, "Space must launch the ball")

# Press and release with a physics step after each, like a real key tap.
func _tap(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await physics_frame
	await process_frame
	Input.parse_input_event(_release(event))
	await physics_frame
	await process_frame

func _click(button: Button) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button.get_global_rect().get_center()
	click.global_position = click.position
	click.pressed = true
	await _tap(click)

func _release(event: InputEvent) -> InputEvent:
	var release: InputEvent = event.duplicate()
	release.pressed = false
	return release

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
