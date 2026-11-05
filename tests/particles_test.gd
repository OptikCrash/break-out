extends SceneTree

# Presentation particles: hit sparks on every live-brick contact, tinted
# destruction bursts, and the Blaster bolt's pulsing glow.
const BrickDamage = preload("res://brick_damage.gd")
const SPARKS = preload("res://brick_sparks.tscn")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_sparks_and_tints()
	await _check_contact_from_real_bolt()
	_check_bolt_glow_pulses()
	await _check_sparks_free_themselves()
	quit(1 if failures else 0)

func _check_sparks_and_tints() -> void:
	var level := Level.new()
	# The final Normal brick keeps the level from completing during the test.
	level.grid = "#xor#"
	var game = preload("res://main.tscn").instantiate()
	game.levels.assign([level])
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var report: Callable = game.ball.brick_broken.emit
	var bricks: Array = game.bricks.get_children()
	var normal_center: Vector2 = bricks[0].get_node("CollisionShape2D").global_position
	var contact := normal_center + Vector2(0, 16)

	# Repeat the hit before yielding a frame: a queued brick must not spark twice.
	BrickDamage.hit(bricks[0], false, report, contact)
	BrickDamage.hit(bricks[0], false, report, contact)
	var sparks := _live("brick_sparks")
	_check(sparks.size() == 1, "A destroying hit sparks once, and a queued brick never sparks")
	_check(sparks[0].global_position == contact, "Sparks start at the contact point")
	_check(is_equal_approx(sparks[0].rotation, Vector2.DOWN.angle()), "Sparks fly off the struck face")
	_check(sparks[0].color == bricks[0].definition.particle_color.lerp(Color.WHITE, sparks[0].tint_whiteness), "Sparks take the brick's particle colour, heated towards white")
	_check(sparks[0].get_parent() == game.get_node("PlayArea"), "Sparks live outside Bricks")
	var bursts := _live("brick_burst")
	_check(bursts.size() == 1 and bursts[0].color == bricks[0].definition.particle_color, "Burst takes the brick's particle colour")
	var flash: CPUParticles2D = bursts[0].get_node("Flash")
	_check(flash.emitting and flash.lifetime <= bursts[0].lifetime, "Burst flash fires with the burst and cannot outlive it")

	BrickDamage.hit(bricks[1], false, report)
	_check(_live("brick_sparks").size() == 2 and _live("brick_burst").size() == 1, "Damaging Reinforced sparks without bursting")
	_check(_live("brick_sparks")[1].spread == 180.0, "A hit without a contact point sprays all round")
	BrickDamage.hit(bricks[2], true, report)
	_check(_live("brick_sparks").size() == 3, "Indestructible sparks even though it takes no damage")
	BrickDamage.hit(bricks[3], false, report)
	_check(_live("brick_sparks").size() == 4 and _live("brick_burst").size() == 1, "Resistant without Breaker sparks but survives")
	_check(game.score == bricks[0].definition.points, "Sparks never change scoring")
	for definition in [bricks[0], bricks[1], bricks[2], bricks[3]].map(func(brick): return brick.definition):
		_check(definition.particle_color != Color.WHITE, "%s has its own particle colour" % definition.id)
	game.free()

func _check_contact_from_real_bolt() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var brick = preload("res://brick.tscn").instantiate()
	brick.position = Vector2(400, 300)
	world.add_child(brick)
	var hits: Array = []
	brick.struck.connect(func(at: Vector2, away: Vector2, _color: Color): hits.append([at, away]))
	var bolt = preload("res://blaster_bolt.tscn").instantiate()
	bolt.position = Vector2(432, 400)
	world.add_child(bolt)
	bolt.set_physics_process(false)
	await physics_frame
	await physics_frame
	bolt._physics_process(0.1)
	var bottom: float = brick.get_node("CollisionShape2D").global_position.y + 16.0
	_check(hits.size() == 1, "A real bolt collision strikes the brick once")
	if hits.size() == 1:
		_check(absf(hits[0][0].y - bottom) < 2.0, "Bolt sparks start on the brick's bottom face")
		_check(hits[0][1].y > 0.0, "Bolt sparks point down, away from the brick")
	world.free()

func _check_bolt_glow_pulses() -> void:
	var bolt = preload("res://blaster_bolt.tscn").instantiate()
	root.add_child(bolt)
	bolt.set_physics_process(false)
	bolt.set_process(false)
	var glow: Sprite2D = bolt.get_node("Glow")
	_check(glow.material is CanvasItemMaterial and glow.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Glow is additive")
	_check(bolt.get_node("Trail").emitting, "Trail emits while the bolt flies")
	var scales: Array = []
	var alphas: Array = []
	for step in 8:
		bolt._process(1.0 / 60.0)
		scales.append(glow.scale.x)
		alphas.append(glow.modulate.a)
	_check(scales.max() - scales.min() > 0.05, "Glow size pulses over time")
	_check(alphas.max() - alphas.min() > 0.1, "Glow brightness pulses with its size")
	var low: float = bolt.glow_scale.x * (1.0 - bolt.PULSE_DEPTH) - 0.001
	var high: float = bolt.glow_scale.x * (1.0 + bolt.PULSE_DEPTH) + 0.001
	_check(scales.min() >= low and scales.max() <= high, "Pulse stays within its depth")
	_check(not bolt.find_children("*", "Light2D"), "No Light2D: the first one stalls shader compilation")
	bolt.free()

func _check_sparks_free_themselves() -> void:
	var sparks = SPARKS.instantiate()
	root.add_child(sparks)
	_check(sparks.emitting and sparks.one_shot, "Sparks are a one-shot emission")
	await create_timer(sparks.lifetime + 0.5).timeout
	_check(not is_instance_valid(sparks), "Sparks free themselves once finished")

func _live(group: StringName) -> Array:
	return get_nodes_in_group(group).filter(func(node): return not node.is_queued_for_deletion())

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
