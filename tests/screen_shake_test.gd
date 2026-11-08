extends SceneTree

const ScreenShake = preload("res://screen_shake.gd")
const BrickDamage = preload("res://brick_damage.gd")
const BURST = preload("res://brick_burst.tscn")
const FIELD = preload("res://effects/force_field.tres")
const SHRINK = preload("res://effects/shrink_paddle.tres")
const WIDE = preload("res://effects/wide_paddle.tres")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_shake_utility()
	_check_shake_triggers()
	_check_brick_bursts()
	await _check_burst_frees_itself()
	quit(1 if failures else 0)

func _check_shake_utility() -> void:
	var camera = ScreenShake.new()
	root.add_child(camera)
	camera.set_process(false)
	_check(camera.offset == Vector2.ZERO, "Camera rests at zero offset")
	camera.shake(10.0, 0.4)
	camera.advance(0.1)
	var first: Vector2 = camera.offset
	_check(first != Vector2.ZERO and absf(first.x) <= 7.5 and absf(first.y) <= 7.5, "Shake offset decays linearly from strength")
	camera.shake(2.0, 1.0)
	_check(camera.duration == 0.4, "Weaker shake does not cut a stronger one short")
	camera.advance(0.31)
	_check(camera.offset == Vector2.ZERO and camera.current_strength() == 0.0, "Offset returns exactly to zero after the duration")
	camera.advance(1.0)
	_check(camera.offset == Vector2.ZERO, "Offset stays at rest afterwards")
	camera.free()

func _check_shake_triggers() -> void:
	var game = preload("res://main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var camera = game.screen_shake
	var play_area_position: Vector2 = game.get_node("PlayArea").position
	_check(camera is Camera2D and camera.offset == Vector2.ZERO, "Main view is unshifted at rest")
	_check(game.get_canvas_transform() == Transform2D.IDENTITY, "Camera at rest leaves the canvas transform unchanged")
	game._catch_capsule(WIDE)
	_check(camera.time_left == 0.0, "Power-up catch does not shake")
	game._catch_capsule(FIELD)
	game._catch_capsule(SHRINK)
	_check(camera.time_left == 0.0, "Hazard negated by Force Field does not shake")
	game._clear_effects_and_capsules()
	game._catch_capsule(SHRINK)
	_check(camera.time_left == game.HAZARD_SHAKE.y, "Applied hazard shakes")
	camera.advance(1.0)
	camera.shake(0.0, 0.0)
	var second = game.add_ball()
	game._on_death_zone_body_entered(second)
	_check(camera.time_left == 0.0 and game.lives == 3, "Losing a ball that is not the last does not shake")
	game._on_death_zone_body_entered(game.ball)
	_check(game.lives == 2 and camera.time_left == game.LIFE_LOST_SHAKE.y, "Life loss shakes")
	camera.advance(0.1)
	_check(game.get_node("PlayArea").position == play_area_position, "Shake leaves PlayArea and its bodies in place")
	game.free()

func _check_brick_bursts() -> void:
	var level := Level.new()
	# The final Normal brick keeps the level from completing during the test.
	level.grid = "#x?ro#"
	var game = preload("res://main.tscn").instantiate()
	game.levels.assign([level])
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var report: Callable = game.ball.brick_broken.emit
	var bricks: Array = game.bricks.get_children()
	_check(_bursts().is_empty(), "No bursts before any break")
	# Repeat the hit before yielding a frame: a queued brick must not burst twice.
	BrickDamage.hit(bricks[0], false, report)
	BrickDamage.hit(bricks[0], false, report)
	_check(_bursts().size() == 1, "Normal break spawns exactly one burst")
	var burst = _bursts()[0]
	_check(burst is CPUParticles2D and burst.one_shot and burst.emitting, "Burst is a one-shot CPUParticles2D")
	_check(burst.global_position == bricks[0].get_node("CollisionShape2D").global_position, "Burst sits at the brick centre")
	_check(burst.get_parent() == game.get_node("PlayArea"), "Burst lives outside Bricks")
	BrickDamage.hit(bricks[1], false, report)
	_check(_bursts().size() == 1, "Damaging Reinforced without breaking does not burst")
	BrickDamage.hit(bricks[1], false, report)
	_check(_bursts().size() == 2, "Reinforced break bursts")
	BrickDamage.hit(bricks[2], false, report)
	_check(_bursts().size() == 3, "Mystery break bursts")
	BrickDamage.hit(bricks[3], false, report)
	_check(_bursts().size() == 3, "Resistant without Breaker does not burst")
	BrickDamage.hit(bricks[3], true, report)
	_check(_bursts().size() == 4, "Resistant break with Breaker bursts")
	BrickDamage.hit(bricks[4], true, report)
	_check(_bursts().size() == 4, "Indestructible never bursts")
	var expected := 0
	for index in 4:
		expected += bricks[index].definition.points
	_check(game.score == expected, "Each break scores once through brick_broken")
	game.free()

func _check_burst_frees_itself() -> void:
	var burst = BURST.instantiate()
	root.add_child(burst)
	_check(burst.emitting, "Burst starts emitting on entering the tree")
	await create_timer(burst.lifetime + 0.5).timeout
	_check(not is_instance_valid(burst), "Burst frees itself once finished")

func _bursts() -> Array:
	return get_nodes_in_group("brick_burst").filter(func(node): return not node.is_queued_for_deletion())

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
