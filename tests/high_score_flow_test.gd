extends SceneTree

const Store = preload("res://high_score_store.gd")
const SAVE := "user://high_score_store_test/terminal.json"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://high_score_store_test")
	for winning in [false, true]:
		DirAccess.remove_absolute(SAVE)
		var store = Store.new(SAVE)
		store.submit("OLD", 100)
		var game = preload("res://main.tscn").instantiate()
		game.high_score_store = store
		root.add_child(game)
		game.score = 500
		if winning:
			game.current_level_index = game.levels.size() - 1
			var level := Level.new()
			level.grid = "#"
			game.bricks.load_level(level)
			game.ball._break_brick(game.bricks.get_child(0))
		else:
			game.lives = 1
			game._on_death_zone_body_entered(game.ball)
		var final_score: int = game.score
		_check(game.reset_ready and game.hud.is_entering_initials(), "Both terminal outcomes open entry")
		_check(not game.hud.get_node("EndButtons").visible, "Entry hides ordinary choices")
		_check(store.records().size() == 1, "Qualification does not save")
		game.restart()
		game.back_to_title()
		_check(game.reset_ready, "Scene navigation is blocked during entry")
		await process_frame
		for key in [_restart_key(), _restart_pad()]:
			key.pressed = true
			Input.parse_input_event(key)
			Input.flush_buffered_events()
			await process_frame
			_check(game.reset_ready and game.awaiting_initials, "R and Y cannot restart during entry")
			key.pressed = false
			Input.parse_input_event(key)
			Input.flush_buffered_events()
		for invalid in ["AB", "abcd", "abC", "A1C"]:
			game.hud.initials_confirmed.emit(invalid)
		_check(store.records().size() == 1 and game.awaiting_initials, "Invalid confirmations never save")
		game._lose_life()
		game._finish_level()
		game.hud.initials_confirmed.emit("NEW")
		game.hud.initials_confirmed.emit("DUP")
		game._finish_level()
		game._lose_life()
		_check(store.records().size() == 2, "Repeated terminal and confirmation signals save once")
		_check(store.records()[0] == {"initials": "NEW", "score": final_score}, "Save uses final score")
		var board = game.hud.get_node("HighScores/Center/BoardView")
		_check(board.visible and not game.hud.is_entering_initials(), "Confirmation opens complete board")
		_check(board.get_node("Board/Rows").get_child_count() == 2, "Board includes previous rows")
		_check(board.get_node("Board/Rows/Row1").get_meta("highlighted"), "Saved row is highlighted")
		_check(board.get_node("Buttons/Restart").has_focus(), "Normal choices return after confirmation")
		game.free()
		var title = preload("res://TitleScreen.tscn").instantiate()
		title.high_score_store = Store.new(SAVE)
		root.add_child(title)
		title.show_high_scores()
		_check(title.get_node("BoardView/Lines/Board/Rows").get_child_count() == 2, "Title loads persisted board")
		title.hide_high_scores()
		_check(title.high_scores_button.has_focus(), "Returning restores title navigation")
		title.free()
	# A rejected write leaves the board unchanged and still permits navigation.
	var failed_game = preload("res://main.tscn").instantiate()
	failed_game.high_score_store = Store.new("")
	root.add_child(failed_game)
	failed_game.lives = 1
	failed_game._on_death_zone_body_entered(failed_game.ball)
	failed_game.hud.initials_confirmed.emit("ERR")
	failed_game.hud.initials_confirmed.emit("DUP")
	_check(not failed_game.awaiting_initials and failed_game.reset_ready, "Write failure releases end choices")
	_check(failed_game.hud.get_node("HighScores/Center/BoardView/Board/Empty").visible,
		"Write failure shows unchanged empty board")
	failed_game.free()
	var lab = preload("res://devtools/test_lab.tscn").instantiate()
	root.add_child(lab)
	lab._lose_life()
	lab._finish_level()
	_check(lab.high_score_store == null, "Test Lab never loads the store")
	lab.free()
	DirAccess.remove_absolute(SAVE)
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		printerr("FAIL: ", message)
		failures += 1

func _restart_key() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.physical_keycode = KEY_R
	return key

func _restart_pad() -> InputEventJoypadButton:
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	return pad
