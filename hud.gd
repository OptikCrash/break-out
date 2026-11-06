extends CanvasLayer

# The HUD only reports which button was chosen; main.gd decides what that does.
signal continue_pressed
signal restart_pressed
signal back_to_title_pressed
# Three confirmed A-Z letters. Saving them (and ranking the run) is the
# caller's job; the HUD never reads or writes the high-score board itself.
signal initials_confirmed(initials: String)

@onready var high_scores: Control = $HighScores
@onready var initials_entry: Control = $HighScores/Center/InitialsEntry
@onready var board_view: Control = $HighScores/Center/BoardView

func _ready() -> void:
	$Continue.pressed.connect(continue_pressed.emit)
	$EndButtons/Restart.pressed.connect(restart_pressed.emit)
	$EndButtons/BackToTitle.pressed.connect(back_to_title_pressed.emit)
	initials_entry.confirmed.connect(initials_confirmed.emit)
	# The board's buttons mean the same as the end buttons, so they reuse their signals.
	$HighScores/Center/BoardView/Buttons/Restart.pressed.connect(restart_pressed.emit)
	$HighScores/Center/BoardView/Buttons/BackToTitle.pressed.connect(back_to_title_pressed.emit)

# Shown instead of the end buttons when the caller has decided the run qualifies.
func show_initials_entry(score: int) -> void:
	$EndButtons.hide()
	board_view.hide()
	_show_high_scores_layer(true)
	initials_entry.open(score)

func hide_initials_entry() -> void:
	initials_entry.hide()
	_show_high_scores_layer(board_view.visible)

func is_entering_initials() -> bool:
	return initials_entry.is_visible_in_tree()

# records: [{ initials: String, score: int }, ...] already ranked by the caller.
# highlight_index marks the row just saved (0-based), or -1 for none.
func show_high_scores(records: Array, highlight_index := -1) -> void:
	$EndButtons.hide()
	initials_entry.hide()
	board_view.get_node("Board").show_records(records, highlight_index)
	board_view.show()
	_show_high_scores_layer(true)
	board_view.get_node("Buttons/Restart").grab_focus()

func hide_high_scores() -> void:
	board_view.hide()
	_show_high_scores_layer(initials_entry.visible)

# The centred Game Over / You Win! message would show through the panel, so
# it steps aside while the layer is up and comes back when it closes.
func _show_high_scores_layer(value: bool) -> void:
	high_scores.visible = value
	$MessageLabel.visible = not value

func update_lives(value: int) -> void:
	$Lives.text = "Lives: " + str(value)
	
func update_score(value: int) -> void:
	$Score.text = "Score: " + str(value)

func update_message(value: String) -> void:
	$MessageLabel.text = value

func show_end_buttons() -> void:
	$EndButtons.show()
	# Focus lets keyboard and gamepad use the buttons (arrows/D-pad to move,
	# Enter/Space/A to press) without touching the mouse.
	$EndButtons/Restart.grab_focus()

func update_level(value: int) -> void:
	$Level.text = "Level: " + str(value)

func show_continue_button() -> void:
	$Continue.show()
	$Continue.grab_focus()

func hide_continue_button() -> void:
	$Continue.release_focus()
	$Continue.hide()

# Placeholder colours until Chris draws effect icons. The row text also says
# "Hazard" so the colour is never the only way to tell the two apart.
const POWER_UP_COLOR := Color(0.3, 0.85, 0.4)
const HAZARD_COLOR := Color(0.95, 0.35, 0.3)

# `active` is effect_rules.gd's dictionary: effect ID -> {definition, remaining}.
# main.gd calls this every physics frame, so rows are kept by effect ID and only
# created or removed when an effect starts or ends, not rebuilt each frame.
func update_effects(active: Dictionary, force_field_charges: int = 0) -> void:
	# A display-only entry reuses rows without putting charges in the timer state.
	active = active.duplicate()
	if force_field_charges > 0:
		active[&"force_field"] = {"definition": preload("res://effects/force_field.tres"), "charges": force_field_charges}
	var rows := $ActiveEffects/Rows
	for row in rows.get_children():
		if not active.has(StringName(row.name)):
			# remove_child first so the row is gone now, not at the end of the frame.
			rows.remove_child(row)
			row.queue_free()
	for id in active:
		var entry: Dictionary = active[id]
		var row := rows.get_node_or_null(NodePath(String(id)))
		if row == null:
			row = _make_effect_row(id, entry.definition)
			rows.add_child(row)
		# Whole seconds, rounded up, so the number doesn't flicker every frame
		# and never shows 0 while the effect is still running.
		if entry.has("charges"):
			row.get_node("Name").text = "%s  %d charges" % [_effect_label(entry.definition), entry.charges]
		else:
			row.get_node("Name").text = "%s  %ds" % [_effect_label(entry.definition), ceili(entry.remaining)]
	$ActiveEffects.visible = not active.is_empty()

func _effect_label(effect: Resource) -> String:
	return ("Hazard: " if effect.hazard else "") + effect.display_name

func _make_effect_row(id: StringName, effect: Resource) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = String(id)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var swatch := ColorRect.new()
	swatch.name = "placeholder_swatch"
	swatch.custom_minimum_size = Vector2(24, 24)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.color = HAZARD_COLOR if effect.hazard else POWER_UP_COLOR
	row.add_child(swatch)
	var label := Label.new()
	label.name = "Name"
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", HAZARD_COLOR if effect.hazard else Color.WHITE)
	row.add_child(label)
	return row
