extends SceneTree

const FIELD = preload("res://effects/force_field.tres")
const SHRINK = preload("res://effects/shrink_paddle.tres")
const FAST = preload("res://effects/speed_up_ball.tres")
const WIDE = preload("res://effects/wide_paddle.tres")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.ball.set_physics_process(false)
	game.paddle.set_physics_process(false)
	var rows = game.hud.get_node("ActiveEffects/Rows")
	game._catch_capsule(FIELD)
	_check(game.force_field_charges == 3 and game.score == 25, "Field grants three charges and 25 points")
	_check(game.effects.active.is_empty(), "Field has no timer")
	var row = rows.get_node("force_field")
	_check(row.get_node("Name").text == "Force Field  3 charges", "HUD shows charges")
	game._physics_process(100.0)
	_check(game.force_field_charges == 3, "Elapsed time does not consume charges")
	for remaining in [2, 1, 0]:
		game._catch_capsule(SHRINK if remaining != 1 else FAST)
		_check(game.force_field_charges == remaining, "Hazard consumes one charge")
		_check(game.effects.active.is_empty() and game.score == 25, "Blocked hazards apply no effect or points")
		_check(game.paddle.get_node("CollisionShape2D").scale.x == 1.0, "Blocked shrink leaves width unchanged")
	_check(not rows.has_node("force_field"), "Spent field leaves HUD")
	game._catch_capsule(SHRINK)
	_check(game.effects.active.has(SHRINK.id) and game.score == 25, "Fourth hazard applies normally")
	game._clear_effects_and_capsules()
	game._catch_capsule(FIELD)
	game._catch_capsule(WIDE)
	_check(game.force_field_charges == 3 and game.effects.active.has(WIDE.id) and game.score == 75, "Power-up applies and scores without spending charge")
	game._catch_capsule(SHRINK)
	game._catch_capsule(FAST)
	_check(game.force_field_charges == 1, "Two hazards leave one charge")
	game._catch_capsule(FIELD)
	_check(game.force_field_charges == 3 and game.score == 100, "Repeat catch resets to three and scores")
	_check(rows.get_node("force_field").get_node("Name").text == "Force Field  3 charges", "HUD refreshes charges")
	var refreshed_row = rows.get_node("force_field")
	game._physics_process(1.0)
	_check(rows.get_node("force_field") == refreshed_row, "HUD retains charge row between updates")
	game._on_death_zone_body_entered(game.ball)
	_check(game.force_field_charges == 0 and not rows.has_node("force_field"), "Last-ball loss clears charges and HUD")
	game._catch_capsule(FIELD)
	for brick in game.bricks.get_children():
		brick.queue_free()
	game._on_ball_brick_broken(0)
	_check(game.force_field_charges == 0 and not rows.has_node("force_field"), "Level completion clears charges and HUD")
	game.free()
	await process_frame
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
