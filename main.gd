extends Node2D

const EffectRules = preload("res://effect_rules.gd")
const BallRules = preload("res://ball_rules.gd")
const Capsule = preload("res://capsule.tscn")
var effects = EffectRules.new()
var force_field_charges := 0
var capsule_rng := RandomNumberGenerator.new()

const COMPANION_SCENE = preload("res://companion_paddle.tscn")
var companion_generation := 0
var companions: Array[Node2D] = []


const BOLT_SCENE = preload("res://blaster_bolt.tscn")
const BALL_SCENE = preload("res://ball.tscn")
const OrbVisual = preload("res://placeholder_satellite_orbs.gd")
const BRICK_BURST_SCENE = preload("res://placeholder_brick_burst.tscn")

# Shake sizes in pixels and seconds. MainBG extends 32 px past the viewport so
# the strongest shake never shows the clear colour at the edges.
const HAZARD_SHAKE := Vector2(8.0, 0.25)
const LIFE_LOST_SHAKE := Vector2(16.0, 0.4)

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
@onready var screen_shake := $ScreenShake
var current_level_index := 0
var level_complete := false
var paddle_start: Vector2
var score = 0
var bricks_left = 0
var reset_ready := false
# Satellite Shield is charge-based, so its count lives here rather than in the
# timed effects dictionary. The orbs are drawn only; they become balls at launch.
var satellite_orbs := 0:
	set(value):
		satellite_orbs = value
		if orb_visual:
			orb_visual.count = value
var orb_visual: Node2D

func _ready() -> void:
	capsule_rng.randomize()
	bricks.capsule_dropped.connect(_spawn_capsule)
	bricks.brick_destroyed.connect(_spawn_brick_burst)
	paddle_start = paddle.position
	# A child of the paddle, so the orbit follows it without extra code.
	orb_visual = OrbVisual.new()
	orb_visual.name = "PlaceholderSatelliteOrbs"
	paddle.add_child(orb_visual)
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
	_count_completion_bricks()

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
	screen_shake.shake(LIFE_LOST_SHAKE.x, LIFE_LOST_SHAKE.y)
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
	_count_completion_bricks()
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
	_count_completion_bricks()
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

func _count_completion_bricks() -> void:
	bricks_left = 0
	for brick in bricks.get_children():
		if brick.definition.counts_for_completion and not brick.is_queued_for_deletion():
			bricks_left += 1

func _physics_process(delta: float) -> void:
	effects.advance(delta)
	if not reset_ready and not level_complete and Input.is_action_just_pressed("power_action"):
		if effects.fire_blaster():
			var bolt = BOLT_SCENE.instantiate()
			bolt.position = $PlayArea.to_local(paddle.global_position)
			bolt.speed = effects.active[&"blaster"].definition.bolt_speed
			bolt.brick_broken.connect(_on_ball_brick_broken)
			$PlayArea.add_child(bolt)
	_update_ball_effects()
	paddle.set_width_multiplier(effects.width_multiplier())
	hud.update_effects(effects.active, force_field_charges)
	orb_visual.orbit_size.x = paddle.half_width + 28.0
	# Read in the physics step, like ball.gd, so both see the same "just pressed".
	# No arbitration: one press can also fire Blaster and release a Sticky catch.
	if Input.is_action_just_pressed("power_action"):
		launch_orb()

# Turns one waiting orb into an ordinary ball. Its Breaker timer starts now
# (ADR-0001), so time spent orbiting never counts against it.
func launch_orb() -> Node2D:
	if reset_ready or level_complete:
		return null
	if not EffectRules.can_launch_orb(satellite_orbs, _ball_waiting_to_launch()):
		return null
	satellite_orbs -= 1
	var orb_ball = add_ball()
	orb_ball.breaker_active = true
	orb_ball.launched = true
	orb_ball.velocity = BallRules.launch_direction() * orb_ball.speed * orb_ball.speed_multiplier
	return orb_ball

func _ball_waiting_to_launch() -> bool:
	for active_ball in get_balls():
		if not active_ball.launched:
			return true
	return false

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

# Every destroyed brick, whichever ball or bolt hit it. The final brick of a
# level gets its burst too, so there is no end-of-level check here.
func _spawn_brick_burst(at: Vector2) -> void:
	var burst := BRICK_BURST_SCENE.instantiate()
	burst.add_to_group("brick_burst")
	burst.position = $PlayArea.to_local(at)
	$PlayArea.add_child(burst)

func _catch_capsule(effect: Resource) -> void:
	if reset_ready or level_complete:
		return
	var negated := EffectRules.negates_hazard(effect, force_field_charges)
	force_field_charges = EffectRules.charges_after_catch(effect, force_field_charges)
	if negated:
		hud.update_effects(effects.active, force_field_charges)
		return
	if effect.hazard:
		screen_shake.shake(HAZARD_SHAKE.x, HAZARD_SHAKE.y)
	if effect.companion_count > 0:
		companion_generation += 1
		_replace_companions.call_deferred(effect, companion_generation)
	if effect.extra_balls > 0:
		_split_ball(effect)
	effects.apply(effect)
	satellite_orbs = EffectRules.orbs_after_catch(satellite_orbs, effect)
	if effect.id == &"breaker":
		for active_ball in get_balls():
			active_ball.breaker_time_left = effect.duration
	_update_ball_effects()
	paddle.set_width_multiplier(effects.width_multiplier())
	hud.update_effects(effects.active, force_field_charges)
	score += EffectRules.catch_points(effect)
	lives += effect.extra_lives
	hud.update_score(score)
	hud.update_lives(lives)

