extends Control

const GAME_SCENE := "res://main.tscn"
var starting := false
# Loaded on entry; injectable before ready for isolated scene tests.
var high_score_store
var high_score_records: Array = []

@onready var start_button: Button = $Center/Lines/Menu/Start
@onready var high_scores_button: Button = $Center/Lines/Menu/HighScores
@onready var board_view: Control = $BoardView
@onready var back_button: Button = $BoardView/Lines/Back

func _ready() -> void:
	if high_score_store == null:
		high_score_store = preload("res://high_score_store.gd").new()
	high_score_records = high_score_store.records()
	start_button.pressed.connect(start_game)
	high_scores_button.pressed.connect(show_high_scores)
	back_button.pressed.connect(hide_high_scores)
	# Keyboard and gamepad players need a focused button to start from.
	start_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	# Escape / gamepad B is the second way back from the board.
	if board_view.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_high_scores()
		return
	# A mouse click on empty space drops focus, which would strand a keyboard or
	# gamepad player. Any navigation press then puts focus back on the menu.
	if get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_accept")
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		get_viewport().set_input_as_handled()
		(back_button if board_view.visible else start_button).grab_focus()

func show_high_scores() -> void:
	$BoardView/Lines/Board.show_records(high_score_records)
	$Center.hide()
	board_view.show()
	back_button.grab_focus()

func hide_high_scores() -> void:
	board_view.hide()
	$Center.show()
	# Return focus to the button that opened the board, so the menu reads in place.
	high_scores_button.grab_focus()

func start_game() -> void:
	# The scene swap happens at the end of the frame, so a second press in the
	# same frame (Enter and a click together) must not ask for it twice.
	if starting:
		return
	starting = true
	# Buttons fire on release, so this press has already stopped being "just
	# pressed" and the new ball can't see it as a launch.
	get_tree().change_scene_to_file(GAME_SCENE)
