extends "res://main.gd"

# Development-only sandbox (see ADR-0002). test_lab.tscn inherits main.tscn,
# so this script only changes the session rules: everything else (loading,
# effects, scoring, capsules) is main.gd's real code. Open test_lab.tscn in
# the editor and press F6; no production scene links here.

func _ready() -> void:
	super._ready()
	# Inherited scenes can't delete inherited nodes, so drop the pause menu
	# here. can_pause() below stops main.gd from ever opening it.
	pause_screen.queue_free()
	pause_screen = null
	$LabOverlay/ResetButton.pressed.connect(reset_lab)

func can_pause() -> bool:
	return false

# Infinite lives: losing the last ball still clears effects (main.gd does that
# before calling this), but only spawns a fresh ball on the paddle.
func _lose_life() -> void:
	add_ball()

# Clearing a level reloads it rather than showing "Level Complete"/"You Win!".
func _finish_level() -> void:
	reset_lab()

# The HUD's end buttons are never shown here, but make sure they can't leave.
func restart() -> void:
	pass

func back_to_title() -> void:
	pass

# Back to a fresh start of the current level: one ball resting on the paddle,
# bricks rebuilt, and the same cleanup a lost life or level end uses.
func reset_lab() -> void:
	_clear_effects_and_capsules()
	var balls := get_balls()
	for extra in balls.slice(1):
		# Leave the group now, as the Death Zone does: deletion waits for frame end.
		extra.remove_from_group("ball")
		extra.queue_free()
	paddle.position = paddle_start
	paddle.velocity = Vector2.ZERO
	paddle.following_mouse = false
	paddle.set_physics_process(true)
	if balls.is_empty():
		add_ball()
	else:
		balls[0].reset()
		balls[0].set_physics_process(true)
	bricks.load_level(levels[current_level_index])
	_count_completion_bricks()
	hud.update_message("")
