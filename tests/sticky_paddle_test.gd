extends SceneTree

const Rules = preload("res://ball_rules.gd")
const Sticky = preload("res://effects/sticky_paddle.tres")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	seed(54)
	var expected := Rules.paddle_direction(0.0) * 550.0
	seed(54)
	_check(Rules.sticky_release(0.0, 550.0, 0.0).is_equal_approx(expected), "Stationary center release reuses bounce randomness")
	var base := Rules.paddle_direction(0.5) * 550.0
	_check(Rules.sticky_release(0.5, 550.0, 1000.0).is_equal_approx(Vector2(1, -1).normalized() * 550.0), "Rightward momentum reaches the 45 degree limit")
	_check(Rules.sticky_release(0.5, 550.0, 400.0).is_equal_approx((base + Vector2(100, 0)).normalized() * 550.0), "Transfer exactly 25 percent before normalization")
	_check(Rules.sticky_release(0.5, 550.0, -1000.0).is_equal_approx((base - Vector2(250, 0)).normalized() * 550.0), "Leftward momentum is signed")
	_check(Rules.sticky_release(0.5, 550.0, 10000.0).is_equal_approx(Vector2(1, -1).normalized() * 550.0), "Momentum is capped at held speed")
	_check(Rules.sticky_release(-0.5, 550.0, -10000.0).is_equal_approx(Vector2(-1, -1).normalized() * 550.0), "Leftward momentum uses the same cap and angle limit")
	_check(Rules.sticky_release(0.5, 0.0, 1000.0) == Vector2.ZERO, "Zero held speed cannot gain speed from paddle momentum")
	for offset in [-1.0, 1.0]:
		for momentum in [-100000.0, 100000.0]:
			var edge := Rules.sticky_release(offset, 550.0, momentum)
			_check(absf(edge.x) <= -edge.y + 0.001, "Edge release stays at least 45 degrees above horizontal")
			_check(is_equal_approx(edge.length(), 550.0), "Edge clamp preserves held speed")
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.paddle.set_physics_process(false)
	var ball = game.ball
	ball.set_physics_process(false)
	game._catch_capsule(Sticky)
	_check(game.score == 25 and ball.sticky_active, "Pickup scores and enables sticky")
	# Allow the physics server to register the paddle before testing real contact.
	await physics_frame
	ball.global_position = game.paddle.global_position + Vector2(32, -30)
	ball.launched = true
	ball.velocity = Vector2(0, 550)
	ball._physics_process(0.03)
	_check(game.can_pause(), "Caught ball remains in play for pause")
	_check(ball.caught and ball.velocity == Vector2.ZERO, "Actual paddle touch catches instead of bouncing")
	_check(ball.position.is_equal_approx(game.paddle.position + Vector2(0, -24)), "Catch immediately centers")
	_check(is_equal_approx(ball.catch_offset, 0.5), "Original catch offset survives visual centering")
	game.paddle.position.x += 20
	ball._physics_process(0.0)
	_check(ball.position.is_equal_approx(game.paddle.position + Vector2(0, -24)), "Caught ball follows paddle")
	ball.catch_offset = 0.0
	seed(99)
	expected = Rules.paddle_direction(0.0) * 550.0
	seed(99)
	Input.action_press("power_action")
	ball.set_physics_process(true)
	await physics_frame
	await physics_frame
	ball.set_physics_process(false)
	Input.action_release("power_action")
	_check(not ball.caught and ball.launched and ball.velocity.is_equal_approx(expected), "Power action releases with normal center bounce")
	ball.velocity = Vector2(0, 550)
	ball.catch_on_paddle(0.5)
	game.paddle.recent_velocity_x = 1000.0
	ball.release_catch()
	_check(ball.velocity.is_equal_approx(Vector2(1, -1).normalized() * 550.0), "Moving paddle changes trajectory while preserving speed")
	# Include both speed capsules and their overlap: steering must preserve each
	# effective speed, even when the paddle reverses between catches.
	for multiplier in [1.0, 0.75, 1.5, 1.125]:
		ball.set_speed_multiplier(multiplier)
		for iteration in range(20):
			game.paddle.recent_velocity_x = 10000.0 if iteration % 2 == 0 else -10000.0
			ball.catch_on_paddle(0.5)
			ball.release_catch()
			_check(is_equal_approx(ball.velocity.length(), 550.0 * multiplier), "Repeated moving catches preserve active speed multiplier")
	ball.set_speed_multiplier(1.0)
	game.paddle.recent_velocity_x = 1000.0
	var released_speed: float = ball.velocity.length()
	ball.catch_on_paddle(0.5)
	game._catch_capsule(preload("res://effects/slow_ball.tres"))
	_check(is_equal_approx(ball.caught_speed, released_speed * 0.75), "Slow scales held speed exactly")
	game._physics_process(9.0)
	game._catch_capsule(Sticky)
	_check(game.effects.active[Sticky.id].remaining == 10.0 and ball.caught, "Refresh preserves catch and resets ten seconds")
	game._physics_process(9.0)
	_check(ball.caught, "Catch persists before expiry")
	_check(is_equal_approx(ball.caught_speed, released_speed), "Slow expiry restores held speed before release")
	expected = Rules.sticky_release(0.5, released_speed, 1000.0)
	game._physics_process(1.0)
	_check(ball.velocity.is_equal_approx(expected), "Expiry uses same offset and momentum formula")
	_check(not ball.caught and not ball.sticky_active and ball.velocity.y < 0, "Expiry releases immediately")

	# A stationary normal bounce isolates Sticky from the independent Paddle Boost.
	game.paddle.recent_velocity_x = 0.0
	ball.set_speed_multiplier(1.5)
	ball.global_position = game.paddle.global_position + Vector2(32, -30)
	ball.velocity = Vector2(0, ball.velocity.length())
	await physics_frame
	ball._physics_process(0.03)
	_check(not ball.caught and ball.velocity.y < 0, "Expired sticky returns to normal paddle bounce")
	_check(is_equal_approx(ball.velocity.length(), ball.speed * ball.speed_multiplier), "Normal bounce after expiry has no residual sticky speed")
	ball.set_speed_multiplier(1.0)

	# New balls inherit sticky; losing another ball preserves a held one.
	game._catch_capsule(Sticky)
	var second = game.add_ball()
	second.set_physics_process(false)
	_check(second.sticky_active, "New balls inherit sticky")
	ball.catch_on_paddle(0.5)
	game._on_death_zone_body_entered(second)
	_check(ball.caught and ball.sticky_active, "Earlier ball loss preserves sticky catch")
	# One physical binding must release an actually caught ball, without relaunching.
	_check(ball.caught, "Shared press begins with a caught ball")
	game.paddle.recent_velocity_x = 0.0
	await physics_frame
	var press := InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	ball.set_physics_process(true)
	await physics_frame
	await physics_frame
	ball.set_physics_process(false)
	press.pressed = false
	Input.parse_input_event(press)
	_check(not ball.caught and ball.velocity.is_equal_approx(base), "Shared Space press releases at catch offset instead of fresh launch")
	await physics_frame
	# Fresh launch uses launch only, even with sticky enabled.
	game._catch_capsule(Sticky)
	ball.reset()
	Input.action_press("launch")
	Input.action_press("power_action")
	ball.set_physics_process(true)
	await physics_frame
	await physics_frame
	ball.set_physics_process(false)
	Input.action_release("launch")
	Input.action_release("power_action")
	_check(ball.launched and not ball.caught and is_equal_approx(ball.velocity.length(), 550.0), "Shared press launches resting ball normally")
	ball.catch_on_paddle(0.5)
	ball.reset()
	_check(not ball.caught and ball.velocity == Vector2.ZERO, "Reset clears catch")
	await physics_frame
	game.paddle.following_mouse = true
	game.paddle.mouse_x = game.paddle.global_position.x + 10.0
	game.paddle._physics_process(1.0 / 60.0)
	_check(absf(game.paddle.recent_velocity_x - 600.0) < 0.01, "Recent movement measures actual mouse travel per second")
	await physics_frame
	game.paddle._physics_process(1.0 / 60.0)
	_check(is_zero_approx(game.paddle.recent_velocity_x), "Stationary step clears stale momentum")
	# Multi-ball must not turn a caught source into motionless launched copies.
	ball.launched = true
	ball.velocity = Vector2(0, -550)
	ball.catch_on_paddle(0.5)
	game._catch_capsule(preload("res://effects/multi_ball.tres"))
	await process_frame
	_check(game.get_balls().size() == 3, "Caught source splits into three balls")
	game.paddle.recent_velocity_x = 0.0
	for copy in game.get_balls():
		copy.set_physics_process(false)
		_check(copy.caught and copy.catch_offset == 0.5 and is_equal_approx(copy.caught_speed, 550.0), "Split copies retain catch offset and held speed")
	game._physics_process(10.0)
	var released = game.get_balls()
	for index in range(released.size()):
		var copy = released[index]
		var angle := 0.0 if index == 0 else deg_to_rad(-20.0 if index == 1 else 20.0)
		_check(not copy.caught and copy.velocity.is_equal_approx(base.rotated(angle)), "Expiry applies the authored split angle to each caught copy")
		_check(is_equal_approx(copy.velocity.length(), 550.0), "Split release preserves held speed")
		_check(copy.release_rotation == 0.0, "Split rotation is consumed on release")
		for other in released.slice(index + 1):
			_check(not copy.velocity.is_equal_approx(other.velocity), "Released split trajectories are pairwise different")
		copy.catch_on_paddle(0.5)
		copy.release_catch()
		_check(copy.velocity.is_equal_approx(base), "Later catches do not reuse the split angle")
	ball.release_rotation = 0.25
	ball.reset()
	_check(ball.release_rotation == 0.0, "Reset clears pending split rotation")
	game.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
