extends SceneTree

const EFFECT = preload("res://effects/companion_paddle.tres")
const Rules = preload("res://effect_rules.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var unassigned = preload("res://companion_paddle.tscn").instantiate()
	root.add_child(unassigned)
	unassigned._physics_process(0.1)
	_check(unassigned.position == Vector2.ZERO, "Unassigned companion waits safely for its main paddle")
	unassigned.free()
	_check(EFFECT.companion_count == 2 and EFFECT.companion_health == 3, "Pin count and health")
	_check(EFFECT.companion_offset == Vector2(160, -96) and EFFECT.companion_follow_speed == 600.0, "Pin spacing and follow speed")
	_check(Rules.companion_clamp_x(200, Vector2(416, 1504), 64) == 480.0, "Left wall includes half-width")
	_check(Rules.companion_clamp_x(1700, Vector2(416, 1504), 64) == 1440.0, "Right wall includes half-width")
	_check(Rules.companion_clamp_x(960, Vector2(416, 1504), 64) == 960.0, "Interior center unchanged")
	for health in range(4):
		_check(Rules.companion_health_after_hit(health) == maxi(0, health - 1), "One damage with zero floor")
	_check(Rules.companion_follow_x(0, 1000, 600, 0.1) == 60.0, "Lag advances sixty pixels in a tenth second")
	_check(Rules.companion_follow_x(100, 0, 600, 0.1) == 40.0, "Signed follow")
	_check(Rules.companion_follow_x(0, 10, 600, 0.1) == 10.0, "Catch up without overshoot")
	for property in ["companion_count", "companion_health", "companion_offset", "companion_follow_speed", "duration", "hazard"]:
		var invalid = EFFECT.duplicate()
		invalid.set(property, {"companion_count": 1, "companion_health": 2, "companion_offset": Vector2.ZERO, "companion_follow_speed": 0.0, "duration": 10.0, "hazard": true}[property])
		_check(not invalid.validation_error().is_empty(), "Reject invalid companion content: " + property)
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.paddle.set_physics_process(false)
	var ball = game.ball
	ball.set_physics_process(false)
	game._catch_capsule(EFFECT)
	await process_frame
	_check(game.companions.size() == 2 and game.score == 25 and game.effects.active.is_empty(), "Catch spawns two and scores without timer")
	for index in range(2):
		var companion = game.companions[index]
		companion.set_physics_process(false)
		_check(companion.health == 3 and companion.half_width == 64.0, "Fresh full-width paddle")
		_check(companion.global_position == game.paddle.global_position + Vector2(-160 if index == 0 else 160, -96), "Left/right spawn offsets")
		_check(companion.get_node("CollisionShape2D").shape == game.paddle.get_node("CollisionShape2D").shape, "Reuse paddle shape resource")
	var left = game.companions[0]
	game.paddle.position.x += 100
	left._physics_process(0.1)
	_check(left.global_position.x == game.paddle.global_position.x - 200.0, "Actual follow lags forty pixels")
	left._physics_process(0.1)
	_check(left.global_position.x == game.paddle.global_position.x - 160.0, "Actual follow catches up")
	var paddle_start: Vector2 = game.paddle.position
	for edge in [96.0, 1056.0]:
		game.paddle.position.x = edge
		game._catch_capsule(EFFECT)
		await process_frame
		for follower in game.companions:
			follower.set_physics_process(false)
			_check(follower.global_position.x >= 480.0 and follower.global_position.x <= 1440.0, "Spawn stays inside inner walls")
			follower._physics_process(1.0)
			_check(follower.global_position.x >= 480.0 and follower.global_position.x <= 1440.0, "Follow stays inside inner walls")
	game.paddle.position = paddle_start
	game._catch_capsule(EFFECT)
	await process_frame
	for follower in game.companions:
		follower.set_physics_process(false)
	left = game.companions[0]
	game._catch_capsule(preload("res://effects/sticky_paddle.tres"))
	await physics_frame
	await process_frame
	# Underside and side contacts must leave the surface, even during Sticky.
	ball.launched = true
	ball.global_position = left.global_position + Vector2(0, 30)
	ball.velocity = Vector2(0, -550)
	ball._physics_process(0.03)
	_check(ball.velocity.is_equal_approx(Vector2(0, 550)) and not ball.caught, "Underside reflects downward at unchanged speed")
	ball._physics_process(0.01)
	_check(left.health == 3 and ball.velocity.y > 0, "Two underside steps preserve health and leave the companion")
	ball.global_position = left.global_position + Vector2(-90, 0)
	ball.velocity = Vector2(550, 0)
	ball._physics_process(0.03)
	_check(ball.velocity.is_equal_approx(Vector2(-550, 0)) and not ball.caught, "Side reflects outward at unchanged speed")
	ball._physics_process(0.01)
	_check(left.health == 3 and ball.velocity.x < 0, "Two side steps preserve health and leave the companion")
	for remaining in [2, 1, 0]:
		ball.global_position = left.global_position + Vector2(32, -30)
		ball.launched = true
		ball.velocity = Vector2(0, 550)
		ball._physics_process(0.03)
		_check(left.health == remaining, "Actual ball bounce consumes one health")
		_check(not ball.caught and ball.velocity.y < 0 and is_equal_approx(ball.velocity.length(), 550.0), "Companion bounces normally even with Sticky")
	_check(left.is_queued_for_deletion() and game.companions.size() == 1, "Third bounce removes companion immediately")
	var survivor = game.companions[0]
	_check(survivor.offset == Vector2(0, -96), "Survivor targets center")
	survivor._physics_process(1.0)
	_check(survivor.global_position == game.paddle.global_position + Vector2(0, -96), "Survivor catches up above main paddle")
	var pickup = preload("res://capsule.tscn").instantiate()
	pickup.effect = EFFECT
	game.add_child(pickup)
	pickup._on_body_entered(survivor)
	_check(not pickup.is_queued_for_deletion() and survivor.health == 3, "Power-up passes through companion")
	pickup.queue_free()
	game._catch_capsule(preload("res://effects/force_field.tres"))
	var score_before: int = game.score
	await physics_frame
	await process_frame
	# Real Area2D/body overlap verifies the capsule mask reaches companions.
	var hazard = preload("res://capsule.tscn").instantiate()
	hazard.effect = preload("res://effects/shrink_paddle.tres")
	hazard.caught.connect(game._catch_capsule)
	hazard.position = survivor.global_position
	game.add_child(hazard)
	hazard.set_physics_process(false)
	await physics_frame
	await physics_frame
	await process_frame
	_check(not is_instance_valid(hazard) and survivor.health == 2, "Hazard overlap consumes local health and capsule")
	_check(game.score == score_before and not game.effects.active.has(&"shrink_paddle") and game.force_field_charges == 3, "Local hazard gives no score, effect or field charge cost")
	# Repeated callbacks before frame-end must not spend health twice or collect.
	var blocked = preload("res://capsule.tscn").instantiate()
	blocked.effect = preload("res://effects/speed_up_ball.tres")
	blocked.caught.connect(game._catch_capsule)
	game.add_child(blocked)
	blocked._on_body_entered(survivor)
	blocked._on_body_entered(survivor)
	blocked._on_body_entered(game.paddle)
	_check(survivor.health == 1 and game.score == score_before and not game.effects.active.has(&"speed_up_ball"), "One hazard cannot damage twice or reach main paddle")
	game._catch_capsule(EFFECT)
	await process_frame
	_check(survivor.is_queued_for_deletion() if is_instance_valid(survivor) else true, "Recatch replaces survivor")
	_check(game.companions.size() == 2 and game.companions[0].health == 3 and game.companions[1].health == 3, "Recatch restores two fresh companions")
	var previous = game.companions[0]
	game._catch_capsule(EFFECT)
	await process_frame
	_check(game.companions.size() == 2 and game.companions[0] != previous, "Recatch with both alive also replaces")
	game._on_death_zone_body_entered(ball)
	_check(game.companions.is_empty(), "Last-ball loss clears companions")
	game._catch_capsule(EFFECT)
	game._clear_effects_and_capsules()
	await process_frame
	_check(game.companions.is_empty(), "Lifecycle clear cancels deferred spawn")
	game._catch_capsule(EFFECT)
	await process_frame
	for brick in game.bricks.get_children():
		brick.queue_free()
	game._on_ball_brick_broken(0)
	_check(game.companions.is_empty(), "Completion clears companions")
	game.free()
	await process_frame
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
