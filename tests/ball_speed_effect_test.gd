extends SceneTree

const Rules = preload("res://effect_rules.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for effect in [Rules.DEFINITIONS[3], Rules.DEFINITIONS[4]]:
		var game = preload("res://main.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.paddle.set_physics_process(false)
		var first = game.ball
		var second = game.add_ball()
		first.set_physics_process(false)
		second.set_physics_process(false)
		first.launched = true
		second.launched = true
		first.velocity = Vector2(330, -440)
		second.velocity = Vector2(-600, -800)
		game._catch_capsule(effect)
		_check(first.velocity.is_equal_approx(Vector2(330, -440) * effect.ball_speed_multiplier), "Catch scales first ball and preserves direction")
		_check(second.velocity.is_equal_approx(Vector2(-600, -800) * effect.ball_speed_multiplier), "Catch scales second ball's distinct baseline")
		game._physics_process(6.0)
		game._catch_capsule(effect)
		_check(game.effects.active[effect.id].remaining == 10.0, "Re-catch refreshes full timer")
		_check(is_equal_approx(first.velocity.length(), 550.0 * effect.ball_speed_multiplier), "Re-catch does not stack speed")
		var later = game.add_ball()
		later.set_physics_process(false)
		_check(later.speed_multiplier == effect.ball_speed_multiplier, "New resting ball inherits effect")
		later.set_physics_process(true)
		Input.action_press("launch")
		await physics_frame
		await physics_frame
		later.set_physics_process(false)
		Input.action_release("launch")
		_check(later.launched and is_equal_approx(later.velocity.length(), 550.0 * effect.ball_speed_multiplier), "Later launch uses active speed")
		game._physics_process(9.0)
		_check(is_equal_approx(second.velocity.length(), 1000.0 * effect.ball_speed_multiplier), "Refreshed effect remains before expiry")
		game._physics_process(1.0)
		_check(first.velocity.is_equal_approx(Vector2(330, -440)), "Expiry restores first baseline")
		_check(second.velocity.is_equal_approx(Vector2(-600, -800)), "Expiry restores second baseline")
		_check(is_equal_approx(later.velocity.length(), 550.0), "Expiry restores later launch")
		game._catch_capsule(effect)
		game._on_death_zone_body_entered(second)
		_check(first.speed_multiplier == effect.ball_speed_multiplier, "Losing an earlier ball preserves effect")
		game._clear_effects_and_capsules()
		_check(first.velocity.is_equal_approx(Vector2(330, -440)) and first.speed_multiplier == 1.0, "Lifecycle clearing restores speed immediately")
		game.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
