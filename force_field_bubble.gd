extends Area2D

# The Force Field's bubble around the main paddle. It is both the picture and the
# hitbox: the drawn ellipse and the collision polygon come from the same points,
# so what the player sees is exactly what blocks hazards.
#
# Gameplay stays in main.gd: the bubble only reports which hazard touched it
# (capsule.gd detects it on the Force Field layer) and main decides through the
# same _catch_capsule() path a paddle catch uses. Charges live on main.gd.
# The bubble never monitors anything itself, and balls pass through it.

signal hazard_blocked(effect: Resource, at: Vector2)

# Bubble size beyond the paddle: horizontal margin past each end, fixed height.
const MARGIN_X := 28.0
const RADIUS_Y := 44.0
const SEGMENTS := 32
# Warning blink once only one charge remains: the next hazard pops the bubble.
const BLINK_HZ := 5.0
const BLINK_DIM_ALPHA := 0.2
# Short presentation animations, in seconds.
const FORM_TIME := 0.2
const FLASH_TIME := 0.25
const POP_TIME := 0.25

const FILL_COLOR := Color(0.35, 0.8, 1.0, 0.14)
const RIM_COLOR := Color(0.55, 0.9, 1.0, 0.9)
const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.45)

# Optional pixel art: when set, it is stretched over the bubble's bounding box
# instead of the drawn ellipse. Hitbox, blink, flash and pop are unchanged.
@export var texture: Texture2D

var charges := 0
var half_width := 64.0
var radii := Vector2(64.0 + MARGIN_X, RADIUS_Y)
var points := PackedVector2Array()
var time := 0.0
var form_left := 0.0
var flash_left := 0.0
var pop_left := 0.0

func _ready() -> void:
	# A shape per instance, so resizing never touches a shared resource.
	$CollisionShape2D.shape = ConvexPolygonShape2D.new()
	_rebuild()
	_refresh_visibility()

# Blocks only while charged, so a spent bubble lets hazards reach the paddle.
func is_blocking() -> bool:
	return charges > 0

func block(effect: Resource, at: Vector2) -> void:
	if is_blocking():
		hazard_blocked.emit(effect, at)

func set_charges(value: int) -> void:
	if value == charges:
		return
	var previous := charges
	charges = value
	if value > previous:
		# Gaining charges always re-forms it: a new field or a refresh.
		form_left = FORM_TIME
		pop_left = 0.0
	elif value == 0:
		pop_left = POP_TIME
	else:
		flash_left = FLASH_TIME
	_refresh_visibility()

# Follows the paddle's current (Wide/Shrink) width.
func set_half_width(value: float) -> void:
	if is_equal_approx(value, half_width):
		return
	half_width = value
	_rebuild()

func is_blinking() -> bool:
	return charges == 1

func _rebuild() -> void:
	radii = Vector2(half_width + MARGIN_X, RADIUS_Y)
	points = PackedVector2Array()
	for index in SEGMENTS:
		var angle := TAU * index / SEGMENTS
		points.append(Vector2(cos(angle), sin(angle)) * radii)
	$CollisionShape2D.shape.points = points
	queue_redraw()

func _refresh_visibility() -> void:
	visible = charges > 0 or pop_left > 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	time += delta
	form_left = maxf(0.0, form_left - delta)
	flash_left = maxf(0.0, flash_left - delta)
	pop_left = maxf(0.0, pop_left - delta)
	_refresh_visibility()
	queue_redraw()

# Overall opacity: the warning blink while on the last charge.
func current_alpha() -> float:
	if is_blinking() and fmod(time * BLINK_HZ, 1.0) >= 0.6:
		return BLINK_DIM_ALPHA
	return 1.0

func _draw() -> void:
	var size := 1.0
	var alpha := current_alpha()
	if form_left > 0.0:
		# Grow out of the paddle with a slight overshoot.
		var t := 1.0 - form_left / FORM_TIME
		size = lerpf(0.5, 1.0, ease(t, 0.4)) + 0.06 * sin(t * PI)
	if pop_left > 0.0:
		var t := 1.0 - pop_left / POP_TIME
		size = 1.0 + 0.3 * t
		alpha = 1.0 - t
	var flash := flash_left / FLASH_TIME
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * size)
	if texture:
		draw_texture_rect(texture, Rect2(-radii, radii * 2.0), false, Color(1, 1, 1, alpha).lerp(Color.WHITE, flash))
		return
	var fill := FILL_COLOR.lerp(Color(0.8, 0.95, 1.0, 0.45), flash)
	fill.a *= alpha
	draw_colored_polygon(points, fill)
	# A slow shimmer on the rim keeps the field reading as "live".
	var rim := RIM_COLOR.lerp(Color.WHITE, flash)
	rim.a *= alpha * (0.8 + 0.2 * sin(time * 3.0))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, rim, 3.0, true)
	# A glint across the upper left, like light on a soap bubble.
	var highlight := HIGHLIGHT_COLOR
	highlight.a *= alpha
	var glint := PackedVector2Array()
	for index in 9:
		var angle := lerpf(PI * 1.12, PI * 1.38, index / 8.0)
		glint.append(Vector2(cos(angle), sin(angle)) * (radii - Vector2(8, 8)))
	draw_polyline(glint, highlight, 3.0, true)
