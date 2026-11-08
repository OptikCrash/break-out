extends SceneTree

const BallRules = preload("res://ball_rules.gd")
var failures := 0

func _initialize() -> void:
	# Matching seeds pin the shared random rule, not a particular random outcome.
	for sample_seed in range(256):
		seed(sample_seed)
		var launch := BallRules.launch_direction()
		seed(sample_seed)
		var bounce := BallRules.paddle_direction(0.0)
		_check(bounce == launch, "Center hit uses the launch lean")
		_check(bounce.x != 0.0 and bounce.y < 0.0, "Center hit always travels upward with a lean")
		_check(is_equal_approx(bounce.length(), 1.0), "Direction preserves the caller's speed")
		_check(absf(bounce.x / bounce.y) <= 0.300001, "Launch lean stays within 0.3")

	_check(BallRules.direction_with_lean(0.0).is_equal_approx(Vector2(0.3, -1.0).normalized()), "Exact zero sample falls back to a 0.3 lean")
	for lean in [-0.3, 0.3]:
		_check(BallRules.direction_with_lean(lean).is_equal_approx(Vector2(lean, -1.0).normalized()), "Launch keeps both 0.3 endpoints")
	for offset in [-1.0, -0.5, 0.000001, 0.5, 1.0]:
		_check(BallRules.paddle_direction(offset).is_equal_approx(Vector2(offset, -1.0).normalized()), "Off-center hit keeps the existing angle")
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
