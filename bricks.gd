extends Node2D
signal capsule_dropped(at: Vector2)
signal brick_destroyed(at: Vector2)

const protoBrick := preload("res://brick.tscn")

# The layout currently on screen, set only by load_level(). main.gd decides which
# level is active, so Bricks has no default level and builds nothing on its own.
var level: Level
# Grid layout, editable in the Inspector. Sizes are in pixels, measured inside PlayArea.
@export var brick_size := Vector2(64, 32)
# Top-left corner of the first brick: x = 32 is the inside of the left wall,
# y = 128 leaves three empty brick rows under the top wall, Arkanoid style.
@export var grid_start := Vector2(32, 128)

# Validate before replacing the current layout; detach queued nodes immediately.
func load_level(next_level: Level) -> bool:
	if next_level == null:
		push_error("Bricks requires a Level resource.")
		return false
	var error := next_level.validation_error()
	if not error.is_empty():
		push_error(error)
		return false
	for brick in get_children():
		remove_child(brick)
		brick.queue_free()
	level = next_level
	for cell in level.brick_cells():
		var brick := protoBrick.instantiate()
		brick.configure(level.brick_symbol_at(cell))
		brick.position = grid_start + Vector2(cell) * brick_size
		brick.capsule_dropped.connect(func(at: Vector2): capsule_dropped.emit(at))
		brick.destroyed.connect(func(at: Vector2): brick_destroyed.emit(at))
		add_child(brick)
	return true
