extends StaticBody2D

const BrickRules = preload("res://brick_rules.gd")

signal broken(points: int, at: Vector2)

signal capsule_dropped(at: Vector2)
# Presentation only (particles); score still travels through the ball's brick_broken.
signal destroyed(at: Vector2, color: Color)
# Presentation only: every contact on a live brick, broken or not, including
# Indestructible and Resistant bricks that ignore the damage. `away` points from
# the brick centre to the contact so sparks fly off the struck face.
signal struck(at: Vector2, away: Vector2, color: Color)

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
# `contact` is the global hit point; without one, sparks start at the centre.
func take_hit(breaker := false, contact := Vector2.INF) -> bool:
	if is_queued_for_deletion():
		return false
	var center: Vector2 = $CollisionShape2D.global_position
	var at: Vector2 = contact if contact.is_finite() else center
	struck.emit(at, (at - center).normalized(), definition.particle_color)
	if not BrickRules.can_damage(definition, breaker):
		return false
	hit_points = BrickRules.remaining_hit_points(hit_points, definition.destructible, breaker)
	if hit_points == 0:
		queue_free()
		broken.emit(definition.points, $CollisionShape2D.global_position)
		destroyed.emit($CollisionShape2D.global_position, definition.particle_color)
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
