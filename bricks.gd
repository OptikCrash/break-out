extends Node2D
const protoBrick := preload("res://brick.tscn")

func _ready() -> void:
	for a in 7:
		for b in 2:
			var brick := protoBrick.instantiate()
			brick.position = Vector2((a + 1) * 100 , (b + 1) * 110)
			add_child(brick)
