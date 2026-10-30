extends GutTest

# game.gd: spawning the levels and the player, and handing the
# player to input, camera, renderer and overlay. Each test runs a
# fresh game.tscn, so _ready has already spawned all eight levels
# and one player by the time the test body runs.

const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/game"

var _game: Node


func before_each() -> void:
	_game = load("res://scenes/game.tscn").instantiate()
	_game.saves_root = SAVES_ROOT
	add_child_autofree(_game)


func after_each() -> void:
	SaveDirs.remove_tree(SAVES_ROOT)


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


# --- saves ---

# The test root holds no slots, so the game picks none, even when the
# real saves folder has one.
func test_ready_looks_for_slots_only_under_its_saves_root() -> void:
	assert_eq(_game.current_save_slot, "", "no slot under the test root")


func test_the_first_save_makes_its_slot_under_the_saves_root() -> void:
	assert_true(_game.save_game(), "the save succeeds")
	assert_eq(_game.current_save_slot, SAVES_ROOT.path_join("slot-001"),
		"the slot is made under the test root")
	assert_true(FileAccess.file_exists(
		SAVES_ROOT.path_join("slot-001").path_join(SaveGame.SAVE_BASE_NAME)),
		"and the save is written there")


# The F6 path end to end: the old world goes, and the loaded player
# stands on a loaded level that is in the tree, not a freed one.
func test_a_load_puts_the_player_on_a_level_in_the_tree() -> void:
	var old_player: Actor = _game.active_actor
	assert_true(_game.save_game(), "saved first")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	var player: Actor = _game.active_actor
	assert_ne(player, old_player, "a new actor, built by the load")
	assert_false(is_instance_valid(old_player), "the old one is freed")
	assert_true(is_instance_valid(player.current_level), "its level is not freed")
	assert_true(player.current_level.is_inside_tree(), "and is in the tree")
	assert_true(player.current_level in _levels(), "under Levels")


func _save_file() -> String:
	return SAVES_ROOT.path_join("slot-001").path_join(SaveGame.SAVE_BASE_NAME)


# A whole generated world loads clean, and F3 says so (D-113).
func test_a_load_shows_its_problem_count_in_f3() -> void:
	assert_true(_game.save_game(), "saved first")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	var overlay: Node = _game.get_node("DebugOverlay")
	assert_eq(overlay.debug_text[overlay.LOAD_PROBLEMS_SECTION].text, "0",
		"no problems in a generated world")


# Ladders and the world spawn come back with their ids (D-091, D-104).
func test_a_load_brings_back_every_fixture() -> void:
	var before: Array = _fixture_ids()
	assert_gt(before.size(), 0, "the generated world has fixtures")
	assert_true(_game.save_game(), "saved first")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	assert_eq(_fixture_ids(), before, "the same fixtures, by id")


func _fixture_ids() -> Array:
	var ids: Array = []
	for level: Level in _levels():
		for fixture: Fixture in level.level_fixtures.all():
			ids.append(fixture.id)
	ids.sort()
	return ids


# Every level change saves, once the player has arrived (D-110).
func test_changing_level_saves_with_the_player_on_the_new_level() -> void:
	var actor: Actor = _game.active_actor
	var here: WorldPos = actor.current_WorldPos
	assert_false(FileAccess.file_exists(_save_file()), "no save yet")
	assert_true(actor.change_depth(WorldPos.new(here.x, here.y, 1)), "the player moves to -1")
	assert_true(FileAccess.file_exists(_save_file()), "the move saved")
	var saved: Dictionary = SaveGame.get_save_data(SAVES_ROOT.path_join("slot-001"))
	assert_eq(saved.actors[actor.actor_name].worldpos.depth, 1, "with the player on -1")


func test_moving_within_a_level_does_not_save() -> void:
	var actor: Actor = _game.active_actor
	actor.position += Vector2(TileSpace.TILE_PIXELS, 0)
	actor._update_WorldPos()
	assert_false(FileAccess.file_exists(_save_file()), "a step is not a save")


# --- levels ---

func test_ready_spawns_each_depth_once() -> void:
	for depth in range(8):
		var count: int = _levels().filter(
			func(level: Level) -> bool: return level.depth == depth).size()
		assert_eq(count, 1, "exactly one level at depth %d" % depth)


func test_spawn_levels_adds_one_per_depth() -> void:
	var before: int = _levels().size()
	_game._spawn_levels()
	var levels: Array[Level] = _levels()
	assert_eq(levels.size(), before + 8, "one level per depth in the list")
	assert_eq(levels[-2].depth, 6, "in the correct order")
	assert_eq(levels[-1].depth, 7, "in the correct order")


func test_get_level_finds_every_depth() -> void:
	for depth in range(8):
		var level: Level = World.get_level_by_depth(depth)
		assert_not_null(level, "depth %d is resident" % depth)
		if level: assert_eq(level.depth, depth, "and is the right one")


func test_get_level_returns_null_for_a_missing_depth() -> void:
	assert_null(World.get_level_by_depth(99), "no level exists at depth 99")


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
	var tiles: LevelTiles = World.get_level_by_depth(actor.depth).level_tiles
	var pos: WorldPos = actor.current_WorldPos
	assert_eq(tiles.get_top(pos.x, pos.y), TileKind.TOP.OPEN,
		"the spawn tile is open floor, not inside rock")


func _world_spawn() -> Fixture:
	return World.get_level_by_depth(0).level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN)[0]


func test_player_spawns_on_the_world_spawn() -> void:
	assert_true(_actors()[0].current_WorldPos.equals(_world_spawn().tile),
		"the first player stands on the world spawn (D-091)")


