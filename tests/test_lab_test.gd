extends SceneTree

const Effects = preload("res://effect_rules.gd")

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var lab = load("res://devtools/test_lab.tscn").instantiate()
	root.size = Vector2i(1920, 1080)
	root.add_child(lab)
	await process_frame
	_check(lab.has_node("PlayArea/Ball") and lab.has_node("PlayArea/Bricks") and lab.has_node("Hud"),
		"Test Lab inherits main.tscn's real gameplay nodes")
	_check(not lab.has_node("PauseScreen") and not lab.can_pause(), "Pause menu is unreachable")
	_check(lab.bricks.get_child_count() > 0, "Current level's bricks are loaded")

	var rows = lab.get_node("LabOverlay/EffectPanel/Margin/Content/Scroll/Rows")
	_check(rows.get_child_count() == Effects.DEFINITIONS.size(), "Every pool entry gets exactly one button")
	for effect in Effects.DEFINITIONS:
		var button := rows.get_node(String(effect.id)) as Button
		_check(button != null, "Pool entry has a button: " + effect.display_name)
		if button == null:
			continue
		_check(button.text == ("Hazard: " if effect.hazard else "") + effect.display_name,
			"Button uses the resource name and textual hazard distinction")
		_check(button.get_node("placeholder_swatch").color == (lab.hud.HAZARD_COLOR if effect.hazard else lab.hud.POWER_UP_COLOR),
			"Button uses the HUD palette")
		_check(button.focus_mode == Control.FOCUS_NONE, "Launch cannot activate a focused effect button")
		lab.reset_lab()
		var old_lives: int = lab.lives
		button.pressed.emit()
		# Timers are exact before the next physics tick; deferred bodies need a frame.
		if effect.duration > 0:
			_check(lab.effects.active[effect.id].remaining == effect.duration, "Real timer starts at its authored duration")
		_check(lab.lives == old_lives + effect.extra_lives, "Catch applies real life changes")
		await process_frame
		_check(lab.get_balls().size() == 1 + effect.extra_balls, "Catch creates real Multi-ball copies")
		_check(lab.satellite_orbs == effect.orbs, "Catch sets real waiting orbs")
		_check(lab.force_field_charges == effect.hazard_charges, "Catch sets real Force Field charges")
		_check(lab.companions.size() == effect.companion_count, "Catch creates real companions")
	lab.reset_lab()
	# Exercise GUI hit testing too, not only the connected pressed signals.
	var shield_button := rows.get_node("satellite_shield") as Button
	# The list scrolls below the level picker; bring the button into view as a player would.
	lab.get_node("LabOverlay/EffectPanel/Margin/Content/Scroll").ensure_control_visible(shield_button)
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = shield_button.get_global_rect().get_center()
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	_check(lab.satellite_orbs == 3, "Mouse click catches Satellite Shield through the panel")
	lab.reset_lab()
	rows.get_node("force_field").pressed.emit()
	rows.get_node("shrink_paddle").pressed.emit()
	_check(lab.force_field_charges == 2 and not lab.effects.active.has(&"shrink_paddle"),
		"Panel catches preserve real Force Field hazard gating")
	lab.reset_lab()
	# The logical canvas and gutter placement must survive window resizing.
	for window_size in [Vector2i(1920, 1080), Vector2i(960, 540)]:
		root.size = window_size
		await process_frame
		await process_frame
		var panel := lab.get_node("LabOverlay/EffectPanel") as Control
		_check(panel.get_global_rect().end.x < 384.0, "Panel stays outside the play area")
		_check(panel.get_global_rect().end.y <= lab.get_viewport().get_visible_rect().end.y,
			"Panel stays within the logical viewport after resize")
		for button in rows.get_children():
			_check(button.size.x >= button.get_minimum_size().x, "Effect labels fit their buttons")
	root.size = Vector2i(1920, 1080)

	var lives_before_losses: int = lab.lives
	# Infinite lives: every last-ball loss respawns a resting ball.
	for i in 5:
		lab.ball.launched = true
		lab._on_death_zone_body_entered(lab.ball)
	_check(lab.lives == lives_before_losses and not lab.reset_ready, "Losing the last ball never costs a life")
	_check(lab.get_balls().size() == 1 and not lab.ball.launched, "A lost ball respawns on the paddle")
	_check(lab.hud.get_node("MessageLabel").text == "", "No Game Over message")

	# Reset: extra balls go, effects/orbs/companions clear, bricks rebuild.
	var multi = Effects.DEFINITIONS.filter(func(e): return e.extra_balls > 0)[0]
	var shield = Effects.DEFINITIONS.filter(func(e): return e.orbs > 0)[0]
	var companion = Effects.DEFINITIONS.filter(func(e): return e.companion_count > 0)[0]
	lab.ball.launched = true
	lab.ball.velocity = Vector2(0, -300)
	lab._catch_capsule(Effects.DEFINITIONS[0])
	lab._catch_capsule(multi)
	lab._catch_capsule(shield)
	lab._catch_capsule(companion)
	await process_frame
	_check(lab.get_balls().size() == 3 and lab.companions.size() == 2 and lab.satellite_orbs > 0,
		"Setup: copies, companions and orbs exist")
	var full_count: int = lab.bricks.get_child_count()
	lab.bricks.get_child(0).take_hit()
	lab.paddle.position.x += 200.0
	var old_brick = lab.bricks.get_child(0)
	lab.get_node("LabOverlay/ResetButton").pressed.emit()
	_check(lab.get_balls().size() == 1 and not lab.ball.launched, "Reset leaves one ball resting")
	_check(lab.ball.position == lab.paddle_start + Vector2(0, -24), "Ball rests on the paddle at its start")
	_check(lab.effects.active.is_empty() and lab.satellite_orbs == 0 and lab.companions.is_empty(),
		"Reset clears effects, orbs and companions")
	_check(lab.bricks.get_child_count() == full_count and lab.bricks.get_child(0) != old_brick,
		"Reset rebuilds the current level's bricks")
	_check(lab.bricks_left > 0, "Completion count matches the rebuilt layout")

	# Reset before a queued Multi-ball split runs: the split must not land in the
	# fresh lab. No frame passes between the catch and the reset.
	lab.ball.launched = true
	lab.ball.velocity = Vector2(0, -300)
	lab._catch_capsule(multi)
	lab.reset_lab()
	await process_frame
	await process_frame
	_check(lab.get_balls().size() == 1 and not lab.ball.launched,
		"A split queued before Reset never spawns copies afterwards")

	# Clearing the level reloads it rather than ending the session.
	var final_level := Level.new()
	final_level.grid = "#"
	lab.levels.assign([final_level])
	lab.bricks.load_level(final_level)
	lab._count_completion_bricks()
	lab.ball.launched = true
	lab.ball._break_brick(lab.bricks.get_child(0))
	_check(not lab.reset_ready and not lab.level_complete, "Clearing the final level shows no end screen")
	_check(lab.hud.get_node("MessageLabel").text == "", "No You Win or Level Complete message")
	_check(lab.bricks.get_child_count() == 1 and lab.bricks_left == 1, "The cleared level is reloaded")
	_check(not lab.ball.launched and lab.ball.is_physics_processing(), "The ball is ready to launch again")
	lab.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
