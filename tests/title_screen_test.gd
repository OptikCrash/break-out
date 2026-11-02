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
	for event in [_key(KEY_SPACE), _key(KEY_ENTER), _click()]:
		await check_starts_game(event)
	await check_held_space_then_launch()
	quit(1 if failures else 0)

func check_layout() -> void:
	change_scene_to_file(TITLE)
	await process_frame
	await process_frame
	var lines: Control = current_scene.get_node("Center/Lines")
	# The title is anchored, so it stays centred and on screen after a resize.
	for viewport_size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport_size
		await process_frame
		var viewport_rect := root.get_visible_rect()
		_check(lines.get_global_rect().get_center().distance_to(viewport_rect.get_center()) < 1.0,
			"Title text must be centred at %s" % viewport_size)
		for label in lines.get_children():
			_check(viewport_rect.encloses(label.get_global_rect()),
				"%s must fit on screen at %s" % [label.name, viewport_size])
	root.size = Vector2i(1920, 1080)

func check_starts_game(event: InputEvent) -> void:
	change_scene_to_file(TITLE)
	await process_frame
	await process_frame
	Input.parse_input_event(event)
	var release: InputEvent = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	for i in 4:
		await physics_frame
	var scene := current_scene
	_check(scene != null and scene.scene_file_path == GAME, "%s must start the game" % event.as_text())
	if scene and scene.scene_file_path == GAME:
		# Space is also the launch key: starting the game must not launch the ball too.
		_check(not scene.get_node("PlayArea/Ball").launched, "%s must not launch the ball" % event.as_text())

# Holding Space through the scene change must not launch the ball, but the
# next real press in the game must still launch it.
func check_held_space_then_launch() -> void:
	change_scene_to_file(TITLE)
	await process_frame
	await process_frame
	Input.parse_input_event(_key(KEY_SPACE))
	for i in 4:
		await physics_frame
	var scene := current_scene
	_check(scene != null and scene.scene_file_path == GAME, "Held Space must start the game")
	if scene == null or scene.scene_file_path != GAME:
		return
	var ball = scene.get_node("PlayArea/Ball")
	_check(not ball.launched, "Holding Space into the game must not launch the ball")
	var release := _key(KEY_SPACE)
	release.pressed = false
	Input.parse_input_event(release)
	await physics_frame
	_check(not ball.launched, "Releasing Space must not launch the ball")
	Input.parse_input_event(_key(KEY_SPACE))
	await physics_frame
	await physics_frame
	_check(ball.launched, "A new Space press in the game must launch the ball")
	Input.parse_input_event(release)
	await physics_frame

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event

func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(960, 540)
	event.global_position = event.position
	event.pressed = true
	return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
