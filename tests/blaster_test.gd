extends SceneTree

const Blaster = preload("res://effects/blaster.tres")
const Rules = preload("res://effect_rules.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(Blaster.duration == 10.0 and Blaster.shot_cooldown == 0.3 and Blaster.bolt_speed == 1200.0, "Pin weapon tuning")
	var rules = Rules.new()
	_check(not rules.fire_blaster(), "Inactive weapon cannot fire")
	rules.apply(Blaster)
	_check(rules.fire_blaster(), "First shot is ready")
	rules.advance(0.15)
	_check(not rules.fire_blaster(), "No shot before cooldown")
	rules.apply(Blaster)
	_check(not rules.fire_blaster(), "Refresh does not bypass cooldown")
	rules.advance(0.15)
	_check(rules.fire_blaster(), "Shot after 0.3 seconds")
	rules.advance(10.0)
	_check(not rules.fire_blaster(), "Expiry prevents firing")
	for field in ["duration", "shot_cooldown", "bolt_speed"]:
		var invalid = Blaster.duplicate()
		invalid.set(field, 0.0)
		_check(not invalid.validation_error().is_empty(), "Reject missing weapon tuning")
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.ball.set_physics_process(false)
	game.paddle.set_physics_process(false)
	await _press()
	_check(get_nodes_in_group("blaster_bolt").is_empty(), "Inactive input spawns nothing")
	game._catch_capsule(preload("res://effects/force_field.tres"))
	game._catch_capsule(Blaster)
	_check(game.force_field_charges == 3, "Blaster pickup preserves Force Field charges")
	game._catch_capsule(preload("res://effects/sticky_paddle.tres"))
	game.ball.launched = true
	game.ball.velocity = Vector2(0, -550)
	game.ball.catch_on_paddle(0.5)
	game.ball.set_physics_process(true)
	await _press()
	game.ball.set_physics_process(false)
	var bolts := get_nodes_in_group("blaster_bolt")
	_check(bolts.size() == 1 and not game.ball.caught, "Same press fires and releases Sticky")
	_check(game.force_field_charges == 3, "Firing preserves Force Field charges")
	await _press()
	_check(get_nodes_in_group("blaster_bolt").size() == 1, "Early second press does not fire")
	# Route a real bolt collision through main's existing score/completion callback.
	var fired = bolts[0]
	fired.set_physics_process(false)
	var target = game.bricks.get_child(game.bricks.get_child_count() - 1)
	var before: int = game.score
	fired.global_position = target.get_node("CollisionShape2D").global_position + Vector2(0, 80)
	await physics_frame
	fired._physics_process(0.1)
	_check(target.is_queued_for_deletion() and game.score == before + 10, "Bolt reports brick score through main")
	game._clear_effects_and_capsules()
	_check(game.force_field_charges == 0, "Lifecycle clears Force Field alongside Blaster")
	await process_frame
	_check(get_nodes_in_group("blaster_bolt").is_empty() and game.effects.shot_time_left == 0.0, "Lifecycle clears bolts and cooldown")
	game.free()
	await _collision()
	quit(1 if failures else 0)

func _press() -> void:
	Input.action_press("power_action")
	await physics_frame
	await physics_frame
	Input.action_release("power_action")
	await physics_frame

func _collision() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var brick = preload("res://brick.tscn").instantiate()
	brick.configure("r")
	brick.position = Vector2(400, 300)
	world.add_child(brick)
	var bolt = preload("res://blaster_bolt.tscn").instantiate()
	bolt.position = Vector2(432, 400)
	world.add_child(bolt)
	bolt.set_physics_process(false)
	var awards: Array[int] = []
	bolt.brick_broken.connect(func(points: int): awards.append(points))
	await physics_frame
	await physics_frame
	bolt._physics_process(0.01)
	_check(bolt.position == Vector2(432, 388), "Fixed upward speed is 1200 pixels per second")
	bolt._physics_process(0.1)
	_check(brick.is_queued_for_deletion() and bolt.is_queued_for_deletion() and awards == [50], "Swept bolt destroys Resistant and scores fifty")
	bolt._physics_process(0.1)
	_check(awards == [50], "Repeated same-frame collision cannot score twice")
	var escaped = preload("res://blaster_bolt.tscn").instantiate()
	escaped.position = Vector2(700, 1)
	world.add_child(escaped)
	escaped.set_physics_process(false)
	escaped._physics_process(0.01)
	_check(escaped.is_queued_for_deletion(), "Bolt leaving top is freed")
	world.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
