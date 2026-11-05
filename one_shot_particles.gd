extends CPUParticles2D

# A one-shot effect: emit once, then free itself when the root's particles have died.
# Child CPUParticles2D layers (flashes, sparks) fire together with the root and
# must not outlive its lifetime, because freeing the root frees them too.
# CPUParticles2D has no collision, so these effects cannot touch gameplay.

# How far towards white the child layers sit, so they read as hot highlights
# on top of the tinted root.
const CHILD_WHITENESS := 0.6
# How far towards white the root itself sits. Additive sparks need some white
# to stay visible over a brick of their own colour.
@export_range(0.0, 1.0) var tint_whiteness := 0.0

func _ready() -> void:
	finished.connect(queue_free)
	emitting = true
	for child in get_children():
		if child is CPUParticles2D:
			child.emitting = true

# Multiplies the colour ramp, so the effect fades the same way in any tint.
func tint(tint_color: Color) -> void:
	color = tint_color.lerp(Color.WHITE, tint_whiteness)
	for child in get_children():
		if child is CPUParticles2D:
			child.color = tint_color.lerp(Color.WHITE, CHILD_WHITENESS)
