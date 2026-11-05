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
	ball._hit_surface(resistant, Vector2.DOWN)
	_check(ball.velocity == Vector2(0, -550), "Same-frame repeated hit stays pass-through")
	_check(resistant.is_queued_for_deletion() and game.score == 100, "One hit awards exactly fifty once, including same-frame duplicate")
	_check(game.bricks_left == 1 and not game.reset_ready, "Optional destruction cannot complete the level")
	second._physics_process(10.0)
	_check(not second.breaker_active, "Breaker expires at ten seconds")
	ball._break_brick(game.bricks.get_child(0))
	_check(game.reset_ready and game.bricks_left == 0 and game.score == 110, "Required brick completes level with Resistant remaining")
	_check(not survivor.is_queued_for_deletion() and not ball.breaker_active and game.effects.active.is_empty(), "Completion leaves optional brick and clears effects")
	game.free()
	_check_breaker_brick_types()
	await _check_physics_collision()
	quit(1 if failures else 0)

func _check_breaker_brick_types() -> void:
	var level := Level.new()
	level.grid = "#xox"
	var game = preload("res://main.tscn").instantiate()
	game.levels.assign([level])
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var ball = game.ball
	var normal = game.bricks.get_child(0)
	var reinforced = game.bricks.get_child(1)
	var indestructible = game.bricks.get_child(2)
	var other_reinforced = game.bricks.get_child(3)
	ball.breaker_active = true
	ball.velocity = Vector2(0, -550)
	ball._hit_surface(reinforced, Vector2.DOWN)
	_check(reinforced.is_queued_for_deletion() and game.score == 20, "Breaker destroys Reinforced in one hit for its full points")
	_check(ball.velocity == Vector2(0, 550), "Breaker still bounces off a destroyed Reinforced brick")
	# Repeat before yielding: queue_free leaves the collider live until frame end.
	ball._hit_surface(reinforced, Vector2.DOWN)
	_check(game.score == 20, "Same-frame repeated Reinforced hit awards once")
	ball._hit_surface(indestructible, Vector2.DOWN)
	_check(not indestructible.is_queued_for_deletion() and game.score == 20, "Breaker cannot destroy Indestructible")
	ball._hit_surface(normal, Vector2.DOWN)
	_check(normal.is_queued_for_deletion() and game.score == 30, "Breaker destroys Normal in one hit")
	ball.breaker_active = false
	ball._hit_surface(other_reinforced, Vector2.DOWN)
	_check(other_reinforced.hit_points == 1 and not other_reinforced.is_queued_for_deletion(), "Expired Breaker deals ordinary one-point damage")
	game.free()

func _check_physics_collision() -> void:
	var world := Node2D.new()
	# Step the ball explicitly after the physics server registers the shapes.
	root.add_child(world)
	var brick = preload("res://brick.tscn").instantiate()
	brick.configure("r")
	brick.position = Vector2(400, 300)
	world.add_child(brick)
	var ball = preload("res://ball.tscn").instantiate()
	ball.launched = true
	ball.position = Vector2(432, 380)
	world.add_child(ball)
	ball.set_physics_process(false)
	var awards: Array[int] = []
	ball.brick_broken.connect(func(points: int): awards.append(points))
	await physics_frame
	await physics_frame
	ball.velocity = Vector2(0, -550)
	ball._physics_process(0.1)
	_check(ball.position.y > 348.0 and ball.position.y < 380.0, "Physics sweep contacts Resistant instead of crossing it")
	_check(ball.velocity == Vector2(0, 550) and brick.hit_points == 1 and awards.is_empty(), "Real ordinary collision bounces without damage or score")
	ball.position = Vector2(432, 380)
	ball.velocity = Vector2(0, -550)
	ball.breaker_active = true
	ball._physics_process(0.1)
	_check(brick.is_queued_for_deletion() and awards == [50], "Real Breaker collision destroys Resistant and emits fifty points")
	_check(ball.velocity == Vector2(0, -550), "Real Breaker collision preserves forward velocity")
	# Repeat before yielding: queue_free leaves the collider live until frame end.
	ball._physics_process(0.1)
	_check(ball.velocity == Vector2(0, -550) and awards == [50], "Second same-frame physics collision stays pass-through and awards once")
	await process_frame
	await process_frame
	ball._physics_process(0.1)
	_check(ball.position.y < 332.0 and awards == [50], "Breaker crosses the former brick after deletion without another award")
	world.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
