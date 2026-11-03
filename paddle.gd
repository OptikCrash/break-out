extends CharacterBody2D

@export var speed : = 1000.0

# Whichever input moved the paddle last is in charge: a mouse move hands
# control to the mouse, a held move key hands it back to the keyboard.
var following_mouse := false
var mouse_x := 0.0

# _input rather than _unhandled_input: the play field's ColorRects are
# Controls, and the GUI would mark mouse motion over them as handled.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		following_mouse = true
		# Event positions are in viewport pixels; turn them into world space.
		mouse_x = (get_canvas_transform().affine_inverse() * event.position).x

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		following_mouse = false

	if following_mouse:
		# Exactly the speed that reaches the mouse this step. Moving through
		# move_and_slide (not setting position) lets the walls stop the paddle.
		velocity.x = (mouse_x - global_position.x) / delta
	elif direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
