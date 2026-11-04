extends "res://main.gd"

# Development-only sandbox (see ADR-0002). test_lab.tscn inherits main.tscn,
# so this script only changes the session rules: everything else (loading,
# effects, scoring, capsules) is main.gd's real code. Open test_lab.tscn in
# the editor and press F6; no production scene links here.

# Scanned when the lab opens, so a new .tres dropped in here gets a button
# without editing a list. A var (not const) so tests can point it elsewhere.
var levels_dir := "res://levels/"
@onready var level_buttons := $LabOverlay/LevelPicker/Scroll/Buttons
@onready var level_status := $LabOverlay/LevelPicker/Status

func _ready() -> void:
	super._ready()
	# Inherited scenes can't delete inherited nodes, so drop the pause menu
	# here. can_pause() below stops main.gd from ever opening it.
	pause_screen.queue_free()
	pause_screen = null
	$LabOverlay/ResetButton.pressed.connect(reset_lab)
	refresh_level_picker()
	_build_effect_buttons()

func can_pause() -> bool:
	return false

# Infinite lives: losing the last ball still clears effects (main.gd does that
# before calling this), but only spawns a fresh ball on the paddle.
func _lose_life() -> void:
	add_ball()

# Clearing a level reloads it rather than showing "Level Complete"/"You Win!".
func _finish_level() -> void:
	reset_lab()

# The HUD's end buttons are never shown here, but make sure they can't leave.
func restart() -> void:
	pass

func back_to_title() -> void:
	pass

# Back to a fresh start of the level on screen (bricks.level, which the picker
# may have changed): one ball resting on the paddle, bricks rebuilt, and the
# same cleanup a lost life or level end uses.
func reset_lab() -> void:
	_restart_with(bricks.level)

# Every .tres file in levels_dir, sorted so level_10 comes after level_9.
func find_level_files() -> Array[String]:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(levels_dir):
		if file.get_extension() == "tres":
			files.append(file)
	files.sort_custom(func(a: String, b: String): return a.naturalnocasecmp_to(b) < 0)
	return files

# Rebuilds the picker's buttons from the folder on disk.
func refresh_level_picker() -> void:
	for button in level_buttons.get_children():
		level_buttons.remove_child(button)
		button.queue_free()
	var files := find_level_files()
	if files.is_empty():
		level_status.text = "No .tres levels found in %s" % levels_dir
		return
	level_status.text = "Pick a level to load it."
	for file in files:
		var button := Button.new()
		button.name = file.get_basename()
		button.text = file.get_basename()
		# Same as Reset: a focused button would also take Space (launch).
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(pick_level_file.bind(file))
		level_buttons.add_child(button)

# Loads a picked file through the same validation and Bricks.load_level() the
# real game uses. A rejected level leaves the current layout and balls alone.
func pick_level_file(file: String) -> bool:
	var path := levels_dir.path_join(file)
	# Loaded on click, not while scanning, so one broken file can't stop the
	# rest of the list from appearing.
	var level = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
	if not level is Level:
		level_status.text = "%s is not a Level resource." % file
		return false
	var error: String = level.validation_error()
	if not error.is_empty():
		# Shown on screen rather than push_error(): a bad file is expected
		# while authoring levels, and the lab should keep running.
		level_status.text = "%s rejected: %s" % [file, error]
		return false
	_restart_with(level)
	level_status.text = "Showing %s" % file
	return true

func _restart_with(level: Level) -> void:
	# Validates again; on failure it pushes the error and keeps the old bricks.
	if not bricks.load_level(level):
		return
	_clear_effects_and_capsules()
	var balls := get_balls()
	for extra in balls.slice(1):
		# Leave the group now, as the Death Zone does: deletion waits for frame end.
		extra.remove_from_group("ball")
		extra.queue_free()
	paddle.position = paddle_start
	paddle.velocity = Vector2.ZERO
	paddle.following_mouse = false
	paddle.set_physics_process(true)
	if balls.is_empty():
		add_ball()
	else:
		balls[0].reset()
		balls[0].set_physics_process(true)
	_count_completion_bricks()
	hud.update_message("")

# Use the capsule pool itself so new gameplay effects appear here automatically.
func _build_effect_buttons() -> void:
	var rows := $LabOverlay/EffectPanel/Margin/Content/Scroll/Rows
	for effect in EffectRules.DEFINITIONS:
		var button := Button.new()
		button.name = String(effect.id)
		button.text = ("Hazard: " if effect.hazard else "") + effect.display_name
		button.tooltip_text = "Catch %s through the gameplay capsule path." % effect.display_name
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 48.0
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", Color.WHITE)
		var swatch := ColorRect.new()
		swatch.name = "placeholder_swatch"
		swatch.color = hud.HAZARD_COLOR if effect.hazard else hud.POWER_UP_COLOR
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		swatch.offset_right = 6.0
		button.add_child(swatch)
		# No falling capsule or alternate effect implementation in the lab.
		button.pressed.connect(_catch_capsule.bind(effect))
		rows.add_child(button)
