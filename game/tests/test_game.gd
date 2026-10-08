extends GutTest

# game.gd: spawning the levels and the player, and handing the
# player to input, camera, renderer and overlay. Each test runs a
# fresh game.tscn, so _ready has already spawned all eight levels
# and one player by the time the test body runs.

var _game: Node


func before_each() -> void:
	_game = load("res://scenes/game.tscn").instantiate()
	add_child_autofree(_game)


func _levels() -> Array[Level]:
	var levels: Array[Level] = []
	for child in _game.get_node("Levels").get_children():
		if child is Level: levels.append(child)
	return levels


func _actors() -> Array[Actor]:
	var actors: Array[Actor] = []
	for child in _game.get_node("GameViewport/Actors/Players").get_children():
		if child is Actor: actors.append(child)
	return actors


# Input handlers live directly under Game, outside the game viewport,
# so their _input fires without events being pushed in.
func _handler_for(actor: Actor) -> InputHandler:
	for child in _game.get_children():
		if child is InputHandler and child.actor == actor: return child
	return null


# --- levels ---

func test_ready_spawns_each_depth_once() -> void:
	for depth in range(8):
		var count: int = _levels().filter(
			func(level: Level) -> bool: return level.depth == depth).size()
		assert_eq(count, 1, "exactly one level at depth %d" % depth)


func test_spawn_level_adds_a_level_at_that_depth() -> void:
	var before: int = _levels().size()
	_game._spawn_level(3)
	var levels: Array[Level] = _levels()
	assert_eq(levels.size(), before + 1, "one more level under Levels")
	assert_eq(levels.back().depth, 3, "and it is at the depth asked for")


func test_spawn_levels_adds_one_per_depth() -> void:
	var before: int = _levels().size()
	_game._spawn_levels()
	var levels: Array[Level] = _levels()
	assert_eq(levels.size(), before + 8, "one level per depth in the list")
	assert_eq(levels[-2].depth, 6, "in the correct order")
	assert_eq(levels[-1].depth, 7, "in the correct order")


func test_get_level_finds_every_depth() -> void:
	for depth in range(8):
		var level: Level = _game.get_level(depth)
		assert_not_null(level, "depth %d is resident" % depth)
		if level: assert_eq(level.depth, depth, "and is the right one")


func test_get_level_returns_null_for_a_missing_depth() -> void:
	assert_null(_game.get_level(99), "no level exists at depth 99")


# --- the player ---

func test_ready_spawns_exactly_one_player() -> void:
	assert_eq(_actors().size(), 1, "one actor under Players")


func test_player_spawns_on_the_surface() -> void:
	assert_eq(_actors()[0].depth, 0,
		"the player starts at depth 0, the level being drawn")


# The regression this file was written for: the player once spawned
# at depth 1, which is solid rock, while Surface was on screen.
func test_player_spawns_on_open_floor() -> void:
	var actor: Actor = _actors()[0]
	var tiles: LevelTiles = _game.get_level(actor.depth).level_tiles
	var pos: WorldPos = actor.current_WorldPos
	assert_eq(tiles.get_top(pos.x, pos.y), TileKind.TOP.OPEN,
		"the spawn tile is open floor, not inside rock")


func test_player_spawns_on_the_surface_anchor() -> void:
	var anchor: Vector2i = _game.get_level(0).anchor
	assert_true(_actors()[0].current_WorldPos.equals(
		WorldPos.new(anchor.x, anchor.y, 0)),
		"the player stands on Surface's anchor tile")


func test_spawn_player_without_a_level_adds_no_player() -> void:
	var before: int = _actors().size()
	_game._spawn_player("TestPlayer", 99)
	assert_push_error("Level (99) not found")
	assert_eq(_actors().size(), before, "no actor is created")


func test_create_player_uses_the_levels_depth_and_anchor() -> void:
	var level: Level = _game.get_level(2)
	var actor: Actor = _game._create_player("TestPlayer", level)
	assert_true(actor in _actors(), "the actor is added under Players")
	assert_true(actor.current_WorldPos.equals(
		WorldPos.new(level.anchor.x, level.anchor.y, 2)),
		"it stands on that level's anchor, at that level's depth")


# --- user control ---

func _actor_at_depth(depth: int) -> Actor:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(0, 0, depth))
	_game.get_node("GameViewport/Actors/Players").add_child(actor)
	return actor


func test_user_control_gives_the_actor_an_input_handler() -> void:
	var actor: Actor = _actor_at_depth(3)
	_game.set_user_control(actor)
	assert_not_null(_handler_for(actor),
		"an InputHandler driving this actor is under Game")


func test_user_control_points_the_camera_at_the_actor() -> void:
	var actor: Actor = _actor_at_depth(3)
	_game.set_user_control(actor)
	assert_eq(_game.get_view_camera().actor, actor,
		"the view camera follows the controlled actor")


func test_user_control_draws_the_actors_level() -> void:
	var actor: Actor = _actor_at_depth(3)
	_game.set_user_control(actor)
	var renderer: LevelRenderer = _game.get_node("GameViewport/LevelRenderer")
	var top: Texture2D = renderer.material.get_shader_parameter("top_data")
	var expected: int = LevelRenderer.level_width(_game.get_level(3).level_tiles)
	assert_eq(top.get_width(), expected,
		"the renderer shows depth 3, whose texture is %d tiles wide" % expected)


func test_user_control_puts_the_actor_on_the_overlay() -> void:
	var actor: Actor = _actor_at_depth(3)
	_game.set_user_control(actor)
	var overlay: Node = _game.get_node("DebugOverlay")
	assert_true(overlay.watched_actors.has(actor.get_instance_id()),
		"the debug overlay watches the controlled actor")


func test_get_view_camera_is_the_view_camera() -> void:
	assert_eq(_game.get_view_camera(), _game.get_node("GameViewport/ViewCamera"),
		"returns the camera under GameViewport")
