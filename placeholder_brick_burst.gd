extends CPUParticles2D

# A one-shot burst: emit once, then free itself when the last particle has died.
# CPUParticles2D has no collision, so the burst cannot touch gameplay.
func _ready() -> void:
	finished.connect(queue_free)
	emitting = true
