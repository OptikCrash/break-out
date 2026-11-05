extends RefCounted

const DEFINITIONS = [
	preload("res://bricks/normal.tres"),
	preload("res://bricks/reinforced.tres"),
	preload("res://bricks/indestructible.tres"),
	preload("res://bricks/mystery.tres"),
	preload("res://bricks/resistant.tres"),
]

static func definition_for_symbol(symbol: String) -> Resource:
	for definition in DEFINITIONS:
		if definition.grid_symbol == symbol:
			return definition
	return null

# Breaker damage (Breaker balls and Blaster bolts) destroys any destructible brick
# in one hit, including multi-hit Reinforced bricks.
static func remaining_hit_points(hit_points: int, destructible: bool, breaker := false) -> int:
	if not destructible:
		return hit_points
	if breaker:
		return 0
	return maxi(0, hit_points - 1)

static func can_damage(definition: Resource, breaker: bool) -> bool:
	return definition.destructible and (not definition.requires_breaker or breaker)