func _clear_effects_and_capsules() -> void:
	companion_generation += 1
	_clear_companions()
	effects.active.clear()
	satellite_orbs = 0
	effects.shot_time_left = 0.0
	for bolt in get_tree().get_nodes_in_group("blaster_bolt"):
		if is_ancestor_of(bolt):
			bolt.queue_free()
	force_field_charges = 0
	for active_ball in get_balls():
		active_ball.breaker_active = false
	_update_ball_effects()
	hud.update_effects(effects.active, force_field_charges)
	paddle.set_width_multiplier(1.0)
	for capsule in get_tree().get_nodes_in_group("capsule"):
		capsule.queue_free()

# Every instance must report score to main.
func add_ball() -> Node2D:
	var new_ball = BALL_SCENE.instantiate()
	new_ball.paddle = paddle
	_connect_ball(new_ball)
	$PlayArea.add_child(new_ball)
	# Copies share a spawn point, so ignore other balls while retaining walls,
	# bricks and paddle collisions. Exceptions leave the scene layers intact.
	for other in get_balls():
		if other != new_ball:
			new_ball.add_collision_exception_with(other)
			other.add_collision_exception_with(new_ball)
	new_ball.reset()
	new_ball.set_speed_multiplier(effects.speed_multiplier())
	new_ball.set_sticky_active(effects.active.has(&"sticky_paddle"))
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

func _split_ball(effect: Resource) -> void:
	var balls := get_balls()
	if balls.is_empty():
		return
	var source = balls[0]
	for candidate in balls:
		if candidate.launched:
			source = candidate
			break
	# Capsule catches arrive during physics queries; add bodies after they finish.
	_add_split_balls.call_deferred(source, effect)

func _add_split_balls(source: Node2D, effect: Resource) -> void:
	# A last-ball loss or level completion can occur before the deferred split.
	if reset_ready or level_complete or not is_instance_valid(source):
		return
	if source.is_queued_for_deletion() or not get_balls().has(source):
		return
	# Balls do not collide with each other. A common origin avoids placing a
	# copy inside a nearby wall or brick; the rotated velocities separate them.
	var split_velocities := EffectRules.split_velocities(source.velocity, effect)
	for index in range(split_velocities.size()):
		var split_velocity: Vector2 = split_velocities[index]
		var copy = add_ball()
		copy.position = source.position
		copy.speed = source.speed
		copy.launched = source.launched
		copy.velocity = split_velocity
		copy.breaker_time_left = source.breaker_time_left
		# A caught source has zero velocity: copies must wait for release too.
		copy.caught = source.caught
		copy.catch_offset = source.catch_offset
		copy.caught_speed = source.caught_speed
		if source.caught:
			var angle := deg_to_rad(float(effect.split_angle_degrees))
			copy.release_rotation = source.release_rotation + (-angle if index == 0 else angle)

func _update_ball_effects() -> void:
	var multiplier: float = effects.speed_multiplier()
	for active_ball in get_balls():
		active_ball.set_speed_multiplier(multiplier)
		active_ball.set_sticky_active(effects.active.has(&"sticky_paddle"))

func _clear_companions() -> void:
	for companion in companions:
		if is_instance_valid(companion) and not companion.is_queued_for_deletion():
			companion.queue_free()
	companions.clear()

func _replace_companions(effect: Resource, generation: int) -> void:
	if generation != companion_generation or reset_ready or level_complete:
		return
	_clear_companions()
	for index in effect.companion_count:
		var companion = COMPANION_SCENE.instantiate()
		companion.main_paddle = paddle
		companion.health = effect.companion_health
		companion.follow_speed = effect.companion_follow_speed
		var left_wall = $PlayArea/Walls/Left
		var right_wall = $PlayArea/Walls/Right
		companion.horizontal_bounds = Vector2(
			left_wall.global_position.x + left_wall.shape.size.x / 2.0,
			right_wall.global_position.x - right_wall.shape.size.x / 2.0)
		companion.offset = Vector2(effect.companion_offset.x * (-1 if index == 0 else 1), effect.companion_offset.y)
		$PlayArea.add_child(companion)
		companion.global_position = paddle.global_position + companion.offset
		companion._physics_process(0.0)
		companions.append(companion)
		companion.destroyed.connect(_on_companion_destroyed)

func _on_companion_destroyed() -> void:
	var survivors: Array[Node2D] = []
	for companion in companions:
		if is_instance_valid(companion) and not companion.is_queued_for_deletion():
			survivors.append(companion)
	companions = survivors
	if companions.size() == 1:
		companions[0].offset.x = 0.0
