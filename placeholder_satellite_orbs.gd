extends Node2D

# Waiting orbs for the Satellite Shield, drawn around the paddle with the ball's own
# animation frames. They are only a picture. No body, no "ball" group, so the
# physics and the Multi-ball Life Rule cannot see them until main launches one.

const BALL_SCENE := preload("res://ball.tscn")
const ORBIT_SPEED := TAU / 2.0
# Gap between the paddle's end and the orbit; main adds the paddle's half-width.
const ORBIT_MARGIN_X := 56.0
const ORBIT_RADIUS_Y := 56.0

var count := 0:
	set(value):
		count = value
		queue_redraw()
# Horizontal radius follows the paddle's current width; the vertical one is fixed.
var orbit_size := Vector2(64.0 + ORBIT_MARGIN_X, ORBIT_RADIUS_Y)
var angle := 0.0
var elapsed := 0.0
var frames: SpriteFrames
var animation := &"default"
var sprite_scale := Vector2.ONE

func _ready() -> void:
	# Borrow the ball's SpriteFrames so the orbs always match the current ball art.
	var ball := BALL_SCENE.instantiate()
	var sprite: AnimatedSprite2D = ball.get_node("Sprite2D")
	frames = sprite.sprite_frames
	animation = sprite.animation
	sprite_scale = sprite.scale
	ball.free()

func _process(delta: float) -> void:
	if count == 0:
		return
	angle = fmod(angle + ORBIT_SPEED * delta, TAU)
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	if frames == null or not frames.has_animation(animation):
		return
	var frame_count := frames.get_frame_count(animation)
	if frame_count == 0:
		return
	var frame := int(elapsed * frames.get_animation_speed(animation)) % frame_count
	var texture := frames.get_frame_texture(animation, frame)
	var size := texture.get_size() * sprite_scale
	for index in count:
		var orb_angle := angle + TAU * index / 3.0
		var center := Vector2(cos(orb_angle), sin(orb_angle)) * orbit_size
		draw_texture_rect(texture, Rect2(center - size / 2.0, size), false)
