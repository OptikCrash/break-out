extends Resource

@export var id: StringName
@export var display_name: String
@export var hazard := false
@export var duration := 0.0
@export var paddle_width_multiplier := 1.0
@export var ball_speed_multiplier := 1.0
@export var extra_lives := 0

func validation_error() -> String:
	if id == &"" or display_name.is_empty():
		return "Effects need a stable ID and display name."
	if duration < 0.0 or paddle_width_multiplier <= 0.0 or ball_speed_multiplier <= 0.0 or extra_lives < 0:
		return "Effect duration/lives must be nonnegative and width/speed positive."
	if duration == 0.0 and (paddle_width_multiplier != 1.0 or ball_speed_multiplier != 1.0):
		return "Width and speed effects need a duration."
	return ""
