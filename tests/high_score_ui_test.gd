extends SceneTree

# M8 presentation only: the board, the initials panel and the HUD calls a
# caller uses to drive them. Records are built here; no saved board is read.

const UI_SCRIPTS := ["res://high_score_board.gd", "res://initials_entry.gd", "res://hud.gd", "res://title.gd"]
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	check_scripts_on_scene_roots()
	check_ui_owns_no_persistence()
	await check_board()
	await check_entry_typing()
	await check_entry_gamepad()
	await check_entry_mouse()
	await check_hud_flow()
	await check_hud_layout()
	quit(1 if failures else 0)

# Each scene carries its own script, so a bare instantiate() works anywhere.
func check_scripts_on_scene_roots() -> void:
	for pair in [["res://high_score_board.tscn", "res://high_score_board.gd"],
			["res://initials_entry.tscn", "res://initials_entry.gd"]]:
		var node: Node = load(pair[0]).instantiate()
		_check(node.get_script() != null and node.get_script().resource_path == pair[1],
			"%s root must carry %s" % pair)
		node.free()
	for scene_path in ["res://HUD.tscn", "res://TitleScreen.tscn"]:
		var state: SceneState = load(scene_path).get_state()
		for i in state.get_node_count():
			if state.get_node_instance(i) == null:
				continue
			for p in state.get_node_property_count(i):
				_check(state.get_node_property_name(i, p) != "script",
					"%s must not override the script on %s" % [scene_path, state.get_node_name(i)])

# Ranking and saving live in the rules/store, never in these scenes.
func check_ui_owns_no_persistence() -> void:
	for path in UI_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		for banned in ["user://", "FileAccess", "ConfigFile", "sort_custom"]:
			_check(not source.contains(banned), "%s must not use %s" % [path, banned])

