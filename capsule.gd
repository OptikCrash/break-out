extends Area2D

const Rules = preload("res://effect_rules.gd")
signal caught(effect: Resource)
var effect: Resource

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	$placeholder_label.text = effect.display_name if effect != null else "Capsule"

func _physics_process(delta: float) -> void:
	position.y += Rules.CAPSULE_SPEED * delta

func _on_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion() or not body.is_in_group("paddle"):
		return
	queue_free()
	caught.emit(effect)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("death_zone"):
		queue_free()
