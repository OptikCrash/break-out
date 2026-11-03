extends StaticBody2D

const BrickRules = preload("res://brick_rules.gd")

signal broken(points: int, at: Vector2)

signal capsule_dropped(at: Vector2)

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
func take_hit(breaker := false) -> bool:
	if is_queued_for_deletion() or not BrickRules.can_damage(definition, breaker):
		return false
	hit_points = BrickRules.remaining_hit_points(hit_points, definition.destructible)
	if hit_points == 0:
		queue_free()
		broken.emit(definition.points, $CollisionShape2D.global_position)
		if definition.drops_capsule:
			capsule_dropped.emit($CollisionShape2D.global_position)
		return true
	_update_color()
	return false

func _update_color() -> void:
	var rect := $CollisionShape2D/ColorRect
	if type_id == &"reinforced":
		rect.color = Color(0.45, 0.65, 0.9) if hit_points == 2 else Color(0.75, 0.85, 1.0)
	elif type_id == &"mystery":
		rect.color = Color(0.8, 0.7, 0.2)
	elif type_id == &"resistant":
		rect.color = Color(0.65, 0.3, 0.65)
	elif type_id == &"indestructible":
		rect.color = Color(0.45, 0.45, 0.45)
