extends CanvasLayer

const TITLE_SCENE := "res://TitleScreen.tscn"
@onready var resume_button: Button = $Center/Menu/Resume

# PauseScreen.tscn sets process_mode = Always on this root (and so on every
# button under it), so the menu keeps reading input while the tree is paused.
func _ready() -> void:
	hide()

func open() -> void:
	get_tree().paused = true
	show()
	# Keyboard and gamepad players need a focused button to start navigating from.
	resume_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	# A hidden CanvasLayer still gets _unhandled_input, so check visibility first.
	if not visible:
		return
	# Escape/Start closes the menu again; ui_cancel (gamepad B) does the same.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	hide()

# paused belongs to the SceneTree, not the scene, so it would stay on after
# the swap. Buttons fire on release, so a Space press here can't reach the
# new ball as "launch" (tests/pause_screen_test.gd checks this).
func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_back_to_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
