extends CharacterBody2D

@export var speed : = 1000.0

var half_width := 64.0

func set_width_multiplier(multiplier: float) -> void:
	half_width = 64.0 * multiplier
	$CollisionShape2D.scale.x = multiplier
	$Sprite2D.scale.x = multiplier

# Whichever input was used last is in charge: a mouse move hands control to
# the mouse, a fresh move action hands it back to the keyboard or gamepad. Both are
# decided from input events, not from what is held down, so moving the mouse
# while a key is still held gives the mouse control.
var following_mouse := false
var mouse_x := 0.0

# _input rather than _unhandled_input: the play field's ColorRects are
# Controls, and the GUI would mark mouse motion over them as handled.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		following_mouse = true
		# Event positions are in viewport pixels; turn them into world space.
		mouse_x = (get_canvas_transform().affine_inverse() * event.position).x
	# is_action_pressed skips key-repeat echoes, so only a real press counts.
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		following_mouse = false

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if following_mouse:
		# Exactly the speed that reaches the mouse this step. Moving through
		# move_and_slide (not setting position) lets the walls stop the paddle.
		velocity.x = (mouse_x - global_position.x) / delta
	elif direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
