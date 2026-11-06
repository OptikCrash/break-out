extends VBoxContainer

# The "New High Score!" panel. It only collects three letters and reports
# them; whether the score qualifies and where it ranks is decided elsewhere,
# and nothing is saved until `confirmed` is handled by the caller.
signal confirmed(initials: String)

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const LENGTH := 3
# Placeholder slot styling until Chris draws one. The next slot to fill gets
# a thicker, brighter border so the cursor is not shown by colour alone.
const SLOT_FILL := Color(0.05, 0.03, 0.15)
const SLOT_BORDER := Color(0.6, 0.6, 0.6)
const ACTIVE_BORDER := Color(1.0, 0.82, 0.25)

var initials := ""
# One confirmation per open, so a double press can't save the run twice.
var sent := false

@onready var slots: Array[Label] = [$Slots/Slot1, $Slots/Slot2, $Slots/Slot3]
@onready var letters: GridContainer = $Letters
@onready var delete_button: Button = $Actions/Delete
@onready var confirm_button: Button = $Actions/Confirm

func _ready() -> void:
	# One button per letter. Godot moves focus between them by position, so
	# arrows and the D-pad walk the grid without hand-set focus neighbours.
	for letter in LETTERS:
		var button := Button.new()
		button.name = letter
		button.text = letter
		button.custom_minimum_size = Vector2(88, 72)
		button.add_theme_font_size_override("font_size", 40)
		button.pressed.connect(add_letter.bind(letter))
		letters.add_child(button)
	delete_button.pressed.connect(remove_letter)
	confirm_button.pressed.connect(confirm)
	_refresh()

func open(score: int) -> void:
	initials = ""
	sent = false
	$Score.text = "Score: %d" % score
	show()
	_refresh()
	# Keyboard and gamepad players need a focused button to start from.
	letters.get_node("A").grab_focus()

func add_letter(letter: String) -> void:
	# Only single A-Z letters, and never more than three: there is no free text.
	if initials.length() >= LENGTH or letter.length() != 1 or not LETTERS.contains(letter):
		return
	initials += letter
	_refresh()
	# With all three chosen, the next press of Enter/A should confirm.
	if initials.length() == LENGTH:
		confirm_button.grab_focus()

func remove_letter() -> void:
	if sent or initials.is_empty():
		return
	initials = initials.left(-1)
	_refresh()

func confirm() -> void:
	if sent or initials.length() != LENGTH:
		return
	sent = true
	confirmed.emit(initials)

# Typing works alongside the on-screen grid. Focused Buttons only use the ui_*
# actions (arrows, Enter, Space, pad A), so letter keys reach this handler.
func _unhandled_input(event: InputEvent) -> void:
	# A hidden panel still gets _unhandled_input, so check visibility first.
	if not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and not (key.ctrl_pressed or key.alt_pressed or key.meta_pressed):
		if key.keycode >= KEY_A and key.keycode <= KEY_Z:
			get_viewport().set_input_as_handled()
			add_letter(char(key.keycode))
			return
		if key.keycode == KEY_BACKSPACE:
			get_viewport().set_input_as_handled()
			remove_letter()
			return
	# Gamepad B (and Escape) steps back one letter, like an arcade cabinet.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		remove_letter()

func _refresh() -> void:
	for i in LENGTH:
		var slot := slots[i]
		slot.text = initials[i] if i < initials.length() else "_"
		var style := StyleBoxFlat.new()
		style.bg_color = SLOT_FILL
		var active := i == initials.length()
		style.border_color = ACTIVE_BORDER if active else SLOT_BORDER
		style.set_border_width_all(6 if active else 2)
		slot.add_theme_stylebox_override("normal", style)
	delete_button.disabled = initials.is_empty()
	confirm_button.disabled = initials.length() != LENGTH
