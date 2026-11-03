extends SceneTree

const Multi = preload("res://effects/multi_ball.tres")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.paddle.set_physics_process(false)
	var freeze_ball := func(node: Node):
		if node.is_in_group("ball"):
			node.set_physics_process(false)
			node.ready.connect(func(): node.set_physics_process(false), CONNECT_ONE_SHOT)
	node_added.connect(freeze_ball)
	var source = game.ball
	source.set_physics_process(false)
	source.position = Vector2(400, 500)
	source.launched = true
	source.speed = 700.0
	source.velocity = Vector2(0, -700)
	source.breaker_time_left = 4.5
	var capsule = preload("res://capsule.tscn").instantiate()
	capsule.effect = Multi
	capsule.caught.connect(game._catch_capsule)
	game.get_node("PlayArea").add_child(capsule)
	capsule._on_body_entered(game.paddle)
	capsule._on_body_entered(game.paddle)
	await process_frame
	var balls = game.get_balls()
	_check(balls.size() == 3 and get_nodes_in_group("ball").size() == 3, "One catch produces exactly three balls, even with duplicate contact")
	_check(game.score == 25 and game.effects.active.is_empty(), "Multi-ball awards 25 points without a timer")
	_check(source.velocity == Vector2(0, -700), "Original trajectory stays unchanged")
	for active_ball in balls:
		active_ball.set_physics_process(false)
		_check(active_ball.launched and active_ball.speed == 700.0, "Copies inherit launched state and speed property")
		_check(active_ball.position == source.position, "Copies start at source without wall-crossing offsets")
		_check(is_equal_approx(active_ball.velocity.length(), 700.0), "Copies preserve actual velocity speed")
		_check(active_ball.breaker_time_left == 4.5, "Copies inherit remaining Breaker time")
		_check(active_ball.paddle == game.paddle, "Copies reference gameplay paddle")
		for other in balls:
			if other != active_ball:
				_check(active_ball.get_collision_exceptions().has(other), "Balls cannot collide at shared spawn point")
	_check(balls[1].velocity.is_equal_approx(Vector2(-239.4141, -657.7848)), "Left copy spreads twenty degrees")
	_check(balls[2].velocity.is_equal_approx(Vector2(239.4141, -657.7848)), "Right copy spreads twenty degrees")
	# Let real physics move the copies once: neither is stuck against another ball.
	await physics_frame
	for active_ball in balls:
		active_ball._physics_process(1.0 / 60.0)
	_check(balls[1].position.x < source.position.x and balls[2].position.x > source.position.x, "Copies separate during physics")
	game._on_death_zone_body_entered(balls[0])
	game._on_death_zone_body_entered(balls[1])
	_check(game.lives == 3 and game.get_balls().size() == 1, "Losing two split balls costs no life")
	game._on_death_zone_body_entered(balls[2])
	game._on_death_zone_body_entered(balls[2])
	_check(game.lives == 2 and game.get_balls().size() == 1, "Last loss costs exactly one life in same frame")
	_check(not game.ball.launched, "Last loss creates a resting replacement")
	await process_frame
	_check(get_nodes_in_group("ball").size() == 1, "Lost copies leave the group")
	# Loose capsules can be caught before launch; never launch a resting ball implicitly.
	game._catch_capsule(Multi)
	await process_frame
	_check(game.get_balls().size() == 3, "Resting ball also splits into three")
	for active_ball in game.get_balls():
		_check(not active_ball.launched and active_ball.position == game.paddle.position + Vector2(0, -24), "Resting copies wait on paddle")
	game._catch_capsule(Multi)
	await process_frame
	_check(game.get_balls().size() == 5, "Repeat catch adds two rather than splitting every ball")
	var resting = game.ball
	var launched = game.get_balls()[1]
	launched.launched = true
	launched.position = Vector2(300, 400)
	launched.velocity = Vector2(100, -500)
	var before_split = game.get_balls()
	game._catch_capsule(Multi)
	await process_frame
	var all_balls = game.get_balls()
	_check(all_balls.size() == 7 and not resting.launched, "Mixed resting and launched catch adds two")
	for active_ball in all_balls:
		if not before_split.has(active_ball):
			_check(active_ball.position == launched.position and active_ball.launched, "Prefer first launched source over resting ball")
			_check(active_ball.brick_broken.is_connected(game._on_ball_brick_broken), "Spawned copies report scoring")
	# Copies inherit the active multiplier as well as the already-scaled velocity.
	game._catch_capsule(preload("res://effects/slow_ball.tres"))
	game._catch_capsule(preload("res://effects/speed_up_ball.tres"))
	game._catch_capsule(Multi)
	await process_frame
	var split_balls = game.get_balls()
	_check(split_balls.size() == 9, "Speed effects still allow two copies")
	for copy in [split_balls[7], split_balls[8]]:
		_check(copy.speed_multiplier == 1.125, "Copies inherit overlapping speed effects")
		_check(is_equal_approx(copy.velocity.length(), Vector2(100, -500).length() * 1.125), "Copies preserve scaled source speed")
	game.effects.advance(10.0)
	game._update_ball_speeds()
	for copy in [split_balls[7], split_balls[8]]:
		_check(copy.speed_multiplier == 1.0, "Copy multiplier expires")
		_check(is_equal_approx(copy.velocity.length(), Vector2(100, -500).length()), "Expiry restores underlying copy speed exactly once")
	# A pending split cannot resurrect a ball already lost in the same frame.
	game.lives = 4
	for active_ball in game.get_balls():
		game._on_death_zone_body_entered(active_ball)
	game._catch_capsule(Multi)
	game._on_death_zone_body_entered(game.ball)
	await process_frame
	_check(game.get_balls().size() == 1 and game.lives == 2, "Pending split cannot survive its source")
	# Completion recounts real bricks, so use a one-brick layout.
	var final_layout := Level.new()
	final_layout.grid = "#"
	game.bricks.load_level(final_layout)
	game._catch_capsule(Multi)
	game.ball._break_brick(game.bricks.get_child(0))
	await process_frame
	_check(game.level_complete and game.get_balls().size() == 1, "Completion cancels pending split")
	node_added.disconnect(freeze_ball)
	game.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
