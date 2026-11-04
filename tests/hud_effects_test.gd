extends SceneTree

const WIDE = preload("res://effects/wide_paddle.tres")
const SHRINK = preload("res://effects/shrink_paddle.tres")
const EXTRA_LIFE = preload("res://effects/extra_life.tres")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.ball.set_physics_process(false)
	game.paddle.set_physics_process(false)
	var panel: Control = game.hud.get_node("ActiveEffects")
	var rows: Node = panel.get_node("Rows")
	_check(not panel.visible, "No panel while nothing is active")

	# Drive the HUD through main's real catch path and effect timers.
	game._catch_capsule(WIDE)
	game._catch_capsule(EXTRA_LIFE)
	await process_frame
	_check(panel.visible, "Panel shows once an effect is active")
	_check(rows.get_child_count() == 1, "Instant Extra Life gets no timer row")
	_check(_row_text(rows, &"wide_paddle") == "Wide Paddle  10s", "Row names the effect and its time left")

	game._catch_capsule(SHRINK)
	await process_frame
	_check(rows.get_child_count() == 2, "Concurrent effects get one row each")
	_check(_row_text(rows, &"shrink_paddle") == "Hazard: Shrink Paddle  10s", "Hazards are labelled in text, not just colour")
	var power_swatch: ColorRect = rows.get_node("wide_paddle/placeholder_swatch")
	var hazard_swatch: ColorRect = rows.get_node("shrink_paddle/placeholder_swatch")
	_check(power_swatch.color != hazard_swatch.color, "Power-up and hazard swatches differ")

	# The panel lives in the gutter right of the Play Area, clear of the bricks.
	var play_area_right: float = game.get_node("PlayArea/PlayAreaBG").get_global_rect().end.x
	_check(panel.get_global_rect().position.x >= play_area_right, "Panel stays right of the Play Area")
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Panel stays on screen")

	var wide_row: Node = rows.get_node("wide_paddle")
	game._physics_process(4.5)
	_check(_row_text(rows, &"wide_paddle") == "Wide Paddle  6s", "Countdown rounds up to whole seconds")
	_check(rows.get_node("wide_paddle") == wide_row, "Rows are updated in place, not rebuilt")

	game._physics_process(6.0)
	_check(rows.get_child_count() == 0, "Expired effects clear from the HUD")
	_check(not panel.visible, "Panel hides again when every effect expires")

	# A life loss clears effects too; the HUD must follow.
	game._catch_capsule(WIDE)
	game._clear_effects_and_capsules()
	_check(rows.get_child_count() == 0 and not panel.visible, "Cleared effects leave the HUD")

	game.free()
	quit(1 if failures else 0)

func _row_text(rows: Node, id: StringName) -> String:
	var row := rows.get_node_or_null(NodePath(String(id)))
	return "" if row == null else row.get_node("Name").text

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
