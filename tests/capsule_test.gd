extends SceneTree

const Rules = preload("res://effect_rules.gd")
const Capsule = preload("res://capsule.tscn")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var game = preload("res://main.tscn").instantiate()
	var level := Level.new()
	level.grid = "?#"
	game.levels.assign([level])
	root.add_child(game)
	game.ball.set_physics_process(false)
	game.paddle.set_physics_process(false)
	var mystery = game.bricks.get_child(0)
	# Move the shape to prove drops use its center rather than a duplicated offset.
	mystery.get_node("CollisionShape2D").position += Vector2(3, 2)
	var drop_at: Vector2 = mystery.get_node("CollisionShape2D").global_position
	# Freeze new drops at tree entry, before any physics step can move them.
	var freeze_drop := func(node: Node):
		if node.is_in_group("capsule"):
			node.set_physics_process(false)
	node_added.connect(freeze_drop)
	game.ball._break_brick(mystery)
	game.ball._break_brick(mystery)
	await process_frame
	node_added.disconnect(freeze_drop)
	var drops := get_nodes_in_group("capsule")
	_check(drops.size() == 1, "Duplicate final hit drops only one capsule")
	var capsule = drops[0]
	_check(capsule.global_position.is_equal_approx(drop_at), "Drop at brick center")
	_check(game.score == 0 and game.bricks_left == 1, "Mystery gives zero points and counts toward completion")
	capsule.set_physics_process(false)
	var start: Vector2 = capsule.position
	capsule._physics_process(0.5)
	_check(capsule.position == start + Vector2(0, 120), "Falls straight down at 240 pixels per second")
	capsule.queue_free()
	await process_frame
	for effect in Rules.DEFINITIONS:
		var score_before: int = game.score
		var lives_before: int = game.lives
		capsule = Capsule.instantiate()
		capsule.effect = effect
		capsule.position = game.paddle.position - Vector2(0, 40)
		capsule.caught.connect(game._catch_capsule)
		game.get_node("PlayArea").add_child(capsule)
		for frame in 30:
			await physics_frame
			if not is_instance_valid(capsule):
				break
		await process_frame
		_check(not is_instance_valid(capsule), "Falling capsule physically touches paddle and frees")
		_check(game.score == score_before + Rules.catch_points(effect), "Catch awards 25 for power-up and zero for hazard")
		_check(game.lives == lives_before + effect.extra_lives, "Extra Life adds exactly one life")
	_check(game.effects.active.size() == 5, "Five timed effects run concurrently; Extra Life and Multi-ball are instant")
	_check(game.paddle.half_width == 72.0, "Combined width affects bounce extent")
	_check(game.paddle.get_node("CollisionShape2D").scale.x == 1.125, "Collision width follows effects")
	_check(game.paddle.get_node("Sprite2D").scale.x == 1.125, "Existing art follows collision width")
	var score_before: int = game.score
	var lives_before: int = game.lives
	capsule = Capsule.instantiate()
	capsule.effect = Rules.DEFINITIONS[2]
	capsule.position = Vector2(200, 970)
	capsule.caught.connect(game._catch_capsule)
	game.get_node("PlayArea").add_child(capsule)
	for frame in 30:
		await physics_frame
		if not is_instance_valid(capsule):
			break
	await process_frame
	_check(not is_instance_valid(capsule), "Death Zone physically removes missed capsule")
	_check(game.score == score_before and game.lives == lives_before, "Miss has no score or life penalty")
	for active_ball in game.get_balls():
		game._on_death_zone_body_entered(active_ball)
	_check(game.effects.active.is_empty() and game.paddle.half_width == 64.0, "Life loss restores base width and clears timers")
	game.ball._break_brick(game.bricks.get_child(0))
	_check(game.reset_ready, "Remaining normal brick completes level")
	game.free()
	# Exercise ball.gd's actual collision path at the same relative hit position.
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.ball.set_physics_process(false)
	game.paddle.set_physics_process(false)
	for multiplier in [1.0, 1.5, 0.75]:
		game.paddle.set_width_multiplier(multiplier)
		game.ball.position = game.paddle.position + Vector2(game.paddle.half_width * 0.75, -30)
		game.ball.launched = true
		game.ball.velocity = Vector2(0, 550)
		await physics_frame
		game.ball._physics_process(1.0 / 60.0)
		var expected := Vector2(0.75, -1).normalized() * 550.0
		_check(game.ball.velocity.is_equal_approx(expected), "Bounce uses current half-width and preserves 550 speed")
	# Widen while touching the right wall, then let move_and_slide recover.
	var right_wall = game.get_node("PlayArea/Walls/Right")
	var wall_inner_x: float = right_wall.position.x - right_wall.shape.size.x / 2.0
	game.paddle.set_width_multiplier(1.0)
	game.paddle.position.x = wall_inner_x - game.paddle.half_width
	await physics_frame
	game.paddle.set_width_multiplier(1.5)
	for frame in 5:
		await physics_frame
		game.paddle._physics_process(1.0 / 60.0)
	_check(game.paddle.position.x + game.paddle.half_width <= wall_inner_x + 0.1, "Widening at wall recovers without overlap")
	game.free()
	# A Mystery Brick may also be the last target: its deferred drop must not leak.
	game = preload("res://main.tscn").instantiate()
	level.grid = "?"
	game.levels.assign([level])
	root.add_child(game)
	game.ball._break_brick(game.bricks.get_child(0))
	await process_frame
	_check(game.reset_ready and get_nodes_in_group("capsule").is_empty(), "Final Mystery completes level without leaving a pending capsule")
	game.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
