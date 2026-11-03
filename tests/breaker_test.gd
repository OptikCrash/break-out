extends SceneTree

const BrickRules = preload("res://brick_rules.gd")
const Breaker = preload("res://effects/breaker.tres")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var definition = BrickRules.definition_for_symbol("r")
	_check(definition.id == &"resistant" and definition.hit_points == 1 and definition.points == 50, "Pin Resistant content")
	_check(definition.requires_breaker and not definition.counts_for_completion, "Resistant requires Breaker and is optional")
	_check(not BrickRules.can_damage(definition, false) and BrickRules.can_damage(definition, true), "Pure damage eligibility")
	var invalid = definition.duplicate()
	invalid.destructible = false
	invalid.hit_points = 0
	invalid.points = 0
	_check(not invalid.validation_error().is_empty(), "Reject indestructible Breaker-only content")
	_check(Breaker.duration == preload("res://ball_rules.gd").BREAKER_DURATION, "Definition and per-ball default agree on ten seconds")
	var level := Level.new()
	for grid in ["r", "ro", "r.r"]:
		level.grid = grid
		_check(not level.validation_error().is_empty(), "Optional bricks alone cannot form a level")
	level.grid = "#rr"
	_check(level.validation_error().is_empty() and level.brick_cells().size() == 3, "Resistant grid symbol loads")
	var game = preload("res://main.tscn").instantiate()
	game.levels.assign([level])
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var ball = game.ball
	var second = game.add_ball()
	var resistant = game.bricks.get_child(1)
	var survivor = game.bricks.get_child(2)
	_check(game.bricks_left == 1, "Resistant excluded from initial count")
	ball.velocity = Vector2(0, -550)
	ball._hit_surface(resistant, Vector2.DOWN)
	_check(ball.velocity == Vector2(0, 550), "Normal hit bounces at unchanged speed")
	_check(resistant.hit_points == 1 and not resistant.is_queued_for_deletion(), "Normal hit does no damage")
	_check(game.score == 0 and game.bricks_left == 1, "Normal hit changes neither score nor count")
	game._catch_capsule(Breaker)
	_check(ball.breaker_time_left == 10.0 and second.breaker_time_left == 10.0, "Pickup enables every current ball for ten seconds")
	_check(game.effects.active[&"breaker"].remaining == 10.0 and game.score == 25, "Shared timer and catch score")
	ball._physics_process(4.0)
	second._physics_process(7.0)
	game._physics_process(4.0)
	game._catch_capsule(Breaker)
	_check(ball.breaker_time_left == 10.0 and second.breaker_time_left == 10.0 and game.effects.active[&"breaker"].remaining == 10.0, "Recatch refreshes all timers")
	var later = game.add_ball()
	_check(not later.breaker_active, "Later balls do not inherit a previous pickup")
	ball.velocity = Vector2(0, -550)
	ball._hit_surface(resistant, Vector2.DOWN)
	_check(ball.velocity == Vector2(0, -550), "Breaker continues through destroyed Resistant")
	ball._break_brick(resistant)
	_check(resistant.is_queued_for_deletion() and game.score == 100, "One hit awards exactly fifty once, including same-frame duplicate")
	_check(game.bricks_left == 1 and not game.reset_ready, "Optional destruction cannot complete the level")
	second._physics_process(10.0)
	_check(not second.breaker_active, "Breaker expires at ten seconds")
	ball._break_brick(game.bricks.get_child(0))
	_check(game.reset_ready and game.bricks_left == 0 and game.score == 110, "Required brick completes level with Resistant remaining")
	_check(not survivor.is_queued_for_deletion() and not ball.breaker_active and game.effects.active.is_empty(), "Completion leaves optional brick and clears effects")
	game.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
