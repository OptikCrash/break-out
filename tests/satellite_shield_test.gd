extends SceneTree

const Rules = preload("res://effect_rules.gd")
const BallRules = preload("res://ball_rules.gd")
const Shield = preload("res://effects/satellite_shield.tres")
const Sticky = preload("res://effects/sticky_paddle.tres")
const Slow = preload("res://effects/slow_ball.tres")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_rules()
	await _check_launches()
	_check_shield_overlap()
	_check_life_rule()
	_check_level_end()
	quit(1 if failures else 0)

func _check_rules() -> void:
	_check(Shield.id == &"satellite_shield" and Shield.orbs == 3 and Shield.duration == 0.0, "Pin three charge-based orbs")
	_check(Shield.validation_error().is_empty() and Rules.DEFINITIONS.has(Shield), "Shield validates and is in the pool")
	_check(not Shield.hazard and Rules.catch_points(Shield) == 25, "Shield is a power-up worth 25")
	var invalid = Shield.duplicate()
	invalid.orbs = -1
	_check(not invalid.validation_error().is_empty(), "Reject negative orb count")
	invalid.orbs = 3
	invalid.duration = 10.0
	_check(not invalid.validation_error().is_empty(), "Reject timed orbs")
	for current in [0, 1, 2, 3]:
		_check(Rules.orbs_after_catch(current, Shield) == 3, "Catch resets to three from %d, never adds" % current)
	_check(Rules.orbs_after_catch(2, Slow) == 2, "Other capsules leave orbs alone")
	_check(Rules.can_launch_orb(3, false) and Rules.can_launch_orb(1, false), "Orbs launch while any remain")
	_check(not Rules.can_launch_orb(0, false), "No orbs, no launch")
	_check(not Rules.can_launch_orb(3, true), "Never on the press that launches a resting ball")
	var rules = Rules.new()
	rules.apply(Shield)
	_check(rules.active.is_empty(), "Shield has no shared timer")

func _check_launches() -> void:
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.paddle.set_physics_process(false)
	var first = game.ball
	first.set_physics_process(false)
	first.launched = true
	first.velocity = Vector2(0, -550)
	_check(game.satellite_orbs == 0 and game.orb_visual.count == 0, "Starts with no orbs")
	game._catch_capsule(Shield)
	_check(game.satellite_orbs == 3 and game.orb_visual.count == 3, "Catch sets three orbs and shows them")
	_check(game.orb_visual.frames == game.ball.get_node("Sprite2D").sprite_frames, "Waiting orbs use the ball's art")
	_check(game.orb_visual.orbit_size.y >= 48.0 and game.orb_visual.orbit_size.x >= game.paddle.half_width + 48.0, "Orbit clears the paddle by more than a ball width")
	_check(game.score == 25 and not game.effects.active.has(&"satellite_shield"), "Catch scores without a timer")
	_check(game.get_balls() == [first], "Orbiting orbs are not balls")
	_check(not game.orb_visual is PhysicsBody2D and not game.orb_visual.is_in_group("ball"), "Orb visual has no physics or ball group")
	game.satellite_orbs = 1
	game._catch_capsule(Shield)
	_check(game.satellite_orbs == 3, "Re-catch resets to three")
	# Freeze new balls once their script has enabled physics, so a launched orb
	# keeps its exact starting state while the test reads it.
	node_added.connect(_freeze_ball)
	var launched_balls := []
	for expected_orbs in [2, 1, 0]:
		var before: int = game.get_balls().size()
		await _press_power_action()
		var balls = game.get_balls()
		_check(balls.size() == before + 1, "One press adds exactly one ball")
		_check(game.satellite_orbs == expected_orbs and game.orb_visual.count == expected_orbs, "One press uses one orb, leaving %d" % expected_orbs)
		var orb_ball = balls[balls.size() - 1]
		launched_balls.append(orb_ball)
		_check(orb_ball.breaker_time_left == BallRules.BREAKER_DURATION, "Breaker timer starts full at launch")
		_check(orb_ball.launched and orb_ball.velocity.y < 0.0 and is_equal_approx(orb_ball.velocity.length(), 550.0), "Orb launches upward at launch speed")
		_check(orb_ball.position == game.paddle.position + Vector2(0, -24), "Orb launches from the paddle")
		_check(orb_ball.brick_broken.is_connected(game._on_ball_brick_broken), "Orb ball reports score through add_ball()")
	var count: int = game.get_balls().size()
	await _press_power_action()
	_check(game.get_balls().size() == count and game.satellite_orbs == 0, "Pressing with zero orbs does nothing")
	# Speed effects apply because the orb comes from add_ball().
	game._catch_capsule(Slow)
	game._catch_capsule(Shield)
	var slow_ball = game.launch_orb()
	_check(is_equal_approx(slow_ball.velocity.length(), 550.0 * 0.75), "Orb launches at the current speed effect")
	# No arbitration: one press releases Sticky, fires Blaster and launches an orb.
	game.effects.active.clear()
	game._catch_capsule(Sticky)
	game._catch_capsule(preload("res://effects/blaster.tres"))
	first.velocity = Vector2(0, 550)
	first.catch_on_paddle(0.0)
	first.set_physics_process(true)
	var orbs_before: int = game.satellite_orbs
	await _press_power_action()
	first.set_physics_process(false)
	_check(not first.caught and game.satellite_orbs == orbs_before - 1, "One press releases the catch and launches an orb")
	_check(get_nodes_in_group("blaster_bolt").size() == 2, "The same press also fires a Blaster pair")
	# A resting ball takes the shared press for its own launch.
	game._clear_effects_and_capsules()
	first.reset()
	game._catch_capsule(Shield)
	_check(game.launch_orb() == null and game.satellite_orbs == 3, "Resting ball blocks the orb launch")
	node_added.disconnect(_freeze_ball)
	game.free()