func test_a_second_player_spawns_beside_the_first() -> void:
	_game._spawn_player("Second")
	var actors: Array[Actor] = _actors()
	assert_eq(actors.size(), 2, "two players")
	assert_false(actors[0].current_WorldPos.equals(actors[1].current_WorldPos), "on different tiles")
	assert_false(actors[0].get_world_box().intersects(actors[1].get_world_box()), "not overlapping")


func test_spawn_player_with_no_world_spawn_adds_no_player() -> void:
	var fixtures: LevelFixtures = World.get_level_by_depth(0).level_fixtures
	fixtures.remove(_world_spawn().id)
	var before: int = _actors().size()
	_game._spawn_player("TestPlayer")
	assert_push_error("Expected one world spawn, found 0.")
	assert_push_error("Nowhere to spawn TestPlayer.")
	assert_eq(_actors().size(), before, "no actor is created")


func test_create_player_stands_on_the_tile_given() -> void:
	var _pos: WorldPos = WorldPos.new(14, -2, 2)
	var actor: Actor = Actor.create(Global.actor_packed_scene, "TestPlayer", _pos, World.get_level_by_depth(_pos.depth), ActorKind.ACTOR.PLAYER)
	actor = _game._create_player(actor)
	assert_true(actor in _actors(), "the actor is added under Players")
	assert_true(actor.current_WorldPos.equals(_pos),
		"on that tile, at that depth")


# --- user control ---

func _actor_at_depth(depth: int) -> Actor:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(0, 0, depth), World.get_level_by_depth(depth), ActorKind.ACTOR.PLAYER)
	_game.get_node("GameViewport/Actors/Players").add_child(actor)
	return actor


func test_user_control_gives_the_actor_an_input_handler() -> void:
	var actor: Actor = _actor_at_depth(3)
	_game.set_user_control(actor)
	assert_not_null(_handler_for(actor),
		"an InputHandler driving this actor is under Game")


# Found by the reference game.gd keeps, not by name: a renamed handler
# still goes, and an unrelated node named like one stays.
func test_freeing_input_handlers_frees_only_the_games_own() -> void:
	var actor: Actor = _actor_at_depth(3)
	_game.set_user_control(actor)
	var handler: InputHandler = _handler_for(actor)
	handler.name = "Renamed"
	var lookalike: Node = Node.new()
	lookalike.name = "InputHandlerLookalike"
	_game.add_child(lookalike)
	_game._free_inputhandlers()
	assert_false(is_instance_valid(handler), "the renamed handler is freed")
	assert_true(is_instance_valid(lookalike), "the lookalike is left alone")
	assert_eq(_game._input_handlers.size(), 0, "and the list is emptied")


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
	var expected: int = LevelRenderer.level_width(World.get_level_by_depth(3).level_tiles)
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


# --- mouse_world_position ---

# A test can't move the mouse, so these vary the display's size
# instead and read wherever the mouse happens to be: the window's
# corner in a headless run, the real pointer when run from the
# editor. That exercises the part of the mapping that is our own
# arithmetic (undoing the scale and the letterbox) for 16:10 (exact
# fit), a wide screen (bars left and right) and a tall one (bars top
# and bottom). Each case states its scale and letterbox by hand.
#
# Game pixels = (mouse on the display - letterbox) / scale. The
# camera's own transform (the built-in part) is then undone to get
# the world.
func _check_mouse_mapping(display_size: Vector2, scale: float,
		letterbox: Vector2, message: String) -> void:
	var display: TextureRect = _game.get_node("Display/UpscaleDisplay")
	display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	display.position = Vector2.ZERO
	display.size = display_size
	var view: SubViewport = _game.get_node("GameViewport")
	var mouse: Vector2 = display.get_local_mouse_position()
	var view_px: Vector2 = (mouse - letterbox) / scale
	var expected: Vector2 = view.get_canvas_transform().affine_inverse() * view_px
	assert_almost_eq(_game.mouse_world_position(), expected,
		Vector2(0.01, 0.01), "%s (mouse at %s on the display)" % [message, mouse])


func test_mouse_maps_through_an_exact_16_10_display() -> void:
	# 1280 x 800 is 2.5 x 512 x 320: no letterbox.
	_check_mouse_mapping(Vector2(1280, 800), 2.5, Vector2.ZERO,
		"an exact fit only scales")


func test_mouse_maps_through_side_bars() -> void:
	# 1920 x 1080: scale 3.375, image 1728 wide, 96 px bars each side.
	_check_mouse_mapping(Vector2(1920, 1080), 3.375, Vector2(96, 0),
		"side bars shift x, not y")


func test_mouse_maps_through_top_and_bottom_bars() -> void:
	# 1280 x 1024: scale 2.5, image 800 tall, 112 px bars top and bottom.
	_check_mouse_mapping(Vector2(1280, 1024), 2.5, Vector2(0, 112),
		"top and bottom bars shift y, not x")


# The screen follows the player down (D-094). The Surface spawn sits
# over -1's home cave, so the landing is open.
func test_the_screen_follows_the_player_down_a_level() -> void:
	var actor: Actor = _actors()[0]
	var here: WorldPos = actor.current_WorldPos
	assert_true(actor.change_depth(WorldPos.new(here.x, here.y, 1)), "the player moves to -1")
	var renderer: LevelRenderer = _game.get_node("GameViewport/LevelRenderer")
	var top: Texture2D = renderer.material.get_shader_parameter("top_data")
	var expected: int = LevelRenderer.level_width(World.get_level_by_depth(1).level_tiles)
	assert_eq(top.get_width(), expected, "the renderer shows -1, %d tiles wide" % expected)
	assert_eq(_game.view.shown_depth, 1, "and the view says -1")
































