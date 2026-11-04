extends RefCounted

const BREAKER_DURATION := 10.0
const BOOST_VELOCITY_FACTOR := 0.25
const BOOST_CAP := 550.0
const BOOST_DURATION := 3.0

static func boosted_total(current: float, paddle_velocity: float) -> float:
	return minf(BOOST_CAP, current + absf(paddle_velocity) * BOOST_VELOCITY_FACTOR)

static func tick_boost(current: float, rate: float, delta: float) -> float:
	return maxf(0.0, current - rate * delta)

static func changed_multiplier_speed(current: float, boost: float, old: float, new: float) -> float:
	return maxf(0.0, current - boost) * new / old + boost


static func tick_breaker(time_left: float, delta: float) -> float:
	return maxf(0.0, time_left - delta)


static func launch_direction() -> Vector2:
	var lean := randf_range(-0.3, 0.3)
	# The random range includes zero; even that sample must avoid a vertical loop.
	return direction_with_lean(lean)

static func direction_with_lean(lean: float) -> Vector2:
	if lean == 0.0:
		lean = 0.3
	return Vector2(lean, -1.0).normalized()

static func paddle_direction(x_dir: float) -> Vector2:
	if x_dir == 0.0:
		return launch_direction()
	return Vector2(x_dir, -1.0).normalized()

# Momentum steers the release; normalization prevents repeated catches adding speed.
static func sticky_release(offset: float, held_speed: float, paddle_velocity: float) -> Vector2:
	var direction := paddle_direction(offset)
	if held_speed <= 0.0:
		return Vector2.ZERO
	direction.x += clampf(paddle_velocity * 0.25 / held_speed, -1.0, 1.0)
	# At least 45 degrees above horizontal, even at an edge with mouse momentum.
	direction.x = clampf(direction.x, direction.y, -direction.y)
	return direction.normalized() * held_speed
