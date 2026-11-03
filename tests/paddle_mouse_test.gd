extends SceneTree

# Walls are 32 wide inside a 1152-wide PlayArea placed at x = 384; the paddle
# is 128 wide. So its centre can range from 384 + 32 + 64 to 384 + 1120 - 64.
const LEFT_LIMIT := 480.0
const RIGHT_LIMIT := 1440.0
var failures := 0
var paddle: Node2D
var ball: Node2D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	_check(_launch_has_left_click(), "The launch action must include a left mouse click")
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	paddle = current_scene.get_node("PlayArea/Paddle")
	ball = current_scene.get_node("PlayArea/Ball")

	# Headless windows start tiny; at 1920x1080 window and viewport pixels match.
	root.size = Vector2i(1920, 1080)
	await process_frame
	await _move_mouse(700.0)
	_check(absf(paddle.global_position.x - 700.0) < 1.0, "Paddle must follow the mouse")
	await _move_mouse(1900.0)
	_check(absf(paddle.global_position.x - RIGHT_LIMIT) < 1.0, "Right wall must stop the paddle")
	await _move_mouse(0.0)
	_check(absf(paddle.global_position.x - LEFT_LIMIT) < 1.0, "Left wall must stop the paddle")

	await _move_mouse(900.0)
	# Holding a move key takes over from the mouse, which has not moved since.
	Input.parse_input_event(_key(KEY_D, true))
	for i in 10:
		await physics_frame
	var after_key := paddle.global_position.x
	_check(after_key > 950.0, "Keyboard must move the paddle away from a still mouse")
	Input.parse_input_event(_key(KEY_D, false))
	for i in 3:
		await physics_frame
	var settled := paddle.global_position.x
	for i in 5:
		await physics_frame
	_check(absf(paddle.global_position.x - settled) < 0.01,
		"Releasing the key must not snap the paddle back to the mouse")
	await _move_mouse(800.0)
	_check(absf(paddle.global_position.x - 800.0) < 1.0, "Moving the mouse again must take back control")

	# Most recent input wins even while a key is still held: hold D, then move
	# the mouse before releasing it. The mouse must take over at once.
	Input.parse_input_event(_key(KEY_D, true))
	for i in 10:
		await physics_frame
	_check(paddle.global_position.x > 850.0, "A new key press must take control from the mouse")
	await _move_mouse(700.0)
	_check(absf(paddle.global_position.x - 700.0) < 1.0,
		"Moving the mouse while a key is held must take control")
	for i in 5:
		await physics_frame
	_check(absf(paddle.global_position.x - 700.0) < 1.0,
		"A key that is merely still held must not take control back")
	# A key-repeat echo is not a new press, so it must not take control back.
	var echo := _key(KEY_D, true)
	echo.echo = true
	Input.parse_input_event(echo)
	for i in 5:
		await physics_frame
	_check(absf(paddle.global_position.x - 700.0) < 1.0,
		"A key-repeat echo must not take control back")
	Input.parse_input_event(_key(KEY_D, false))
	await _move_mouse(800.0)

	# In a 1280x720 window the canvas is scaled down; the window's centre is
	# still the middle of the 1920-wide game.
	root.size = Vector2i(1280, 720)
	await process_frame
	await _move_mouse(640.0)
	_check(absf(paddle.global_position.x - 960.0) < 1.0, "Paddle must follow the mouse in a resized window")
	root.size = Vector2i(1920, 1080)
	await process_frame

	_check(not ball.launched, "Ball must wait on the paddle before a click")
	Input.parse_input_event(_click(true))
	await physics_frame
	await physics_frame
	_check(ball.launched, "A left click must launch the ball")
	Input.parse_input_event(_click(false))
	await physics_frame
	quit(1 if failures else 0)

func _launch_has_left_click() -> bool:
	for event in InputMap.action_get_events("launch"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			return true
	return false

func _move_mouse(x: float) -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(x, 540)
	event.global_position = event.position
	Input.parse_input_event(event)
	for i in 3:
		await physics_frame

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event

func _click(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(800, 540)
	event.global_position = event.position
	event.pressed = pressed
	return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
