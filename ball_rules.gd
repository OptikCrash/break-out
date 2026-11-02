extends RefCounted

static func launch_direction() -> Vector2:
	var lean := randf_range(-0.3, 0.3)
	# The random range includes zero; even that sample must avoid a vertical loop.
	return direction_with_lean(lean)

static func direction_with_lean(lean: float) -> Vector2:
	if lean == 0.0:
		lean = 0.3
	return Vector2(lean, -1.0).normalized()

static func paddle_direction(x_dir: float) -> Vector2:
	if x_dir == 0.0:
		return launch_direction()
	return Vector2(x_dir, -1.0).normalized()
