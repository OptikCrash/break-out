extends VBoxContainer

# Draws the records it is handed, in the order given: { initials: String, score: int }.
# Ranking, the ten-row limit and saving belong to the high-score rules and
# store, so this scene never sorts, trims or writes anything.

const FONT_SIZE := 40
const RANK_WIDTH := 120
const INITIALS_WIDTH := 220
const SCORE_WIDTH := 300
const HEADER_COLOR := Color(0.8, 0.8, 0.8)
# Placeholder highlight until Chris styles the board. A light band with dark
# text changes brightness, not only hue, so the new row stands out for
# colour-blind players too.
const HIGHLIGHT_FILL := Color(1.0, 0.82, 0.25)
const HIGHLIGHT_TEXT := Color(0.08, 0.05, 0.2)

@onready var rows: VBoxContainer = $Rows

func _ready() -> void:
	$Header.add_child(_make_columns("Rank", "Name", "Score", HEADER_COLOR))
	show_records([])

# highlight_index is the 0-based position of the row to mark (the one just
# saved), or -1 for none. The caller works it out; the board only draws it.
func show_records(records: Array, highlight_index := -1) -> void:
	for row in rows.get_children():
		# remove_child first so the old rows are gone now, not at frame end.
		rows.remove_child(row)
		row.queue_free()
	for i in records.size():
		rows.add_child(_make_row(i, records[i], i == highlight_index))
	# Empty state: a fresh install (or an unreadable save) has no rows yet.
	$Empty.visible = records.is_empty()
	$Header.visible = not records.is_empty()

func _make_row(index: int, record: Dictionary, highlighted: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "Row%d" % (index + 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = HIGHLIGHT_FILL if highlighted else Color.TRANSPARENT
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", style)
	row.set_meta("highlighted", highlighted)
	row.add_child(_make_columns("%d." % (index + 1), str(record.initials),
		str(int(record.score)), HIGHLIGHT_TEXT if highlighted else Color.WHITE))
	return row

func _make_columns(rank: String, initials: String, score: String, color: Color) -> HBoxContainer:
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(_make_label("Rank", rank, RANK_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT, color))
	columns.add_child(_make_label("Initials", initials, INITIALS_WIDTH, HORIZONTAL_ALIGNMENT_CENTER, color))
	columns.add_child(_make_label("Score", score, SCORE_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT, color))
	return columns

func _make_label(label_name: String, text: String, width: int,
		alignment: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.custom_minimum_size = Vector2(width, 0)
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label
