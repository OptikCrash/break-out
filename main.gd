extends Node2D

const EffectRules = preload("res://effect_rules.gd")
const Capsule = preload("res://capsule.tscn")
var effects = EffectRules.new()
var capsule_rng := RandomNumberGenerator.new()

const BALL_SCENE = preload("res://ball.tscn")

const TITLE_SCENE := "res://TitleScreen.tscn"

@export var levels: Array[Level] = [
	preload("res://levels/level_1.tres"),
	preload("res://levels/level_2.tres"),
	preload("res://levels/level_3.tres"),
]
@export var lives = 3
@onready var paddle := $PlayArea/Paddle
# Convenience for callers needing the first ball; lifecycle uses the whole group.
var ball: Node2D:
	get:
		return get_balls()[0] if not get_balls().is_empty() else null
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
	capsule_rng.randomize()
	bricks.capsule_dropped.connect(_spawn_capsule)
	paddle_start = paddle.position
	for active_ball in get_balls():
		_connect_ball(active_ball)
	if levels.is_empty():
		push_error("Level sequence must contain at least one Level.")
		_stop_balls()
		return
	for index in levels.size():
		var error := "Level resource is missing." if levels[index] == null else levels[index].validation_error()
		if not error.is_empty():
			push_error("Level sequence position %d: %s" % [index + 1, error])
			_stop_balls()
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
	if reset_ready or level_complete:
		return false
	for active_ball in get_balls():
		if active_ball.launched:
			return true
	return false

func _on_death_zone_body_entered(body: Node2D) -> void:
	if reset_ready or level_complete:
		return
	if not body.is_in_group("ball") or body.is_queued_for_deletion():
		return
	# Remove membership now: queue_free() only deletes at the end of the frame.
	body.remove_from_group("ball")
	body.set_physics_process(false)
	body.queue_free()
	if not get_balls().is_empty():
		return
	_clear_effects_and_capsules()
	lives -= 1
	hud.update_lives(lives)
	if lives == 0:
		reset_ready = true
		hud.update_message("Game Over!")
		hud.show_end_buttons()
	else:
		print("Lives left: ", lives)
		add_ball()

func _on_ball_brick_broken(points: int) -> void:
	if reset_ready or level_complete:
		return
	_count_destructible_bricks()
	score += points
	hud.update_score(score)
	if bricks_left == 0:
		_clear_effects_and_capsules()
		for active_ball in get_balls():
			active_ball.reset()
		_stop_balls()
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
	for active_ball in get_balls():
		active_ball.reset()
	hud.update_level(current_level_index + 1)
	hud.hide_continue_button()
	hud.update_message("")
	level_complete = false
	paddle.set_physics_process(true)
	for active_ball in get_balls():
		active_ball.set_physics_process(true)

func _count_destructible_bricks() -> void:
	bricks_left = 0
	for brick in bricks.get_children():
		if brick.definition.counts_for_completion and not brick.is_queued_for_deletion():
			bricks_left += 1

func _physics_process(delta: float) -> void:
	effects.advance(delta)
	paddle.set_width_multiplier(effects.width_multiplier())
	hud.update_effects(effects.active)

# Physics-query callbacks cannot safely add a monitoring Area2D directly.
func _spawn_capsule(at: Vector2) -> void:
	_add_capsule.call_deferred(at)

func _add_capsule(at: Vector2) -> void:
	if reset_ready or level_complete:
		return
	var capsule := Capsule.instantiate()
	capsule.effect = EffectRules.random_effect(capsule_rng)
	capsule.position = $PlayArea.to_local(at)
	capsule.caught.connect(_catch_capsule)
	$PlayArea.add_child(capsule)

func _catch_capsule(effect: Resource) -> void:
	if reset_ready or level_complete:
		return
	effects.apply(effect)
	if effect.id == &"breaker":
		for active_ball in get_balls():
			active_ball.breaker_time_left = effect.duration
	paddle.set_width_multiplier(effects.width_multiplier())
	hud.update_effects(effects.active)
	score += EffectRules.catch_points(effect)
	lives += effect.extra_lives
	hud.update_score(score)
	hud.update_lives(lives)

func _clear_effects_and_capsules() -> void:
	effects.active.clear()
	for active_ball in get_balls():
		active_ball.breaker_active = false
	hud.update_effects(effects.active)
	paddle.set_width_multiplier(1.0)
	for capsule in get_tree().get_nodes_in_group("capsule"):
		capsule.queue_free()

# Future Multi-ball creation uses this so every instance reports score to main.
func add_ball() -> Node2D:
	var new_ball = BALL_SCENE.instantiate()
	new_ball.paddle = paddle
	_connect_ball(new_ball)
	$PlayArea.add_child(new_ball)
	new_ball.reset()
	return new_ball

func _connect_ball(active_ball: Node2D) -> void:
	if not active_ball.brick_broken.is_connected(_on_ball_brick_broken):
		active_ball.brick_broken.connect(_on_ball_brick_broken)

func get_balls() -> Array[Node]:
	var active: Array[Node] = []
	for candidate in get_tree().get_nodes_in_group("ball"):
		if is_ancestor_of(candidate) and not candidate.is_queued_for_deletion():
			active.append(candidate)
	return active

func _stop_balls() -> void:
	for active_ball in get_balls():
		active_ball.set_physics_process(false)
