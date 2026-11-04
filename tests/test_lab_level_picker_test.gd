extends SceneTree

# The Test Lab's level picker: buttons come from scanning levels/, clicking one
# swaps the layout through Bricks.load_level(), and bad files are rejected on
# screen without touching the current level or the lab's session rules.

const SCRATCH_DIR := "user://test_lab_level_picker/"

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var lab = load("res://devtools/test_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame

	# Discovery: one button per .tres in the real folder, nothing hardcoded.
	var expected: Array[String] = []
	for file in DirAccess.get_files_at("res://levels/"):
		if file.get_extension() == "tres":
			expected.append(file.get_basename())
	var buttons: Array = lab.level_buttons.get_children()
	var names := buttons.map(func(button): return button.text)
	_check(expected.size() >= 3 and names.size() == expected.size(), "One button per level file")
	for level_name in expected:
		_check(names.has(level_name), "Picker lists %s" % level_name)
	_check(names.slice(0, 3) == ["level_1", "level_2", "level_3"], "Levels are listed in order")
	for button in buttons:
		_check(button.focus_mode == Control.FOCUS_NONE, "%s can't take Space from launch" % button.text)

	# The picker sits in the left gutter, below Reset, inside the viewport.
	var picker: Control = lab.get_node("LabOverlay/LevelPicker")
	var reset_rect: Rect2 = lab.get_node("LabOverlay/ResetButton").get_global_rect()
	var picker_rect := picker.get_global_rect()
	_check(picker_rect.end.x <= 384.0 and picker_rect.position.x >= 0.0, "Picker stays out of the Play Area")
	_check(not picker_rect.intersects(reset_rect) and picker_rect.end.y <= 1080.0, "Picker fits below Reset")

	# Clicking swaps the layout through the real loading path.
	var level_2: Level = load("res://levels/level_2.tres")
	var old_brick = lab.bricks.get_child(0)
	lab.ball.launched = true
	lab.ball.velocity = Vector2(0, -300)
	lab.paddle.position.x += 200.0
	_button(lab, "level_2").pressed.emit()
	_check(lab.bricks.level == level_2, "Clicking level_2 loads it into Bricks")
	_check(lab.bricks.get_child_count() == level_2.brick_cells().size() and lab.bricks.get_child(0) != old_brick,
		"Old bricks are replaced by level_2's layout")
	_check(lab.bricks_left > 0, "Completion count matches the new layout")
	_check(lab.get_balls().size() == 1 and not lab.ball.launched and lab.paddle.position == lab.paddle_start,
		"The ball rests on the paddle for the new level")
	_check(lab.level_status.text.contains("level_2"), "Status names the level on screen")

	# Session rules survive a pick: no pause, infinite lives, Reset keeps the pick.
	_check(not lab.has_node("PauseScreen") and not lab.can_pause(), "Pause stays unreachable")
	lab.ball.launched = true
	lab._on_death_zone_body_entered(lab.ball)
	_check(lab.lives == 3 and not lab.reset_ready and lab.get_balls().size() == 1, "Lives stay infinite")
	lab.bricks.get_child(0).take_hit()
	lab.get_node("LabOverlay/ResetButton").pressed.emit()
	_check(lab.bricks.level == level_2 and lab.bricks.get_child_count() == level_2.brick_cells().size(),
		"Reset rebuilds the picked level, not level_1")

	# Bad files: listed (so they can be found and fixed) but rejected on click.
	DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)
	var bad := Level.new()
	bad.grid = "##\n#"
	ResourceSaver.save(bad, SCRATCH_DIR + "bad_rows.tres")
	ResourceSaver.save(Resource.new(), SCRATCH_DIR + "not_a_level.tres")
	var good := Level.new()
	good.grid = "#.#"
	ResourceSaver.save(good, SCRATCH_DIR + "level_10.tres")
	ResourceSaver.save(good, SCRATCH_DIR + "level_9.tres")
	lab.levels_dir = SCRATCH_DIR
	lab.refresh_level_picker()
	names = lab.level_buttons.get_children().map(func(button): return button.text)
	_check(names == ["bad_rows", "level_9", "level_10", "not_a_level"], "Rescan lists the new folder in natural order")
	var shown_brick = lab.bricks.get_child(0)
	_button(lab, "bad_rows").pressed.emit()
	_check(lab.bricks.level == level_2 and lab.bricks.get_child(0) == shown_brick, "Invalid grid keeps the current level")
	_check(lab.level_status.text == "bad_rows.tres rejected: " + bad.validation_error(),
		"Status shows Level.validation_error()")
	_button(lab, "not_a_level").pressed.emit()
	_check(lab.bricks.level == level_2 and lab.level_status.text.contains("not a Level"),
		"Non-Level resources are rejected")
	_button(lab, "level_9").pressed.emit()
	_check(lab.bricks.get_child_count() == 2 and lab.bricks_left == 2, "A valid file still loads after a rejection")

	# Empty folder: say so rather than show a blank panel.
	for file in DirAccess.get_files_at(SCRATCH_DIR):
		DirAccess.remove_absolute(SCRATCH_DIR + file)
	lab.refresh_level_picker()
	_check(lab.level_buttons.get_child_count() == 0 and lab.level_status.text.contains("No .tres levels"),
		"An empty folder shows a message")
	DirAccess.remove_absolute(SCRATCH_DIR)

	lab.free()
	quit(1 if failures else 0)

func _button(lab: Node, level_name: String) -> Button:
	for button in lab.level_buttons.get_children():
		if button.text == level_name:
			return button
	_check(false, "No button for %s" % level_name)
	return Button.new()

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
