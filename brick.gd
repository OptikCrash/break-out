extends StaticBody2D

const BrickRules = preload("res://brick_rules.gd")

signal broken(points: int, at: Vector2)

signal capsule_dropped(at: Vector2)
# Presentation only (particles); score still travels through the ball's brick_broken.
signal destroyed(at: Vector2)

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
		destroyed.emit($CollisionShape2D.global_position)
		if definition.drops_capsule:
			capsule_dropped.emit($CollisionShape2D.global_position)
		return true
	_update_color()
	return false

func _update_color() -> void:
	var sprite: Sprite2D = $Sprite2D
	var damaged: bool = definition.destructible and hit_points < definition.hit_points
	if damaged and definition.damaged_texture:
		sprite.texture = definition.damaged_texture
	elif definition.texture:
		sprite.texture = definition.texture
