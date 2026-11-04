extends CanvasLayer

# The HUD only reports which button was chosen; main.gd decides what that does.
signal continue_pressed
signal restart_pressed
signal back_to_title_pressed

func _ready() -> void:
	$Continue.pressed.connect(continue_pressed.emit)
	$EndButtons/Restart.pressed.connect(restart_pressed.emit)
	$EndButtons/BackToTitle.pressed.connect(back_to_title_pressed.emit)

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
