extends Node2D
const protoBrick := preload("res://brick.tscn")

# Grid layout, editable in the Inspector. Sizes are in pixels, measured inside PlayArea.
@export var columns := 17
@export var rows := 5
@export var brick_size := Vector2(64, 32)
# Top-left corner of the first brick: x = 32 is the inside of the left wall,
# y = 128 leaves three empty brick rows under the top wall, Arkanoid style.
@export var grid_start := Vector2(32, 128)

func _ready() -> void:
	for row in rows:
		for col in columns:
			var brick := protoBrick.instantiate()
			# A brick's position is its top-left corner, so each one sits
			# exactly one brick width/height after the previous one (no gaps).
			brick.position = grid_start + Vector2(col * brick_size.x, row * brick_size.y)
			add_child(brick)