func _check_shield_overlap() -> void:
	var game = preload("res://main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	game._catch_capsule(preload("res://effects/force_field.tres"))
	game._catch_capsule(Shield)
	_check(game.force_field_charges == 3 and game.satellite_orbs == 3, "Satellite pickup preserves Force Field charges")
	_check(game.score == 50, "Both shield pickups award 25 points")
	game._catch_capsule(preload("res://effects/shrink_paddle.tres"))
	_check(game.force_field_charges == 2 and game.satellite_orbs == 3, "Blocked hazard spends only Force Field charge")
	_check(game.effects.active.is_empty() and game.score == 50, "Blocked hazard has no timer or score")
	game._clear_effects_and_capsules()
	_check(game.force_field_charges == 0 and game.satellite_orbs == 0, "Lifecycle clearing resets both shields")
	game.free()

func _check_life_rule() -> void:
	var game = preload("res://main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var first = game.ball
	first.launched = true
	game._catch_capsule(Shield)
	var orb_ball = game.launch_orb()
	_check(game.get_balls().size() == 2 and game.satellite_orbs == 2, "Launch adds a second ball")
	game._on_death_zone_body_entered(orb_ball)
	_check(game.lives == 3 and game.get_balls() == [first], "Losing an orb ball with another in play costs no life")
	_check(game.satellite_orbs == 2, "Losing a launched orb keeps the waiting ones")
	orb_ball = game.launch_orb()
	game._on_death_zone_body_entered(first)
	_check(game.lives == 3 and game.get_balls() == [orb_ball], "Orb ball can be the last ball in play")
	game._on_death_zone_body_entered(orb_ball)
	_check(game.lives == 2 and game.get_balls().size() == 1, "Last orb ball lost costs one life")
	_check(game.satellite_orbs == 0 and game.orb_visual.count == 0, "Life loss clears waiting orbs like other effects")
	game.free()

func _check_level_end() -> void:
	var game = preload("res://main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var level := Level.new()
	level.grid = "##"
	game.levels.assign([level, level])
	root.add_child(game)
	game.ball.launched = true
	game._catch_capsule(Shield)
	game.ball._break_brick(game.bricks.get_child(0))
	game.ball._break_brick(game.bricks.get_child(1))
	_check(game.level_complete and game.satellite_orbs == 0, "Level end clears waiting orbs")
	game.satellite_orbs = 3
	_check(game.launch_orb() == null, "No launch under the level-complete message")
	game.free()

func _press_power_action() -> void:
	Input.action_press("power_action")
	await physics_frame
	await physics_frame
	await physics_frame
	Input.action_release("power_action")
	await physics_frame

func _freeze_ball(node: Node) -> void:
	if node.is_in_group("ball"):
		node.ready.connect(node.set_physics_process.bind(false), CONNECT_ONE_SHOT)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
