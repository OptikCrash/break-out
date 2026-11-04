extends Control

const GAME_SCENE := "res://main.tscn"
var starting := false

# _unhandled_input only sees events no Control consumed, so every node in
# TitleScreen.tscn has mouse_filter = Ignore to let clicks reach this script.
func _unhandled_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if event.is_action_pressed("ui_accept") or clicked:
		start_game()

func start_game() -> void:
	# The scene swap happens at the end of the frame, so a second press in the
	# same frame (Space and a click together) must not ask for it twice.
	if starting:
		return
	starting = true
	get_viewport().set_input_as_handled()
	# Space is also the "launch" action. Swapping scenes right away would let the
	# new ball see that same press as just pressed and launch at once. A press
	# counts as just pressed for the next physics step, so let that step pass here.
	await get_tree().physics_frame
	get_tree().change_scene_to_file(GAME_SCENE)
