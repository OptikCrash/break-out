extends SceneTree

# power_action is the shared input for active power-ups (GLOSSARY.md "Power-up
# Action"). Nothing reads it yet; this pins its bindings to launch's.
var failures := 0

func _initialize() -> void:
	_check(InputMap.has_action("power_action"), "project.godot must define power_action")
	if InputMap.has_action("power_action"):
		check_expected_events()
		check_mirrors_launch()
	quit(1 if failures else 0)

# Space, gamepad A (bottom face button) and the left mouse button, exactly.
func check_expected_events() -> void:
	var events := InputMap.action_get_events("power_action")
	_check(events.size() == 3, "power_action must have 3 events, has %d" % events.size())
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	for pair in [["Space", space], ["Gamepad A", pad_a], ["Left mouse", click]]:
		pair[1].pressed = true
		_check(InputMap.event_is_action(pair[1], "power_action", true),
			"%s must trigger power_action" % pair[0])
	_check(is_equal_approx(InputMap.action_get_deadzone("power_action"), 0.2),
		"power_action must use the 0.2 deadzone like launch")

# Every launch binding must also be a power_action binding and vice versa, so a
# rebind of one without the other fails here.
func check_mirrors_launch() -> void:
	var launch := InputMap.action_get_events("launch")
	var power := InputMap.action_get_events("power_action")
	_check(launch.size() == power.size(), "power_action and launch must have the same event count")
	for event in launch:
		_check(_contains(power, event), "power_action is missing launch's %s" % event.as_text())
	for event in power:
		_check(_contains(launch, event), "power_action has %s, which launch lacks" % event.as_text())

func _contains(events: Array[InputEvent], wanted: InputEvent) -> bool:
	for event in events:
		if event.is_match(wanted, true):
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
