extends Node2D

# Placeholder art for the Satellite Shield's waiting orbs: plain circles drawn
# around the paddle. They are only a picture. No body, no "ball" group, so the
# physics and the Multi-ball Life Rule cannot see them until main launches one.

const ORBIT_SPEED := TAU / 2.0
const ORB_RADIUS := 8.0
const ORB_COLOR := Color(0.55, 0.85, 1.0)

var count := 0:
	set(value):
		count = value
		queue_redraw()
# Horizontal radius follows the paddle's current width; the vertical one is fixed.
var orbit_size := Vector2(92, 36)
var angle := 0.0

func _process(delta: float) -> void:
	if count == 0:
		return
	angle = fmod(angle + ORBIT_SPEED * delta, TAU)
	queue_redraw()

func _draw() -> void:
	for index in count:
		var orb_angle := angle + TAU * index / 3.0
		draw_circle(Vector2(cos(orb_angle), sin(orb_angle)) * orbit_size, ORB_RADIUS, ORB_COLOR)
