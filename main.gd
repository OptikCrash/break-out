extends Node2D

@export var lives = 3
@onready var ball := $PlayArea/Ball
@onready var bricks := $PlayArea/Bricks
@onready var hud := $Hud
@onready var pause_screen := $PauseScreen
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

# Main stops getting input while the tree is paused, so closing the menu again
# is handled by pause_screen.gd, which keeps running.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and can_pause():
		get_viewport().set_input_as_handled()
		pause_screen.open()

# Only while the ball is in play: not resting on the paddle, and not under the
# game-over or win message.
func can_pause() -> bool:
	return ball.launched and not reset_ready

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
