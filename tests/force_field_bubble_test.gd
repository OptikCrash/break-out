extends SceneTree

# The Force Field bubble: it mirrors main's charges, blocks hazard capsules on
# contact (before they reach the paddle), lets power-ups and balls through, follows
# the paddle width, and blinks on its last charge.
const FIELD = preload("res://effects/force_field.tres")
const SHRINK = preload("res://effects/shrink_paddle.tres")
const WIDE = preload("res://effects/wide_paddle.tres")
const BUBBLE = preload("res://force_field_bubble.tscn")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_bubble_state()
	await _check_real_capsules()
	_check_shapes_are_per_instance()
	quit(1 if failures else 0)

func _check_bubble_state() -> void:
	var game = _game()
	var bubble: Area2D = game.force_field
	_check(bubble.get_parent() == game.paddle, "The bubble is a child of the main paddle")
	_check(not bubble.visible and not bubble.is_blocking(), "No bubble without charges")
	game._catch_capsule(FIELD)
	_check(bubble.visible and bubble.charges == 3 and bubble.is_blocking(), "Catching Force Field forms the bubble")
	_check(not bubble.is_blinking(), "A full bubble does not blink")
	_check(_alpha_range(bubble) == Vector2(1.0, 1.0), "A full bubble stays solid")
	game._catch_capsule(SHRINK)
	game._catch_capsule(SHRINK)
	_check(bubble.charges == 1 and bubble.is_blinking(), "The last charge blinks")
	var alphas := _alpha_range(bubble)
	_check(is_equal_approx(alphas.x, bubble.BLINK_DIM_ALPHA) and alphas.y == 1.0, "Blinking alternates between dim and solid")
	game._catch_capsule(SHRINK)
	_check(bubble.charges == 0 and not bubble.is_blocking(), "The third blocked hazard spends the bubble")
	_check(bubble.visible, "A spent bubble plays its pop before hiding")
	bubble._process(bubble.POP_TIME + 0.01)
	_check(not bubble.visible, "The bubble hides once the pop finishes")
	game._catch_capsule(FIELD)
	game._on_death_zone_body_entered(game.ball)
	_check(bubble.charges == 0 and not bubble.is_blocking(), "Last-ball loss clears the bubble with the charges")

	game._catch_capsule(FIELD)
	var shape: ConvexPolygonShape2D = bubble.get_node("CollisionShape2D").shape
	_check(shape.points == bubble.points, "The hitbox is exactly the drawn outline")
	var narrow := _width(shape)
	game._catch_capsule(WIDE)
	game._physics_process(0.0)
	_check(is_equal_approx(_width(shape) - narrow, game.paddle.half_width * 2.0 - 128.0), "The hitbox widens with Wide Paddle")
	game.free()

func _check_real_capsules() -> void:
	var game = _game()
	var play_area: Node2D = game.get_node("PlayArea")
	var above_paddle: Vector2 = game.paddle.global_position + Vector2(0, -200)
	game._catch_capsule(FIELD)
	var blocked := []
	game.force_field.hazard_blocked.connect(func(_effect: Resource, at: Vector2): blocked.append(at))

	_check(await _drop(game, SHRINK, above_paddle), "A hazard falling into the bubble is removed")
	_check(blocked.size() == 1 and game.force_field_charges == 2, "The bubble spends one charge on contact")
	_check(not game.effects.active.has(SHRINK.id), "A blocked hazard applies no effect")
	var paddle_top: float = game.paddle.global_position.y - 8.0
	var capsule_half: float = 10.0
	_check(blocked.size() == 1 and blocked[0].y + capsule_half < paddle_top, "The hazard is stopped before it touches the paddle")

	var power_up_gone: bool = await _drop(game, WIDE, above_paddle)
	_check(power_up_gone and game.effects.active.has(WIDE.id), "A power-up passes through and the paddle collects it")
	_check(game.force_field_charges == 2, "Power-ups do not spend charges")

	game.force_field_charges = 0
	game.force_field._process(1.0)
	game.effects.active.clear()
	await _drop(game, SHRINK, above_paddle)
	_check(game.effects.active.has(SHRINK.id), "Without charges, a hazard reaches the paddle and applies")
	_check(play_area.get_children().filter(func(n): return n.is_in_group("capsule")).is_empty(), "No capsule is left behind")
	game.free()

func _check_shapes_are_per_instance() -> void:
	var first: Area2D = BUBBLE.instantiate()
	var second: Area2D = BUBBLE.instantiate()
	root.add_child(first)
	root.add_child(second)
	first.set_half_width(96.0)
	var a: Shape2D = first.get_node("CollisionShape2D").shape
	var b: Shape2D = second.get_node("CollisionShape2D").shape
	_check(a != b and _width(b) == 2.0 * (64.0 + first.MARGIN_X), "Resizing one bubble never resizes another")
	first.free()
	second.free()

# Drops a capsule from `from` and runs real physics until it is caught or blocked.
# Returns true once the capsule is gone, false if it was still falling at the bound.
func _drop(game: Node, effect: Resource, from: Vector2) -> bool:
	game._add_capsule(from)
	var capsules: Array = get_nodes_in_group("capsule").filter(func(n): return not n.is_queued_for_deletion())
	var capsule = capsules[-1]
	capsule.effect = effect
	for step in 240:
		if not is_instance_valid(capsule) or capsule.is_queued_for_deletion():
			break
		await physics_frame
	var gone: bool = not is_instance_valid(capsule) or capsule.is_queued_for_deletion()
	await process_frame
	return gone

func _game() -> Node:
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.ball.set_physics_process(false)
	return game

func _alpha_range(bubble: Area2D) -> Vector2:
	var low := 1.0
	var high := 0.0
	for step in 30:
		bubble._process(1.0 / 60.0)
		low = minf(low, bubble.current_alpha())
		high = maxf(high, bubble.current_alpha())
	return Vector2(low, high)

func _width(shape: ConvexPolygonShape2D) -> float:
	var xs := Array(shape.points).map(func(p: Vector2): return p.x)
	return xs.max() - xs.min()

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
