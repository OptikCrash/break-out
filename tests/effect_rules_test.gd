extends SceneTree

const Rules = preload("res://effect_rules.gd")
var failures := 0

func _initialize() -> void:
	var expected := [
		[&"wide_paddle", false, 10.0, 1.5, 0, 25],
		[&"shrink_paddle", true, 10.0, 0.75, 0, 0],
		[&"extra_life", false, 0.0, 1.0, 1, 25],
		[&"slow_ball", false, 10.0, 1.0, 0, 25],
		[&"speed_up_ball", true, 10.0, 1.0, 0, 0],
		[&"multi_ball", false, 0.0, 1.0, 0, 25],
		[&"breaker", false, 10.0, 1.0, 0, 25],
		[&"sticky_paddle", false, 10.0, 1.0, 0, 25],
	]
	_check(Rules.DEFINITIONS.size() == expected.size(), "Pin pool size")
	var ids := []
	for i in Rules.DEFINITIONS.size():
		var effect = Rules.DEFINITIONS[i]
		_check(effect.validation_error().is_empty(), "Effect content validates")
		_check(not ids.has(effect.id), "Stable effect IDs are unique")
		ids.append(effect.id)
		_check([effect.id, effect.hazard, effect.duration, effect.paddle_width_multiplier, effect.extra_lives, Rules.catch_points(effect)] == expected[i], "Pin effect data and scoring")
	var invalid = Rules.DEFINITIONS[0].duplicate()
	invalid.id = &""
	_check(not invalid.validation_error().is_empty(), "Reject missing effect ID")
	invalid = Rules.DEFINITIONS[0].duplicate()
	invalid.duration = -1.0
	_check(not invalid.validation_error().is_empty(), "Reject negative duration")
	invalid.duration = 0.0
	_check(not invalid.validation_error().is_empty(), "Reject permanent width changes")
	invalid.duration = 10.0
	invalid.paddle_width_multiplier = 0.0
	_check(not invalid.validation_error().is_empty(), "Reject zero width")
	var rules = Rules.new()
	var wide = Rules.DEFINITIONS[0]
	var shrink = Rules.DEFINITIONS[1]
	rules.apply(wide)
	_check(rules.width_multiplier() == 1.5, "Wide multiplier")
	rules.advance(4.0)
	rules.apply(shrink)
	_check(rules.width_multiplier() == 1.125, "Different effects combine multiplicatively")
	rules.apply(wide)
	_check(rules.active[wide.id].remaining == 10.0 and rules.active.size() == 2, "Same effect refreshes without stacking")
	rules.advance(9.0)
	_check(rules.width_multiplier() == 1.125, "Effects remain before boundary")
	rules.advance(1.0)
	_check(rules.active.is_empty() and rules.width_multiplier() == 1.0, "Expire exactly at ten seconds")
	rules.apply(shrink)
	_check(rules.width_multiplier() == 0.75, "Shrink multiplier")
	rules.apply(Rules.DEFINITIONS[2])
	_check(rules.active.size() == 1, "Instant effect has no timer")
	rules.advance(100.0)
	_check(rules.active.is_empty(), "Oversized step expires cleanly")
	rules.apply(wide)
	rules.advance(5.0)
	rules.apply(shrink)
	rules.advance(5.0)
	_check(not rules.active.has(wide.id) and rules.active[shrink.id].remaining == 5.0, "Different timers expire independently")
	_check(rules.width_multiplier() == 0.75, "Expiring Wide leaves Shrink active")
	var multi = Rules.DEFINITIONS[5]
	_check(multi.extra_balls == 2 and multi.split_angle_degrees == 20.0, "Pin two copies and twenty-degree spread")
	var velocities = Rules.split_velocities(Vector2(0, -700), multi)
	_check(velocities.size() == 2, "Split creates two velocities")
	_check(velocities[0].is_equal_approx(Vector2(-239.4141, -657.7848)), "Pin left spread at speed 700")
	_check(velocities[1].is_equal_approx(Vector2(239.4141, -657.7848)), "Pin right spread at speed 700")
	for velocity in velocities:
		_check(is_equal_approx(velocity.length(), 700.0), "Split preserves speed")
	rules.active.clear()
	rules.apply(multi)
	_check(rules.active.is_empty(), "Multi-ball is instant")
	invalid = multi.duplicate()
	invalid.extra_balls = -1
	_check(not invalid.validation_error().is_empty(), "Reject negative copies")
	invalid.extra_balls = 1
	_check(not invalid.validation_error().is_empty(), "Reject split counts other than two")
	invalid.extra_balls = 2
	invalid.split_angle_degrees = 90.0
	_check(not invalid.validation_error().is_empty(), "Reject ninety-degree spread")
	invalid.split_angle_degrees = 0.0
	_check(not invalid.validation_error().is_empty(), "Reject overlapping trajectories")
	invalid.split_angle_degrees = 20.0
	invalid.duration = 10.0
	_check(not invalid.validation_error().is_empty(), "Reject timed Multi-ball")
	var slow = Rules.DEFINITIONS[3]
	var fast = Rules.DEFINITIONS[4]
	_check(slow.ball_speed_multiplier == 0.75 and fast.ball_speed_multiplier == 1.5, "Pin speed tuning")
	rules.active.clear()
	rules.apply(slow)
	_check(rules.speed_multiplier() == 0.75, "Slow multiplier")
	rules.advance(4.0)
	rules.apply(fast)
	_check(rules.speed_multiplier() == 1.125, "Speed effects multiply")
	rules.apply(slow)
	_check(rules.active[slow.id].remaining == 10.0 and rules.speed_multiplier() == 1.125, "Slow refresh does not stack")
	rules.advance(6.0)
	rules.apply(fast)
	_check(rules.active[fast.id].remaining == 10.0, "Speed-up refreshes")
	rules.advance(4.0)
	_check(rules.speed_multiplier() == 1.5, "Slow expiry leaves speed-up")
	rules.advance(6.0)
	_check(rules.speed_multiplier() == 1.0, "Speed-up expiry restores baseline")
	invalid = slow.duplicate()
	invalid.ball_speed_multiplier = 0.0
	_check(not invalid.validation_error().is_empty(), "Reject zero speed")
	invalid.ball_speed_multiplier = -1.0
	_check(not invalid.validation_error().is_empty(), "Reject negative speed")
	invalid.ball_speed_multiplier = 0.75
	invalid.duration = 0.0
	_check(not invalid.validation_error().is_empty(), "Reject permanent speed effects")
	var rng := RandomNumberGenerator.new()
	rng.seed = 50
	var reference := RandomNumberGenerator.new()
	reference.seed = 50
	var seen := {}
	for i in 300:
		var effect = Rules.random_effect(rng)
		_check(effect == Rules.DEFINITIONS[reference.randi_range(0, Rules.DEFINITIONS.size() - 1)], "Uniform draw uses one equal-weight index")
		seen[effect.id] = true
	_check(seen.size() == 8, "All registered effects are reachable")
	_check(Rules.CAPSULE_SPEED == 240.0, "Pin fall speed")
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
