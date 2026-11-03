class_name Level
extends Resource

@export_multiline var grid: String = ""

# Keep row widths explicit: use dots for holes, not spaces or missing cells.
func validation_error() -> String:
	var lines := grid.replace("\r\n", "\n").trim_suffix("\n").split("\n")
	if lines[0].is_empty():
		return "Level grid must have at least one cell."
	var width := lines[0].length()
	for row in lines.size():
		if lines[row].length() != width:
			return "Level grid row %d must contain %d cells." % [row + 1, width]
		for col in width:
			if not lines[row][col] in ".#xo?":
				return "Invalid level character '%s' at row %d, column %d." % [lines[row][col], row + 1, col + 1]
	# A playable layout needs a brick that can trigger level completion.
	if not "#" in grid and not "x" in grid and not "?" in grid:
		return "Level grid must contain at least one destructible brick (#, x or ?)."
	return ""

func brick_symbol_at(cell: Vector2i) -> String:
	var lines := grid.replace("\r\n", "\n").trim_suffix("\n").split("\n")
	return lines[cell.y][cell.x]

# Coordinates are cells, independent of the play area's pixel layout.
func brick_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var error := validation_error()
	if not error.is_empty():
		push_error(error)
		return cells
	var lines := grid.replace("\r\n", "\n").trim_suffix("\n").split("\n")
	for row in lines.size():
		for col in lines[row].length():
			if lines[row][col] != ".":
				cells.append(Vector2i(col, row))
	return cells
