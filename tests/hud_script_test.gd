extends SceneTree

func _initialize() -> void:
	call_deferred("check_script")

func check_script() -> void:
	# A bare HUD.tscn instance must carry hud.gd itself, not rely on main.tscn.
	var hud = load("res://HUD.tscn").instantiate()
	root.add_child(hud)
	if not hud.has_method("update_score"):
		push_error("HUD.tscn root must have hud.gd attached")
		quit(1)
		return
	hud.update_lives(2)
	hud.update_score(40)
	hud.update_message("Paused")
	if hud.get_node("Lives").text != "Lives: 2" or hud.get_node("Score").text != "Score: 40" or hud.get_node("MessageLabel").text != "Paused":
		push_error("HUD update methods must write to their labels")
		quit(1)
		return
	hud.free()

	# main.tscn's Hud instance must not override the script on top of the scene.
	var state: SceneState = load("res://main.tscn").get_state()
	for i in state.get_node_count():
		if state.get_node_name(i) != "Hud":
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == "script":
				push_error("main.tscn Hud instance must not override its script")
				quit(1)
				return
	quit(0)
