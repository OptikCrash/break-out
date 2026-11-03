extends RefCounted

# Append definitions here to extend the uniform capsule pool.
const DEFINITIONS = [
	preload("res://effects/wide_paddle.tres"),
	preload("res://effects/shrink_paddle.tres"),
	preload("res://effects/extra_life.tres"),
	preload("res://effects/slow_ball.tres"),
	preload("res://effects/speed_up_ball.tres"),
	preload("res://effects/multi_ball.tres"),
	preload("res://effects/breaker.tres"),
	preload("res://effects/sticky_paddle.tres"),
	preload("res://effects/blaster.tres"),
	preload("res://effects/force_field.tres"),
	preload("res://effects/companion_paddle.tres"),
]
const CAPSULE_SPEED := 240.0
var shot_time_left := 0.0
var active: Dictionary = {}

static func random_effect(rng: RandomNumberGenerator) -> Resource:
	return DEFINITIONS[rng.randi_range(0, DEFINITIONS.size() - 1)]

static func catch_points(effect: Resource) -> int:
	return 0 if effect.hazard else 25

# Charge state is separate from active timed effects. Power-ups never spend it.
static func negates_hazard(effect: Resource, charges: int) -> bool:
	return effect.hazard and charges > 0

static func charges_after_catch(effect: Resource, charges: int) -> int:
	if negates_hazard(effect, charges):
		return charges - 1
	return effect.hazard_charges if effect.hazard_charges > 0 else charges

static func split_velocities(velocity: Vector2, effect: Resource) -> Array[Vector2]:
	var angle := deg_to_rad(float(effect.split_angle_degrees))
	return [velocity.rotated(-angle), velocity.rotated(angle)]

func apply(effect: Resource) -> void:
	if effect.duration > 0.0:
		active[effect.id] = {"definition": effect, "remaining": effect.duration}

func advance(delta: float) -> void:
	shot_time_left = maxf(0.0, shot_time_left - delta)
	for id in active.keys():
		active[id].remaining = maxf(0.0, active[id].remaining - delta)
		if active[id].remaining == 0.0:
			active.erase(id)

func width_multiplier() -> float:
	var multiplier := 1.0
	for entry in active.values():
		multiplier *= entry.definition.paddle_width_multiplier
	return multiplier

func speed_multiplier() -> float:
	var multiplier := 1.0
	for entry in active.values():
		multiplier *= entry.definition.ball_speed_multiplier
	return multiplier

static func companion_health_after_hit(health: int) -> int:
	return maxi(0, health - 1)

static func companion_follow_x(current: float, target: float, speed: float, delta: float) -> float:
	return move_toward(current, target, speed * delta)

static func companion_clamp_x(center: float, bounds: Vector2, half_width: float) -> float:
	return clampf(center, bounds.x + half_width, bounds.y - half_width)

# A refresh extends duration without bypassing an existing shot cooldown.
func fire_blaster() -> bool:
	if not active.has(&"blaster") or shot_time_left > 0.0:
		return false
	shot_time_left = active[&"blaster"].definition.shot_cooldown
	return true
