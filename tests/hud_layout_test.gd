extends SceneTree

func _initialize() -> void:
	call_deferred("check_layout")

func check_layout() -> void:
	var hud = load("res://HUD.tscn").instantiate()
	root.add_child(hud)
	var label: Label = hud.get_node("MessageLabel")
	# CanvasLayer controls follow the viewport, including after a resize.
	for viewport_size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = viewport_size
		for message in ["", "Game Over!\nPress R to restart", "You Win!\nPress R to restart"]:
			label.text = message
			await process_frame
			var viewport_rect = root.get_visible_rect()
			if not label.get_global_rect().is_equal_approx(viewport_rect):
				push_error("MessageLabel must fill the viewport for " + message)
				quit(1)
				return
			if label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
				push_error("MessageLabel text must be centered on both axes")
				quit(1)
				return
	hud.free()
	quit(0)
