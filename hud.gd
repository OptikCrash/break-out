extends CanvasLayer

# The HUD only reports which button was chosen; main.gd decides what that does.
signal restart_pressed
signal back_to_title_pressed

func _ready() -> void:
	$EndButtons/Restart.pressed.connect(restart_pressed.emit)
	$EndButtons/BackToTitle.pressed.connect(back_to_title_pressed.emit)

func update_lives(value: int) -> void:
	$Lives.text = "Lives: " + str(value)
	
func update_score(value: int) -> void:
	$Score.text = "Score: " + str(value)

func update_message(value: String) -> void:
	$MessageLabel.text = value

func show_end_buttons() -> void:
	$EndButtons.show()
	# Focus lets keyboard and gamepad use the buttons (arrows/D-pad to move,
	# Enter/Space/A to press) without touching the mouse.
	$EndButtons/Restart.grab_focus()
