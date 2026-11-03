extends Node2D

func _ready() -> void:
	# Relative travel keeps the popup anchored to the event position in world space.
	var tween := create_tween().set_parallel(true)
	tween.tween_property($Label, "position:y", $Label.position.y - 64.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(queue_free)
