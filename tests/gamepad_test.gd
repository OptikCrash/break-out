extends SceneTree

# Plays the game with gamepad events only: move, launch, lose, restart.
# The end screen's d-pad/A navigation is covered in end_screen_test.gd and the
# title screen's A press in title_screen_test.gd.
const GAME := "res://main.tscn"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	check_bindings()
	await check_movement("Left stick left", _stick(-1.0), -1)
	await check_movement("Left stick right", _stick(1.0), 1)
	await check_movement("D-pad left", _joy(JOY_BUTTON_DPAD_LEFT), -1)
	await check_movement("D-pad right", _joy(JOY_BUTTON_DPAD_RIGHT), 1)
	await check_stick_deadzone()
	await check_launch()
	await check_restart()
	quit(1 if failures else 0)

# Each gameplay action keeps its keyboard keys and gains a gamepad input.
func check_bindings() -> void:
	var expected := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"launch": [KEY_SPACE],
		"restart": [KEY_R],
	}
	for action in expected:
		var keys: Array = []
		var has_pad := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append(event.physical_keycode)
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		for key in expected[action]:
			_check(key in keys, "%s must keep key %s" % [action, OS.get_keycode_string(key)])
		_check(has_pad, "%s must have a gamepad binding" % action)

func start_game() -> Node:
	change_scene_to_file(GAME)
	await process_frame
	await process_frame
	current_scene.high_score_store = preload("res://tests/helpers/non_qualifying_store.gd").new()
	return current_scene

func check_movement(label: String, event: InputEvent, sign_x: int) -> void:
	var game := await start_game()
	var paddle: Node2D = game.get_node("PlayArea/Paddle")
	# The merged mouse controller must hand control back to either pad input.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(700, 540)
	Input.parse_input_event(motion)
	await physics_frame
	await physics_frame
	_check(paddle.following_mouse, "Mouse motion must take control before the pad")
	var start_x := paddle.position.x
	Input.parse_input_event(event)
	for i in 5:
		await physics_frame
	var moved := paddle.position.x - start_x
	_check(signf(moved) == sign_x, "%s must move the paddle (moved %.1f)" % [label, moved])
	Input.parse_input_event(_released(event))
	await physics_frame
	await physics_frame
	var stopped_x := paddle.position.x
	await physics_frame
	_check(paddle.position.x == stopped_x, "%s released must stop the paddle" % label)

# A resting stick drifts a little; the 0.2 action deadzone must ignore that.
func check_stick_deadzone() -> void:
	var game := await start_game()
	var paddle: Node2D = game.get_node("PlayArea/Paddle")
	var start_x := paddle.position.x
	Input.parse_input_event(_stick(0.1))
	for i in 5:
		await physics_frame
	_check(paddle.position.x == start_x, "Stick drift inside the deadzone must not move the paddle")
	Input.parse_input_event(_stick(0.0))
	await physics_frame

func check_launch() -> void:
	var game := await start_game()
	var ball: Node2D = game.get_node("PlayArea/Ball")
	_check(not ball.launched, "Ball must wait on the paddle")
	await press(_joy(JOY_BUTTON_A))
	_check(ball.launched, "Gamepad A must launch the ball")

func check_restart() -> void:
	var game := await start_game()
	# Y only restarts once the game has ended, like R.
	await press(_joy(JOY_BUTTON_Y))
	_check(current_scene == game, "Gamepad Y must not restart during play")
	game.lives = 1
	game._on_death_zone_body_entered(game.ball)
	await process_frame
	await press(_joy(JOY_BUTTON_Y))
	for i in 3:
		await process_frame
	var scene := current_scene
	_check(scene != null and scene != game and scene.scene_file_path == GAME,
		"Gamepad Y on Game Over must restart the game")
	if scene and scene.scene_file_path == GAME:
		_check(scene.lives == 3, "Gamepad Y must start a fresh game")

func press(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await physics_frame
	Input.parse_input_event(_released(event))
	await physics_frame

func _released(event: InputEvent) -> InputEvent:
	var release: InputEvent = event.duplicate()
	if release is InputEventJoypadMotion:
		release.axis_value = 0.0
	else:
		release.pressed = false
	return release

func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event

func _stick(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
