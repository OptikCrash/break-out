extends Resource

@export var id: StringName
@export var grid_symbol: String
@export var hit_points: int
@export var points: int
@export var drops_capsule := false
@export var destructible: bool = true

func validation_error() -> String:
	if id == &"" or grid_symbol.length() != 1:
		return "Brick definitions need a stable ID and one grid symbol."
	if destructible and (hit_points <= 0 or points < 0):
		return "Destructible bricks need positive hit points and nonnegative score."
	if not destructible and (hit_points != 0 or points != 0):
		return "Indestructible bricks must have zero hit points and score."
	return ""