func check_board() -> void:
	var board: Control = load("res://high_score_board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	_check(board.get_node("Title").text == "High Scores", "Board must be titled High Scores")
	_check(board.get_node("Empty").visible and board.get_node("Rows").get_child_count() == 0,
		"An empty board must show its empty state and no rows")
	var records := [
		{"initials": "AAA", "score": 900},
		{"initials": "BOB", "score": 500},
		{"initials": "ZED", "score": 500},
	]
	board.show_records(records, 1)
	var rows: Node = board.get_node("Rows")
	_check(not board.get_node("Empty").visible, "A board with rows must hide the empty state")
	_check(rows.get_child_count() == 3, "Board must draw one row per record, in the order given")
	for i in rows.get_child_count():
		var columns: Node = rows.get_child(i).get_node("Columns")
		# Only rank, initials and score: nothing else on a row.
		_check(columns.get_child_count() == 3, "Row %d must show exactly three columns" % (i + 1))
		_check(columns.get_node("Rank").text == "%d." % (i + 1), "Row %d rank" % (i + 1))
		_check(columns.get_node("Initials").text == records[i].initials, "Row %d initials" % (i + 1))
		_check(columns.get_node("Score").text == str(records[i].score), "Row %d score" % (i + 1))
		_check(rows.get_child(i).get_meta("highlighted") == (i == 1), "Only row 2 must be highlighted")
	var marked: StyleBoxFlat = rows.get_child(1).get_theme_stylebox("panel")
	var plain: StyleBoxFlat = rows.get_child(0).get_theme_stylebox("panel")
	_check(marked.bg_color.a > 0.5 and plain.bg_color.a == 0.0, "The highlighted row must be visibly filled")
	# Showing again replaces rows at once, with no highlight unless asked.
	board.show_records(records.slice(0, 2))
	_check(rows.get_child_count() == 2, "Re-showing must replace the old rows immediately")
	_check(not rows.get_child(1).get_meta("highlighted"), "No row is highlighted by default")
	board.free()

func open_entry() -> Control:
	var entry: Control = load("res://initials_entry.tscn").instantiate()
	root.add_child(entry)
	await process_frame
	entry.open(1234)
	return entry

func check_entry_typing() -> void:
	var entry := await open_entry()
	var sent := []
	entry.confirmed.connect(func(initials: String) -> void: sent.append(initials))
	_check(entry.get_node("Title").text == "New High Score!", "Entry must say New High Score!")
	_check(entry.get_node("Score").text == "Score: 1234", "Entry must show the run's score")
	_check(entry.get_node("Letters").get_child_count() == 26, "Selector must offer exactly A-Z")
	_check(entry.get_node("Letters/A").has_focus(), "Opening the entry must focus A")
	_check(entry.get_node("Actions/Confirm").disabled, "Confirm must wait for three letters")
	# Digits and punctuation are not initials. (Space is ui_accept, so it presses the focused letter.)
	for keycode in [KEY_1, KEY_PERIOD, KEY_MINUS]:
		await press(_key(keycode))
	_check(entry.initials == "", "Only A-Z keys may enter initials")
	await press(_key(KEY_K))
	await press(_key(KEY_X))
	await press(_key(KEY_BACKSPACE))
	_check(entry.initials == "K", "Backspace must remove the last letter")
	for keycode in [KEY_A, KEY_Y, KEY_Z, KEY_Q]:
		await press(_key(keycode))
	_check(entry.initials == "KAY", "Entry must stop at exactly three letters")
	_check(_slot_text(entry) == "KAY", "Slots must show the chosen letters")
	_check(sent.is_empty(), "Three letters alone must not confirm")
	_check(entry.get_node("Actions/Confirm").has_focus(), "A full entry must move focus to Confirm")
	await press(_key(KEY_ENTER))
	_check(sent == ["KAY"], "Enter on Confirm must send the initials once")
	entry.confirm()
	await press(_key(KEY_BACKSPACE))
	_check(sent == ["KAY"] and entry.initials == "KAY", "A sent entry must not change or resend")
	entry.free()

func check_entry_gamepad() -> void:
	var entry := await open_entry()
	var sent := []
	entry.confirmed.connect(func(initials: String) -> void: sent.append(initials))
	# Grid focus follows positions: right from A is B, down from B is K (9 columns).
	await press(_joy(JOY_BUTTON_DPAD_RIGHT))
	await press(_joy(JOY_BUTTON_DPAD_DOWN))
	_check(entry.get_node("Letters/K").has_focus(), "D-pad must walk the letter grid")
	await press(_joy(JOY_BUTTON_A))
	await press(_joy(JOY_BUTTON_A))
	await press(_joy(JOY_BUTTON_B))
	_check(entry.initials == "K", "Pad A picks a letter and pad B deletes one")
	await press(_joy(JOY_BUTTON_A))
	await press(_joy(JOY_BUTTON_A))
	_check(entry.initials == "KKK" and _slot_text(entry) == "KKK", "Pad must fill all three slots")
	await press(_joy(JOY_BUTTON_A))
	_check(sent == ["KKK"], "Pad A on the focused Confirm must send the initials")
	entry.free()

func check_entry_mouse() -> void:
	var entry := await open_entry()
	var sent := []
	entry.confirmed.connect(func(initials: String) -> void: sent.append(initials))
	for letter in ["S", "A", "M"]:
		await press(_click_on(entry.get_node("Letters/" + letter)))
	await press(_click_on(entry.get_node("Actions/Delete")))
	await press(_click_on(entry.get_node("Letters/B")))
	_check(entry.initials == "SAB", "Clicks must pick and delete letters")
	await press(_click_on(entry.get_node("Actions/Confirm")))
	_check(sent == ["SAB"], "Clicking Confirm must send the initials")
	entry.free()

func check_hud_flow() -> void:
	var hud: CanvasLayer = load("res://HUD.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	var got := {"initials": [], "restart": 0, "title": 0}
	hud.initials_confirmed.connect(func(initials: String) -> void: got.initials.append(initials))
	hud.restart_pressed.connect(func() -> void: got.restart += 1)
	hud.back_to_title_pressed.connect(func() -> void: got.title += 1)
	_check(not hud.get_node("HighScores").visible, "High-score layer must start hidden")

	hud.update_message("Game Over!")
	hud.show_end_buttons()
	hud.show_initials_entry(4200)
	_check(hud.is_entering_initials(), "show_initials_entry must open the panel")
	_check(not hud.get_node("EndButtons").visible, "The entry panel replaces the end buttons")
	_check(not hud.get_node("MessageLabel").visible, "The message must not show through the panel")
	_check(hud.get_node("HighScores/Center/InitialsEntry/Letters/A").has_focus(), "Entry must take focus")
	for keycode in [KEY_C, KEY_A, KEY_T]:
		await press(_key(keycode))
	await press(_key(KEY_ENTER))
	_check(got.initials == ["CAT"], "HUD must forward confirmed initials")

	hud.hide_initials_entry()
	_check(not hud.is_entering_initials() and not hud.get_node("HighScores").visible,
		"hide_initials_entry must close the panel")
	_check(hud.get_node("MessageLabel").visible, "Closing the layer must bring the message back")

	hud.show_initials_entry(4200)
	hud.show_high_scores([{"initials": "CAT", "score": 4200}], 0)
	var board_view: Control = hud.get_node("HighScores/Center/BoardView")
	_check(board_view.visible and not hud.is_entering_initials(), "show_high_scores swaps the entry for the board")
	_check(board_view.get_node("Board/Rows/Row1").get_meta("highlighted"), "The caller's row must be highlighted")
	_check(board_view.get_node("Buttons/Restart").has_focus(), "The board must focus Restart")
	# Containers lay out at frame end; focus neighbours need real positions.
	await process_frame
	await press(_key(KEY_RIGHT))
	await press(_joy(JOY_BUTTON_A))
	_check(got.title == 1, "Back to Title on the board must emit back_to_title_pressed")
	await press(_click_on(board_view.get_node("Buttons/Restart")))
	_check(got.restart == 1, "Restart on the board must emit restart_pressed")
	hud.hide_high_scores()
	_check(not hud.get_node("HighScores").visible, "hide_high_scores must close the board")
	hud.free()

func check_hud_layout() -> void:
	var hud: CanvasLayer = load("res://HUD.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	var records := []
	for i in 10:
		records.append({"initials": "WWW", "score": 9999999 - i})
	var views := {
		"entry": func() -> void: hud.show_initials_entry(9999999),
		"board": func() -> void: hud.show_high_scores(records, 9),
	}
	for view in views:
		views[view].call()
		var panel: Control = hud.get_node("HighScores/Center/InitialsEntry" if view == "entry" else "HighScores/Center/BoardView")
		for viewport_size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
			root.size = viewport_size
			await process_frame
			var viewport_rect := root.get_visible_rect()
			_check(panel.get_global_rect().get_center().distance_to(viewport_rect.get_center()) < 1.0,
				"The %s must be centred at %s" % [view, viewport_size])
			_check(viewport_rect.encloses(panel.get_global_rect()),
				"The %s must fit on screen at %s" % [view, viewport_size])
	root.size = Vector2i(1920, 1080)
	hud.free()

func _slot_text(entry: Node) -> String:
	var text := ""
	for slot in entry.get_node("Slots").get_children():
		text += slot.text
	return text

# Flush and let a GUI frame pass between press and release (see AGENTS.md).
func press(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	var release: InputEvent = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame

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

func _click_on(control: Control) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.pressed = true
	return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
