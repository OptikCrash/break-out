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
	_check(bricks.level == null and bricks.get_child_count() == 0, "Bricks must not build a layout until main hands it one")
	_check(bricks.load_level(level) and bricks.get_child_count() == 68, "Loader must instantiate Level 1")
	for i in cells.size():
		_check(bricks.get_child(i).position == Vector2(32 + cells[i].x * 64, 128 + cells[i].y * 32), "Brick must use the cell's pixel position")
	bricks.free()

	var sample := Level.new()
	sample.grid = ".#x\r\no..\r\n"
	_check(sample.validation_error().is_empty(), "CRLF, final newline and reserved characters must be accepted")
	_check(sample.brick_cells() == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)], "Dots must leave holes without shifting cells")
	bricks = Node2D.new()
	bricks.set_script(preload("res://bricks.gd"))
	bricks.grid_start = Vector2(10, 20)
	bricks.brick_size = Vector2(30, 40)
	root.add_child(bricks)
	bricks.load_level(sample)
	_check(bricks.get_child_count() == 3, "Every non-dot character must instantiate a brick")
	_check(bricks.get_child(2).position == Vector2(10, 60), "Loader must honor exported sizing and origin")
	bricks.free()

	for invalid in ["", "##\n#", "# ", "#?", "##\n\n##"]:
		sample.grid = invalid
		_check(not sample.validation_error().is_empty(), "Malformed grid must report a clear error: " + invalid)
	for unplayable in ["ooo", "...", ".o\no."]:
		sample.grid = unplayable
		_check(sample.validation_error() == "Level grid must contain at least one destructible brick (# or x).", "Unclearable layouts must report why they cannot be loaded")
	for playable in ["o#", "ox"]:
		sample.grid = playable
		_check(sample.validation_error().is_empty(), "Either destructible brick type makes a layout playable")
	_check_designed_level(2, 32, 25, 0, 82)
	_check_designed_level(3, 16, 45, 14, 106)
	quit(1 if failures else 0)

# These layouts deliberately leave every target's column open to the paddle.
# Removing lower targets exposes upper ones; no permanent roof blocks that route.
func _check_designed_level(number: int, normal: int, reinforced: int, permanent: int, hits: int) -> void:
	var level: Level = load("res://levels/level_%d.tres" % number)
	_check(level.validation_error().is_empty(), "Designed level must validate")
	var rows := level.grid.split("\n")
	_check(rows.size() == 7, "Designed formation must have seven rows")
	for row in rows:
		_check(row.length() == 17, "Designed formation must span seventeen columns")
	_check(level.grid.count("#") == normal, "Normal count must match design")
	_check(level.grid.count("x") == reinforced, "Reinforced count must match design")
	_check(level.grid.count("o") == permanent, "Indestructible count must match design")
	_check(normal + 2 * reinforced == hits, "Required hits must pin the difficulty ramp")
	var bricks = Node2D.new()
	bricks.set_script(preload("res://bricks.gd"))
	root.add_child(bricks)
	bricks.load_level(level)
	var cells := level.brick_cells()
	_check(bricks.get_child_count() == normal + reinforced + permanent, "All designed bricks must load")
	for i in cells.size():
		var cell := cells[i]
		var brick = bricks.get_child(i)
		_check(brick.position == Vector2(32 + cell.x * 64, 128 + cell.y * 32), "Designed brick must retain its grid position")
		# Inside wall faces are x=32/1120 and y=32; paddle starts at y=900.
		_check(brick.position.x >= 32 and brick.position.x + 64 <= 1120, "Brick must fit between side walls")
		_check(brick.position.y >= 32 and brick.position.y + 32 < 900, "Brick must fit above the paddle")
		if level.brick_symbol_at(cell) != "o":
			for lower in range(cell.y + 1, rows.size()):
				_check(level.brick_symbol_at(Vector2i(cell.x, lower)) != "o", "Every target needs an approach from below without permanent blockers")
	# Each open column is 64px wide, exceeding the ball's 32px diameter.
	bricks.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
