extends SceneTree

var failures := 0
var heard: Array[StringName] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var game = preload("res://main.tscn").instantiate()
	var first := Level.new()
	first.grid = "#x"
	var last := Level.new()
	last.grid = "#"
	game.levels.assign([first, last])
	root.add_child(game)
	game.set_physics_process(false)
	game.ball.set_physics_process(false)
	game.sounds.cue_played.connect(func(cue: StringName): heard.append(cue))
	var signatures: Array[Vector2] = []
	for cue in game.sounds.CUES:
		var stream: AudioStreamWAV = game.sounds.streams[cue]
		_check(not stream.data.is_empty() and stream.get_length() > 0.0, "Generated PCM exists for %s" % cue)
		_check(not signatures.has(game.sounds.CUES[cue]), "Cue pitch/length differs: %s" % cue)
		signatures.append(game.sounds.CUES[cue])
		_check(game.sounds.play_cue(cue), "Known cue can play")
	_check(game.sounds.players.size() == 12, "Audio pool is bounded")
	heard.clear()
	game.sounds.volume = 0.0
	for player in game.sounds.players:
		_check(player.volume_linear == 0.0, "Mute updates already playing voices")
	game.sounds.play_cue(&"win")
	_expect([&"win"], "Muted events remain observable")
	game.sounds.volume = 0.25
	for player in game.sounds.players:
		_check(is_equal_approx(player.volume_linear, 0.25), "Volume updates every voice")
	game.sounds.volume = 0.0

	var ball = game.ball
	ball.velocity = Vector2(0, -550)
	ball._hit_surface(game.get_node("PlayArea/Walls"), Vector2.DOWN)
	_expect([&"wall_bounce"], "Wall reflection")
	# Exercise the actual top-face collision branch, including signal wiring.
	ball.launched = true
	ball.global_position = game.paddle.global_position + Vector2(0, -30)
	ball.velocity = Vector2(0, 550)
	await physics_frame
	await process_frame
	ball._physics_process(0.03)
	_expect([&"paddle_bounce"], "Paddle collision")
	var reinforced = game.bricks.get_child(1)
	ball._hit_surface(reinforced, Vector2.DOWN)
	_expect([], "Surviving brick is not a wall bounce or break")
	ball._hit_surface(reinforced, Vector2.DOWN)
	ball._break_brick(reinforced)
	_expect([&"brick_break"], "Destruction sounds once, including same-frame repeated hit")
	game._catch_capsule(preload("res://effects/wide_paddle.tres"))
	_expect([&"power_up_catch"], "Power-up catch")
	game.force_field_charges = 1
	game._catch_capsule(preload("res://effects/shrink_paddle.tres"))
	_expect([&"hazard_catch"], "Blocked hazard still has hazard catch cue")
	var extra = game.add_ball()
	extra.set_physics_process(false)
	game._on_death_zone_body_entered(extra)
	_expect([], "Earlier multi-ball loss is silent")
	game._on_death_zone_body_entered(ball)
	game._on_death_zone_body_entered(ball)
	_expect([&"life_lost"], "Only the last ball costs a life and sounds once")
	ball = game.ball
	ball.set_physics_process(false)
	ball._break_brick(game.bricks.get_child(0))
	_expect([&"brick_break", &"level_complete"], "Intermediate level clear")
	game._on_ball_brick_broken(10)
	game._on_death_zone_body_entered(ball)
	_expect([], "Late callbacks after completion are silent")
	game.continue_level()
	game.ball.set_physics_process(false)
	game.ball._break_brick(game.bricks.get_child(0))
	_expect([&"brick_break", &"win"], "Final clear uses win")
	game.free()

	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.sounds.volume = 0.0
	game.sounds.cue_played.connect(func(cue: StringName): heard.append(cue))
	game.lives = 1
	game._on_death_zone_body_entered(game.ball)
	_expect([&"life_lost", &"game_over"], "Final life uses both loss and game over")
	game.free()
	await process_frame
	quit(1 if failures else 0)

func _expect(expected: Array, message: String) -> void:
	_check(heard == expected, "%s: expected %s, got %s" % [message, expected, heard])
	heard.clear()

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
