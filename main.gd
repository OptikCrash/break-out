extends Node2D

@export var lives = 3
@onready var ball := $Ball
@onready var bricks := $Bricks
@onready var hud := $Hud
var score = 0
var bricks_left = 0
var reset_ready := false

func _ready() -> void:
	hud.update_message("")
	hud.update_score(score)
	hud.update_lives(lives)
	bricks_left = bricks.get_child_count()

func _process(_delta: float) -> void:
	if reset_ready && Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

func _on_death_zone_body_entered(_body: Node2D) -> void:
	lives -= 1
	hud.update_lives(lives)
	if lives == 0:
		reset_ready = true
		ball.set_physics_process(false)
		hud.update_message("Game Over!\nPress R to restart")
	else:
		print("Lives left: ", lives)
		ball.reset()

func _on_ball_brick_broken() -> void:
	bricks_left -= 1
	score += 10
	hud.update_score(score)
	if bricks_left == 0:
		ball.reset()
		reset_ready = true
		ball.set_physics_process(false)
		hud.update_message("You Win!\nPress R to restart")
