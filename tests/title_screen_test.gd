extends SceneTree

const TITLE := "res://TitleScreen.tscn"
const GAME := "res://main.tscn"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == TITLE,
		"run/main_scene must be the title screen")
	await check_layout()
	for event in [_key(KEY_SPACE), _key(KEY_ENTER), _joy(JOY_BUTTON_A), _click_on("Center/Lines/Menu/Start")]:
		await check_starts_game(event)
	await check_start_then_launch()
	await check_high_scores_navigation()
	await check_focus_recovers_after_stray_click()
	quit(1 if failures else 0)

func open_title() -> Node:
	change_scene_to_file(TITLE)
	await process_frame
	await process_frame
	return current_scene

func check_layout() -> void:
	var title := await open_title()
	_check(title.get_node("Center/Lines/Menu/Start").has_focus(), "Start must have focus on the title screen")
	_check(title.get_node("Center/Lines/Menu/HighScores").text == "High Scores", "Title must offer High Scores")
	var lines: Control = title.get_node("Center/Lines")
	# A full ten-row board must also fit, on top of the menu it replaces.
	title.high_score_records = _ten_records()
	title.show_high_scores()
	title.hide_high_scores()
	# The title is anchored, so it stays centred and on screen after a resize.
	for viewport_size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport_size
		await process_frame
		var viewport_rect := root.get_visible_rect()
		_check(lines.get_global_rect().get_center().distance_to(viewport_rect.get_center()) < 1.0,
			"Title text must be centred at %s" % viewport_size)
		for line in lines.get_children():
			_check(viewport_rect.encloses(line.get_global_rect()),
				"%s must fit on screen at %s" % [line.name, viewport_size])
		title.show_high_scores()
		await process_frame
		var board: Control = title.get_node("BoardView/Lines")
		_check(board.get_global_rect().get_center().distance_to(viewport_rect.get_center()) < 1.0,
			"High-score board must be centred at %s" % viewport_size)
		_check(viewport_rect.encloses(board.get_global_rect()),
			"A full high-score board must fit on screen at %s" % viewport_size)
		title.hide_high_scores()
	root.size = Vector2i(1920, 1080)
	title.high_score_records = []

func check_starts_game(event_or_maker: Variant) -> void:
	await open_title()
	var event: InputEvent = event_or_maker.call() if event_or_maker is Callable else event_or_maker
	await press(event)
	for i in 4:
		await physics_frame
	var scene := current_scene
	_check(scene != null and scene.scene_file_path == GAME, "%s must start the game" % event.as_text())
	if scene and scene.scene_file_path == GAME:
		# Space is also the launch key: starting the game must not launch the ball too.
		_check(not scene.get_node("PlayArea/Ball").launched, "%s must not launch the ball" % event.as_text())

# Start fires on release, so the press that started the game is spent; the
# next real press in the game must still launch the ball.
func check_start_then_launch() -> void:
	await open_title()
	await press(_key(KEY_SPACE))
	for i in 4:
		await physics_frame
	var scene := current_scene
	_check(scene != null and scene.scene_file_path == GAME, "Space on Start must start the game")
	if scene == null or scene.scene_file_path != GAME:
		return
	var ball = scene.get_node("PlayArea/Ball")
	_check(not ball.launched, "Starting with Space must not launch the ball")
	Input.parse_input_event(_key(KEY_SPACE))
	await physics_frame
	await physics_frame
	_check(ball.launched, "A new Space press in the game must launch the ball")
	Input.parse_input_event(_released(_key(KEY_SPACE)))
	await physics_frame

# Every input path reaches the board and comes back with focus on High Scores.
func check_high_scores_navigation() -> void:
	var ways := [
		["Keyboard", [_key(KEY_DOWN), _key(KEY_ENTER)], [_key(KEY_ESCAPE)]],
		["Gamepad", [_joy(JOY_BUTTON_DPAD_DOWN), _joy(JOY_BUTTON_A)], [_joy(JOY_BUTTON_B)]],
		["Gamepad Back button", [_joy(JOY_BUTTON_DPAD_DOWN), _joy(JOY_BUTTON_A)], [_joy(JOY_BUTTON_A)]],
		["Mouse", [_click_on("Center/Lines/Menu/HighScores")], [_click_on("BoardView/Lines/Back")]],
	]
	for way in ways:
		var title := await open_title()
		for event in way[1]:
			await press(event.call() if event is Callable else event)
		var board_view: Control = title.get_node("BoardView")
		_check(board_view.visible and not title.get_node("Center").visible, "%s must open the board" % way[0])
		_check(title.get_node("BoardView/Lines/Back").has_focus(), "%s: Back must have focus on the board" % way[0])
		# No saved board is read here, so the empty state must show.
		_check(title.get_node("BoardView/Lines/Board/Empty").visible, "%s: an empty board must say so" % way[0])
		for event in way[2]:
			await press(event.call() if event is Callable else event)
		_check(not board_view.visible and title.get_node("Center").visible, "%s must return to the menu" % way[0])
		_check(title.get_node("Center/Lines/Menu/HighScores").has_focus(),
			"%s: focus must return to High Scores" % way[0])
		_check(current_scene == title, "%s must stay on the title screen" % way[0])

func check_focus_recovers_after_stray_click() -> void:
	var title := await open_title()
	var stray := _click_at(Vector2(100, 100))
	await press(stray)
	root.gui_release_focus()
	await press(_key(KEY_DOWN))
	var owner := root.gui_get_focus_owner()
	_check(owner != null and title.is_ancestor_of(owner), "A menu key must bring focus back after a stray click")
	_check(current_scene == title, "A stray click must not start the game")

# Buffered input is flushed and a GUI frame passes between press and release,
# so a slow runner can't merge the press into the release.
func press(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await physics_frame
	Input.parse_input_event(_released(event))
	Input.flush_buffered_events()
	await process_frame
	await physics_frame

func _released(event: InputEvent) -> InputEvent:
	var release: InputEvent = event.duplicate()
	release.pressed = false
	return release

func _ten_records() -> Array:
	var records := []
	for i in 10:
		records.append({"initials": "WWW", "score": 9999999 - i})
	return records

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event

# project.godot adds pad A to ui_accept and pad B to ui_cancel.
func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event

# The click position is read when the test runs, once the button is laid out.
func _click_on(path: String) -> Callable:
	return func() -> InputEventMouseButton:
		return _click_at((current_scene.get_node(path) as Control).get_global_rect().get_center())

func _click_at(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = true
	return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
