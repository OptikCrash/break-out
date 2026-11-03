extends RefCounted

const DEFINITIONS = [
	preload("res://bricks/normal.tres"),
	preload("res://bricks/reinforced.tres"),
	preload("res://bricks/indestructible.tres"),
	preload("res://bricks/mystery.tres"),
]

static func definition_for_symbol(symbol: String) -> Resource:
	for definition in DEFINITIONS:
		if definition.grid_symbol == symbol:
			return definition
	return null

static func remaining_hit_points(hit_points: int, destructible: bool) -> int:
	if not destructible:
		return hit_points
	return maxi(0, hit_points - 1)
