extends CharacterBody2D

const BrickDamage = preload("res://brick_damage.gd")
signal brick_broken(points: int)
var speed: float = preload("res://effects/blaster.tres").bolt_speed

# Presentation only: the additive Glow sprite pulses in size and brightness around
# its scene values. It is a sprite, not a PointLight2D: the first 2D light on screen
# makes Godot compile lit variants of every visible shader, a ~0.5 s stall on first fire.
const PULSE_HZ := 7.0
const PULSE_DEPTH := 0.3
# A random start phase, so the pair of bolts from one shot do not pulse in lockstep.
var pulse_time := randf()
@onready var glow: Sprite2D = $Glow
@onready var glow_scale := glow.scale
@onready var glow_alpha := glow.modulate.a

func _process(delta: float) -> void:
	pulse_time += delta
	var pulse := 1.0 + PULSE_DEPTH * sin(pulse_time * PULSE_HZ * TAU)
	glow.scale = glow_scale * pulse
	glow.modulate.a = minf(1.0, glow_alpha * pulse)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	# Sweep instead of overlap detection so fast bolts cannot skip thin bricks.
	var collision := move_and_collide(Vector2.UP * speed * delta)
	if collision:
		var hit := collision.get_collider()
		if hit.is_in_group("brick"):
			BrickDamage.hit(hit, true, brick_broken.emit, collision.get_position())
		queue_free()
	elif position.y < 0.0:
		queue_free()
