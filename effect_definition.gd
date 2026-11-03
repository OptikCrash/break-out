extends Resource

@export var id: StringName
@export var display_name: String
@export var hazard := false
@export var duration := 0.0
@export var paddle_width_multiplier := 1.0
@export var ball_speed_multiplier := 1.0
@export var shot_cooldown := 0.0
@export var bolt_speed := 0.0
@export var extra_lives := 0
@export var hazard_charges := 0
@export var companion_count := 0
@export var companion_health := 0
@export var companion_offset := Vector2.ZERO
@export var companion_follow_speed := 0.0
@export var extra_balls := 0
@export var split_angle_degrees := 0.0
# Satellite Shield is charge-based: orbs wait at the paddle instead of a timer.
@export var orbs := 0

func validation_error() -> String:
	if id == &"" or display_name.is_empty():
		return "Effects need a stable ID and display name."
	if duration < 0.0 or paddle_width_multiplier <= 0.0 or ball_speed_multiplier <= 0.0 or extra_lives < 0:
		return "Effect duration/lives must be nonnegative and width/speed positive."
	if duration == 0.0 and (paddle_width_multiplier != 1.0 or ball_speed_multiplier != 1.0):
		return "Width and speed effects need a duration."
	if extra_balls < 0 or split_angle_degrees < 0.0 or split_angle_degrees >= 90.0:
		return "Ball count must be nonnegative and spread in [0, 90) degrees."
	if extra_balls > 0 and (extra_balls != 2 or split_angle_degrees == 0.0 or duration != 0.0):
		return "Multi-ball needs two extra balls, a spread and no timer."
	if orbs < 0 or (orbs > 0 and duration != 0.0):
		return "Orb count must be nonnegative, and orbs are charges with no timer."
	if shot_cooldown < 0.0 or bolt_speed < 0.0:
		return "Weapon tuning must be nonnegative."
	if id == &"blaster" and (duration <= 0.0 or shot_cooldown <= 0.0 or bolt_speed <= 0.0):
		return "Blaster needs a duration, cooldown and bolt speed."
	if hazard_charges < 0:
		return "Hazard charges must be nonnegative."
	if hazard_charges > 0 and (hazard_charges != 3 or duration != 0.0 or hazard):
		return "Force Field needs three charges, no timer and must be a power-up."
	if companion_count != 0 or companion_health != 0 or companion_offset != Vector2.ZERO or companion_follow_speed != 0.0:
		if companion_count != 2 or companion_health != 3 or companion_offset.x <= 0.0 or companion_offset.y >= 0.0 or companion_follow_speed <= 0.0 or duration != 0.0 or hazard:
			return "Companions need two paddles, three health, positive spacing/speed, upward offset and no hazard/timer."
	return ""
