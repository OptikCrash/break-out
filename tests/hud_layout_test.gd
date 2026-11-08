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
		for message in ["", "Game Over!", "You Win!"]:
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
		# The longest names in the pool, so a row can't spill past the panel.
		hud.update_effects({
			&"wide_paddle": {"definition": preload("res://effects/wide_paddle.tres"), "remaining": 10.0},
			&"shrink_paddle": {"definition": preload("res://effects/shrink_paddle.tres"), "remaining": 10.0},
		})
		await process_frame
		var panel: Control = hud.get_node("ActiveEffects")
		var panel_rect := panel.get_global_rect()
		if not root.get_visible_rect().encloses(panel_rect):
			push_error("ActiveEffects must stay inside the viewport at %s" % viewport_size)
			quit(1)
			return
		for label_name in ["Score", "Lives", "Level"]:
			if panel_rect.intersects(hud.get_node(label_name).get_global_rect()):
				push_error("ActiveEffects must not overlap the %s label" % label_name)
				quit(1)
				return
		hud.update_effects({})
	hud.free()
	quit(0)
