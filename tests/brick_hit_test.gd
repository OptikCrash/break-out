extends SceneTree

var failures := 0
var broken_signals := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://main.tscn").instantiate()
	var bricks = game.get_node("PlayArea/Bricks")
	bricks.columns = 2
	bricks.rows = 1
	# Exercise the hit rule synchronously, without input or physics timing.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var ball = game.get_node("PlayArea/Ball")
	ball.brick_broken.connect(func(): broken_signals += 1)
	var first_brick = bricks.get_child(0)
	var last_brick = bricks.get_child(1)
	_check(game.score == 0 and game.bricks_left == 2, "Start with two unbroken bricks and zero points")

	ball._break_brick(first_brick)
	ball._break_brick(first_brick)
	_check(first_brick.is_queued_for_deletion(), "First hit queues the brick for deletion")
	_check(broken_signals == 1, "Repeated hit emits only one brick_broken signal")
	_check(game.score == 10, "Repeated hit scores exactly 10 points")
	_check(game.bricks_left == 1, "Repeated hit removes exactly one remaining brick")
	_check(not game.reset_ready, "One remaining brick does not trigger a win")

	ball.launched = true
	ball._break_brick(last_brick)
	ball._break_brick(last_brick)
	_check(broken_signals == 2, "Two distinct bricks emit exactly two signals")
	_check(game.score == 20, "Repeated final hit leaves the total at 20 points")
	_check(game.bricks_left == 0, "Repeated final hit leaves zero remaining bricks")
	_check(game.reset_ready, "Final brick enables restart")
	_check(not ball.launched and not ball.is_physics_processing(), "Win resets and stops the ball")
	_check(game.get_node("Hud/MessageLabel").text == "You Win!\nPress R to restart", "Final brick displays the win message")

	game.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
