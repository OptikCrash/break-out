extends StaticBody2D

const BrickRules = preload("res://brick_rules.gd")

var definition: Resource = preload("res://bricks/normal.tres")
var hit_points: int = 1
var type_id: StringName:
	get:
		return definition.id

func configure(symbol: String) -> void:
	definition = BrickRules.definition_for_symbol(symbol)
	hit_points = definition.hit_points

func _ready() -> void:
	_update_color()

# Returns true only on destruction. Queued colliders can still be hit this frame.
func take_hit() -> bool:
	if is_queued_for_deletion() or not definition.destructible:
		return false
	hit_points = BrickRules.remaining_hit_points(hit_points, definition.destructible)
	if hit_points == 0:
		queue_free()
		return true
	_update_color()
	return false

func _update_color() -> void:
	var rect := $CollisionShape2D/ColorRect
	if type_id == &"reinforced":
		rect.color = Color(0.45, 0.65, 0.9) if hit_points == 2 else Color(0.75, 0.85, 1.0)
	elif type_id == &"indestructible":
		rect.color = Color(0.45, 0.45, 0.45)
