extends SceneTree

const TITLE := "res://TitleScreen.tscn"
const GAME := "res://main.tscn"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await check_hidden_during_play()
	await check_layout()
	await check_win_shows_buttons()
	# Each way of choosing Restart must reload the game; Back to Title must leave it.
	await check_choice("R key", [_key(KEY_R)], GAME)
	await check_choice("Enter on Restart", [_key(KEY_ENTER)], GAME)
	await check_choice("Space on Restart", [_key(KEY_SPACE)], GAME)
	await check_choice("Gamepad A on Restart", [_joy(JOY_BUTTON_A)], GAME)
	await check_choice("Click on Restart", [_click_on("Restart")], GAME)
	await check_choice("Right then Enter", [_key(KEY_RIGHT), _key(KEY_ENTER)], TITLE)
	await check_choice("D-pad right then A", [_joy(JOY_BUTTON_DPAD_RIGHT), _joy(JOY_BUTTON_A)], TITLE)
	await check_choice("Click on Back to Title", [_click_on("BackToTitle")], TITLE)
	quit(1 if failures else 0)

func start_game() -> Node:
	change_scene_to_file(GAME)
	await process_frame
	await process_frame
	return current_scene

func lose(game: Node) -> void:
	game.lives = 1
	game._on_death_zone_body_entered(game.ball)
	await process_frame

func check_hidden_during_play() -> void:
	var game := await start_game()
	_check(not game.get_node("Hud/EndButtons").visible, "Buttons must stay hidden while playing")
	# R only restarts once the game has ended.
	await press(_key(KEY_R))
	_check(current_scene == game, "R must not restart during play")

func check_layout() -> void:
	var game := await start_game()
	await lose(game)
	var buttons: Control = game.get_node("Hud/EndButtons")
	var restart: Button = buttons.get_node("Restart")
	_check(buttons.visible, "Game Over must show the buttons")
	_check(restart.has_focus(), "Restart must have focus when the buttons appear")
	_check(game.get_node("Hud/MessageLabel").text == "Game Over!", "Game Over message must show")
	for viewport_size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport_size
		await process_frame
		var viewport_rect := root.get_visible_rect()
		var rect := buttons.get_global_rect()
		_check(absf(rect.get_center().x - viewport_rect.get_center().x) < 1.0,
			"Buttons must be centred horizontally at %s" % viewport_size)
		_check(rect.position.y > viewport_rect.get_center().y,
			"Buttons must sit below the centred message at %s" % viewport_size)
		for button in buttons.get_children():
			_check(viewport_rect.encloses(button.get_global_rect()),
				"%s must fit on screen at %s" % [button.name, viewport_size])
	root.size = Vector2i(1920, 1080)
	await process_frame

func check_win_shows_buttons() -> void:
	var game := await start_game()
	game.current_level_index = game.levels.size() - 1
	# Use a real final brick so completion exercises the live layout.
	var final_level := Level.new()
	final_level.grid = "#"
	game.bricks.load_level(final_level)
	game._count_destructible_bricks()
	game.ball._break_brick(game.bricks.get_child(0))
	await process_frame
	_check(game.get_node("Hud/EndButtons").visible, "Win must show the buttons")
	_check(game.get_node("Hud/EndButtons/Restart").has_focus(), "Win must focus Restart")

func check_choice(label: String, events: Array, expected: String) -> void:
	var game := await start_game()
	await lose(game)
	for event in events:
		await press(event.call() if event is Callable else event)
	for i in 3:
		await process_frame
	var scene := current_scene
	_check(scene != null and scene != game and scene.scene_file_path == expected,
		"%s must open %s" % [label, expected])
	if scene and scene.scene_file_path == GAME:
		_check(scene.lives == 3 and not scene.reset_ready, "%s must start a fresh game" % label)
		_check(not scene.get_node("Hud/EndButtons").visible, "%s must hide the buttons again" % label)
		await physics_frame
		await physics_frame
		# Space is also the launch key: restarting with it must not launch the ball.
		_check(not scene.get_node("PlayArea/Ball").launched, "%s must not launch the ball" % label)

func press(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await physics_frame
	var release: InputEvent = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await physics_frame

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event

func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event

# The click position is read when the test runs, after the game has ended.
func _click_on(button_name: String) -> Callable:
	return func() -> InputEventMouseButton:
		var button: Control = current_scene.get_node("Hud/EndButtons/" + button_name)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		event.pressed = true
		return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
