extends RefCounted

# Append definitions here to extend the uniform capsule pool.
const DEFINITIONS = [
	preload("res://effects/wide_paddle.tres"),
	preload("res://effects/shrink_paddle.tres"),
	preload("res://effects/extra_life.tres"),
	preload("res://effects/multi_ball.tres"),
]
const CAPSULE_SPEED := 240.0
var active: Dictionary = {}

static func random_effect(rng: RandomNumberGenerator) -> Resource:
	return DEFINITIONS[rng.randi_range(0, DEFINITIONS.size() - 1)]

static func catch_points(effect: Resource) -> int:
	return 0 if effect.hazard else 25

static func split_velocities(velocity: Vector2, effect: Resource) -> Array[Vector2]:
	var angle := deg_to_rad(float(effect.split_angle_degrees))
	return [velocity.rotated(-angle), velocity.rotated(angle)]

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
