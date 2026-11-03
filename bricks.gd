extends Node2D
const protoBrick := preload("res://brick.tscn")

# Grid layout, editable in the Inspector. Sizes are in pixels, measured inside PlayArea.
@export var level: Level = preload("res://levels/level_1.tres")
@export var brick_size := Vector2(64, 32)
# Top-left corner of the first brick: x = 32 is the inside of the left wall,
# y = 128 leaves three empty brick rows under the top wall, Arkanoid style.
@export var grid_start := Vector2(32, 128)

func _ready() -> void:
	if level == null:
		push_error("Bricks requires a Level resource.")
		return
	for cell in level.brick_cells():
		var brick := protoBrick.instantiate()
		# All occupied cells use today's normal brick until brick types are added.
		brick.position = grid_start + Vector2(cell) * brick_size
		add_child(brick)
