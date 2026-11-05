extends SceneTree

const BallRules = preload("res://ball_rules.gd")
const Breaker = preload("res://effects/breaker.tres")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Pure rule: steady, then flicker in the final three seconds, then off.
	_check(not BallRules.breaker_glow_visible(0.0), "No glow without Breaker time")
	_check(BallRules.breaker_glow_visible(10.0) and BallRules.breaker_glow_visible(3.01), "Steady glow above three seconds")
	var states := {}
	var t := 3.0
	while t > 0.0:
		states[BallRules.breaker_glow_visible(t)] = true
		t -= 0.05
	_check(states.has(true) and states.has(false), "Glow flickers on and off under three seconds")
	_check(BallRules.breaker_glow_visible(3.0) and not BallRules.breaker_glow_visible(3.0 - 0.2), "Flicker toggles each step")

	var game = preload("res://main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var ball = game.ball
	var glow: Sprite2D = ball.get_node("Glow")
	_check(glow.material is CanvasItemMaterial and glow.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Glow is an additive sprite, not a Light2D")
	_check(glow.get_index() < ball.get_node("Sprite2D").get_index(), "Glow draws behind the ball")
	_check(not glow.visible, "Ordinary ball has no glow")
	game._catch_capsule(Breaker)
	_check(glow.visible, "Breaker pickup lights the glow immediately")
	ball._physics_process(6.0)
	_check(glow.visible, "Glow stays steady with four seconds left")
	var seen := {}
	for i in 40:
		ball._physics_process(0.05)
		seen[glow.visible] = true
	_check(seen.has(true) and seen.has(false), "Glow flickers in the final seconds")
	ball._physics_process(5.0)
	_check(not ball.breaker_active and not glow.visible, "Glow disappears when Breaker expires")
	game._catch_capsule(Breaker)
	var copy = game.add_ball()
	copy.breaker_time_left = ball.breaker_time_left
	_check(copy.get_node("Glow").visible, "Copied Breaker time lights the copy's glow")
	ball.breaker_active = false
	_check(not glow.visible, "Clearing Breaker hides the glow")
	game.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
