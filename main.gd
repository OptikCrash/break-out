extends Node2D

const TITLE_SCENE := "res://TitleScreen.tscn"

@export var levels: Array[Level] = [
	preload("res://levels/level_1.tres"),
	preload("res://levels/level_2.tres"),
	preload("res://levels/level_3.tres"),
]
@export var lives = 3
@onready var paddle := $PlayArea/Paddle
@onready var ball := $PlayArea/Ball
@onready var bricks := $PlayArea/Bricks
@onready var hud := $Hud
@onready var pause_screen := $PauseScreen
var current_level_index := 0
var level_complete := false
var paddle_start: Vector2
var score = 0
var bricks_left = 0
var reset_ready := false

func _ready() -> void:
	paddle_start = paddle.position
	if levels.is_empty():
		push_error("Level sequence must contain at least one Level.")
		ball.set_physics_process(false)
		return
	for index in levels.size():
		var error := "Level resource is missing." if levels[index] == null else levels[index].validation_error()
		if not error.is_empty():
			push_error("Level sequence position %d: %s" % [index + 1, error])
			ball.set_physics_process(false)
			return
	bricks.load_level(levels[0])
	hud.update_level(1)
	hud.continue_pressed.connect(continue_level)
	hud.update_message("")
	hud.update_score(score)
	hud.update_lives(lives)
	hud.restart_pressed.connect(restart)
	hud.back_to_title_pressed.connect(back_to_title)
	_count_destructible_bricks()

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
	return ball.launched and not reset_ready and not level_complete

func _on_death_zone_body_entered(_body: Node2D) -> void:
	if reset_ready or level_complete:
		return
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

func _on_ball_brick_broken(points: int) -> void:
	if reset_ready or level_complete:
		return
	bricks_left -= 1
	score += points
	hud.update_score(score)
	if bricks_left == 0:
		ball.reset()
		ball.set_physics_process(false)
		if current_level_index + 1 < levels.size():
			level_complete = true
			paddle.set_physics_process(false)
			hud.update_message("Level %d Complete!" % (current_level_index + 1))
			hud.show_continue_button()
		else:
			reset_ready = true
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

func continue_level() -> void:
	if not level_complete:
		return
	# Unreachable today: _ready() already validated every level in the sequence,
	# using the same validation_error() that load_level() checks. If it ever
	# fails anyway, load_level() has pushed the error and the old layout stays.
	if not bricks.load_level(levels[current_level_index + 1]):
		return
	current_level_index += 1
	_count_destructible_bricks()
	paddle.position = paddle_start
	paddle.velocity = Vector2.ZERO
	paddle.following_mouse = false
	ball.reset()
	hud.update_level(current_level_index + 1)
	hud.hide_continue_button()
	hud.update_message("")
	level_complete = false
	paddle.set_physics_process(true)
	ball.set_physics_process(true)

func _count_destructible_bricks() -> void:
	bricks_left = 0
	for brick in bricks.get_children():
		if brick.definition.destructible:
			bricks_left += 1
