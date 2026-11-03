extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var level: Level = load("res://levels/level_1.tres")
	_check(level.validation_error().is_empty(), "Level 1 must be valid")
	var cells := level.brick_cells()
	_check(cells.size() == 68, "Level 1 must contain 17 by 4 bricks")
	for row in 4:
		for col in 17:
			_check(cells.has(Vector2i(col, row)), "Level 1 must fill every cell")

	var bricks = Node2D.new()
	bricks.set_script(preload("res://bricks.gd"))
	root.add_child(bricks)
	_check(bricks.get_child_count() == 68, "Default loader must instantiate Level 1")
	for i in cells.size():
		_check(bricks.get_child(i).position == Vector2(32 + cells[i].x * 64, 128 + cells[i].y * 32), "Brick must use the cell's pixel position")
	bricks.free()

	var sample := Level.new()
	sample.grid = ".#x\r\no..\r\n"
	_check(sample.validation_error().is_empty(), "CRLF, final newline and reserved characters must be accepted")
	_check(sample.brick_cells() == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)], "Dots must leave holes without shifting cells")
	bricks = Node2D.new()
	bricks.set_script(preload("res://bricks.gd"))
	bricks.level = sample
	bricks.grid_start = Vector2(10, 20)
	bricks.brick_size = Vector2(30, 40)
	root.add_child(bricks)
	_check(bricks.get_child_count() == 3, "Every non-dot character must instantiate a brick")
	_check(bricks.get_child(2).position == Vector2(10, 60), "Loader must honor exported sizing and origin")
	bricks.free()

	for invalid in ["", "##\n#", "# ", "#?", "##\n\n##"]:
		sample.grid = invalid
		_check(not sample.validation_error().is_empty(), "Malformed grid must report a clear error: " + invalid)
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
