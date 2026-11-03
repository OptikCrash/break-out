extends SceneTree

const BrickRules = preload("res://brick_rules.gd")
var failures := 0
var awards: Array[int] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Content IDs, symbols and numbers are part of the level format contract.
	var expected := [[&"normal", "#", 1, 10, true], [&"reinforced", "x", 2, 20, true], [&"indestructible", "o", 0, 0, false]]
	var ids := []
	var symbols := []
	for i in expected.size():
		var definition = BrickRules.DEFINITIONS[i]
		_check(definition.validation_error().is_empty(), "Definition must validate")
		_check(not ids.has(definition.id) and not symbols.has(definition.grid_symbol), "IDs and symbols must be unique")
		ids.append(definition.id)
		symbols.append(definition.grid_symbol)
		_check([definition.id, definition.grid_symbol, definition.hit_points, definition.points, definition.destructible] == expected[i], "Pin type ID, symbol, hit points, score and destructibility")
		_check(BrickRules.definition_for_symbol(definition.grid_symbol) == definition, "Symbol resolves to its definition")
	_check(BrickRules.definition_for_symbol("?") == null, "Unknown symbols have no definition")
	_check(BrickRules.remaining_hit_points(2, true) == 1, "First reinforced hit leaves one HP")
	_check(BrickRules.remaining_hit_points(1, true) == 0, "Final hit leaves zero HP")
	_check(BrickRules.remaining_hit_points(0, true) == 0, "HP cannot become negative")
	_check(BrickRules.remaining_hit_points(0, false) == 0, "Indestructible HP does not count down")
	var invalid = BrickRules.DEFINITIONS[0].duplicate()
	invalid.id = &""
	_check(not invalid.validation_error().is_empty(), "Empty IDs fail validation")
	invalid = BrickRules.DEFINITIONS[0].duplicate()
	invalid.hit_points = 0
	_check(not invalid.validation_error().is_empty(), "Destructible bricks require hit points")
	invalid = BrickRules.DEFINITIONS[2].duplicate()
	invalid.points = 10
	_check(not invalid.validation_error().is_empty(), "Indestructible bricks cannot score")

	var game = preload("res://main.tscn").instantiate()
	var bricks = game.get_node("PlayArea/Bricks")
	bricks.level = Level.new()
	bricks.level.grid = "#xxo"
	game.levels.assign([bricks.level])
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	var ball = game.get_node("PlayArea/Ball")
	ball.brick_broken.connect(func(points: int): awards.append(points))
	var normal = bricks.get_child(0)
	var reinforced = bricks.get_child(1)
	var other_reinforced = bricks.get_child(2)
	var indestructible = bricks.get_child(3)
	_check(game.bricks_left == 3, "Indestructible bricks excluded at start")
	_check(normal.type_id == &"normal" and reinforced.type_id == &"reinforced" and indestructible.type_id == &"indestructible", "Loader instantiates the specified types")
	var intact_color: Color = reinforced.get_node("CollisionShape2D/ColorRect").color
	ball._break_brick(reinforced)
	_check(reinforced.hit_points == 1 and not reinforced.is_queued_for_deletion(), "Reinforced survives its first hit")
	_check(reinforced.get_node("CollisionShape2D/ColorRect").color != intact_color, "First hit changes appearance")
	_check(other_reinforced.hit_points == 2 and reinforced.definition.hit_points == 2, "Damage belongs to the instance, not shared content")
	_check(game.score == 0 and awards.is_empty() and game.bricks_left == 3, "Intermediate hits award no score or signal")
	for i in 10:
		ball._break_brick(indestructible)
	_check(not indestructible.is_queued_for_deletion() and indestructible.hit_points == 0, "Indestructible survives repeated hits")
	_check(game.score == 0 and awards.is_empty() and game.bricks_left == 3, "Indestructible never scores or emits")
	ball._break_brick(normal)
	ball._break_brick(reinforced)
	ball._break_brick(reinforced)
	_check(reinforced.is_queued_for_deletion() and game.score == 30 and awards == [10, 20], "Repeated final reinforced hit awards 20 exactly once")
	_check(game.bricks_left == 1 and not game.reset_ready, "Other reinforced brick still prevents a win")
	ball._break_brick(other_reinforced)
	ball._break_brick(other_reinforced)
	ball._break_brick(other_reinforced)
	_check(game.score == 50 and awards == [10, 20, 20], "Final brick destruction scores once")
	_check(game.bricks_left == 0 and game.reset_ready, "Clearing destructible bricks wins with indestructible remaining")
	_check(not indestructible.is_queued_for_deletion(), "Winning leaves indestructible brick intact")
	_check(not ball.launched and not ball.is_physics_processing(), "Win stops the ball")
	_check(game.get_node("Hud/MessageLabel").text == "You Win!", "Mixed level displays win message")
	game.free()
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1
