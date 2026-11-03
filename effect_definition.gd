extends Resource

@export var id: StringName
@export var display_name: String
@export var hazard := false
@export var duration := 0.0
@export var paddle_width_multiplier := 1.0
@export var extra_lives := 0
@export var extra_balls := 0
@export var split_angle_degrees := 0.0

func validation_error() -> String:
	if id == &"" or display_name.is_empty():
		return "Effects need a stable ID and display name."
	if duration < 0.0 or paddle_width_multiplier <= 0.0 or extra_lives < 0:
		return "Effect duration/lives must be nonnegative and width positive."
	if duration == 0.0 and paddle_width_multiplier != 1.0:
		return "Paddle width effects need a duration."
	if extra_balls < 0 or split_angle_degrees < 0.0 or split_angle_degrees >= 90.0:
		return "Ball count must be nonnegative and spread in [0, 90) degrees."
	if extra_balls > 0 and (extra_balls != 2 or split_angle_degrees == 0.0 or duration != 0.0):
		return "Multi-ball needs two extra balls, a spread and no timer."
	return ""
