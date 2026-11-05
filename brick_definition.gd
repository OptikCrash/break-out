extends Resource

@export var id: StringName
@export var grid_symbol: String
@export var hit_points: int
@export var points: int
@export var drops_capsule := false
@export var requires_breaker := false
@export var counts_for_completion := true
@export var destructible: bool = true
@export var texture: Texture2D
# Shown once a multi-hit brick has taken damage; empty keeps `texture`.
@export var damaged_texture: Texture2D
# Tint for hit sparks and the destruction burst, matched by eye to `texture`.
@export var particle_color := Color.WHITE

func validation_error() -> String:
	if id == &"" or grid_symbol.length() != 1:
		return "Brick definitions need a stable ID and one grid symbol."
	if destructible and (hit_points <= 0 or points < 0):
		return "Destructible bricks need positive hit points and nonnegative score."
	if not destructible and (hit_points != 0 or points != 0):
		return "Indestructible bricks must have zero hit points and score."
	if requires_breaker and not destructible:
		return "Breaker-only bricks must be destructible."
	if not destructible and counts_for_completion:
		return "Indestructible bricks cannot count toward completion."
	return ""
