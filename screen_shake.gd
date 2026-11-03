extends Camera2D

# Screen shake moves only this camera's offset, which changes what is drawn and
# nothing else: bodies, collision shapes and the HUD (a CanvasLayer) stay put.
# The anchor is the top-left corner at (0, 0), so at rest the view is unchanged.

var strength := 0.0
var duration := 0.0
var time_left := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

# A weaker shake never cuts a stronger one short.
func shake(new_strength: float, new_duration: float) -> void:
	if new_duration <= 0.0 or new_strength < current_strength():
		return
	strength = new_strength
	duration = new_duration
	time_left = new_duration

# Linear decay from full strength to zero over the duration.
func current_strength() -> float:
	if time_left <= 0.0:
		return 0.0
	return strength * time_left / duration

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)
	var amount := current_strength()
	if amount == 0.0:
		offset = Vector2.ZERO
		return
	offset = Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount))
