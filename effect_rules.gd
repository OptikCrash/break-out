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
	preload("res://effects/satellite_shield.tres"),
	preload("res://effects/force_field.tres"),
]
const CAPSULE_SPEED := 240.0
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

# Re-catching Satellite Shield resets the orb count instead of adding to it.
static func orbs_after_catch(current: int, effect: Resource) -> int:
	return effect.orbs if effect.orbs > 0 else current

# One orb per press, and never on the press that launches a resting ball:
# launch and power_action share a key.
static func can_launch_orb(orbs: int, ball_waiting_to_launch: bool) -> bool:
	return orbs > 0 and not ball_waiting_to_launch

func apply(effect: Resource) -> void:
	if effect.duration > 0.0:
		active[effect.id] = {"definition": effect, "remaining": effect.duration}

func advance(delta: float) -> void:
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
