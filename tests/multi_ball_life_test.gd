extends SceneTree

const Effects = preload("res://effect_rules.gd")

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	var first = game.ball
	var second = game.add_ball()
	first.breaker_active = true
	_check(not second.breaker_active, "Power timers belong to individual balls")
	second.launched = true
	game._catch_capsule(Effects.DEFINITIONS[0])
	_check(game.can_pause(), "Any launched ball allows pause")
	game._on_death_zone_body_entered(game.paddle)
	_check(game.lives == 3, "Non-ball bodies cost no life")
	game._on_death_zone_body_entered(first)
	game._on_death_zone_body_entered(first)
	_check(game.lives == 3 and game.get_balls() == [second], "First loss and duplicate callback cost no life")
	_check(game.effects.active.has("wide_paddle") and game.paddle.half_width == 96.0, "Losing one of multiple balls preserves active effects")
	_check(first.is_queued_for_deletion(), "Lost ball queues deletion immediately")
	game._on_death_zone_body_entered(second)
	game._on_death_zone_body_entered(second)
	_check(game.lives == 2 and game.get_balls().size() == 1, "Same-frame last loss costs exactly one life")
	_check(game.effects.active.is_empty() and game.paddle.half_width == 64.0, "Last-ball loss clears effects and restores width")
	_check(not game.ball.launched and game.ball.position == game.paddle.position + Vector2(0, -24), "Replacement rests synchronously on paddle")
	await process_frame
	_check(not is_instance_valid(first) and not is_instance_valid(second), "Both lost balls are freed")
	game._on_death_zone_body_entered(game.ball)
	_check(game.lives == 1, "Single-ball loss costs one life")
	game._on_death_zone_body_entered(game.ball)
	_check(game.lives == 0 and game.reset_ready and game.get_balls().is_empty(), "Final life ends without replacement")
	game.free()
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	first = game.ball
	second = game.add_ball()
	first.launched = true
	second.launched = true
	game._catch_capsule(Effects.DEFINITIONS[0])
	# Use a real final brick so completion exercises the live layout.
	var final_level := Level.new()
	final_level.grid = "#"
	game.bricks.load_level(final_level)
	game._count_completion_bricks()
	second._break_brick(game.bricks.get_child(0))
	_check(game.score == 35 and game.level_complete, "Added ball reports destruction and score")
	_check(game.effects.active.is_empty() and game.paddle.half_width == 64.0, "Completion clears effects with multiple balls")
	for active_ball in game.get_balls():
		_check(not active_ball.launched and not active_ball.is_physics_processing(), "Completion resets and stops every ball")
	game.continue_level()
	for active_ball in game.get_balls():
		_check(not active_ball.launched and active_ball.is_physics_processing(), "Continue readies every ball")
	game.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
