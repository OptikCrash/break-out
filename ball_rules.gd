extends RefCounted

const BREAKER_DURATION := 10.0

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

# Add bounded paddle momentum without changing the existing bounce rule.
static func sticky_release(offset: float, held_speed: float, paddle_velocity: float) -> Vector2:
	var result := paddle_direction(offset) * held_speed
	result.x += clampf(paddle_velocity * 0.25, -held_speed, held_speed)
	return result
