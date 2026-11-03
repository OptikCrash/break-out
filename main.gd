extends Node2D

const TITLE_SCENE := "res://TitleScreen.tscn"

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
	hud.restart_pressed.connect(restart)
	hud.back_to_title_pressed.connect(back_to_title)
	bricks_left = bricks.get_child_count()

func _process(_delta: float) -> void:
	if reset_ready && Input.is_action_just_pressed("restart"):
		restart()

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
		hud.update_message("Game Over!")
		hud.show_end_buttons()
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
		hud.update_message("You Win!")
		hud.show_end_buttons()

# R and the Restart button both land here. Clearing reset_ready means a second
# request in the same frame (R plus a click) can't ask for another scene change.
func restart() -> void:
	if not reset_ready:
		return
	reset_ready = false
	get_tree().reload_current_scene()

func back_to_title() -> void:
	if not reset_ready:
		return
	reset_ready = false
	get_tree().change_scene_to_file(TITLE_SCENE)
