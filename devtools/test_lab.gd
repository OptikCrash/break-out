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
	_build_effect_buttons()

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

# Use the capsule pool itself so new gameplay effects appear here automatically.
func _build_effect_buttons() -> void:
	var rows := $LabOverlay/EffectPanel/Margin/Content/Scroll/Rows
	for effect in EffectRules.DEFINITIONS:
		var button := Button.new()
		button.name = String(effect.id)
		button.text = ("Hazard: " if effect.hazard else "") + effect.display_name
		button.tooltip_text = "Catch %s through the gameplay capsule path." % effect.display_name
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 48.0
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", Color.WHITE)
		var swatch := ColorRect.new()
		swatch.name = "placeholder_swatch"
		swatch.color = hud.HAZARD_COLOR if effect.hazard else hud.POWER_UP_COLOR
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		swatch.offset_right = 6.0
		button.add_child(swatch)
		# No falling capsule or alternate effect implementation in the lab.
		button.pressed.connect(_catch_capsule.bind(effect))
		rows.add_child(button)
