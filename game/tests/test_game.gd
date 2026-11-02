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
	assert_true(actor.move_to(WorldPos.new(here.x, here.y, 1)), "the player moves to -1")
	assert_true(FileAccess.file_exists(_save_file()), "the move saved")
	var saved: Dictionary = SaveGame.get_save_data(SAVES_ROOT.path_join("slot-001"))
	assert_eq(saved.actors[actor.actor_id].worldpos.depth, 1, "with the player on -1")


func test_moving_within_a_level_does_not_save() -> void:
	var actor: Actor = _game.active_actor
	actor.position += Vector2(TileSpace.TILE_PIXELS, 0)
	actor._update_WorldPos()
	assert_false(FileAccess.file_exists(_save_file()), "a step is not a save")


# --- launching over broken saves (D-111) ---

# Quits this game and launches another over the same saves root, so
# its _ready reads whatever the slot holds now.
func _relaunch() -> void:
	_game.free()
	_game = load("res://scenes/game.tscn").instantiate()
	_game.saves_root = SAVES_ROOT
	add_child_autofree(_game)


func _backup_file() -> String:
	return SAVES_ROOT.path_join("slot-001").path_join(SaveGame.BACKUP_NAME)


# Cuts a file off halfway, as a crash mid-write would.
func _truncate(path: String) -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes.slice(0, bytes.size() / 2))
	f.close()


func _f3_save_line() -> String:
	var overlay: Node = _game.get_node("DebugOverlay")
	return overlay.debug_text[overlay.SAVE_SECTION].text


func test_f3_says_a_fresh_launch_is_a_new_world() -> void:
	assert_eq(_game.load_source, SaveGame.SOURCE.NEW, "nothing to load")
	assert_eq(_f3_save_line(), "new, format %d" % SaveGame.FORMAT_VERSION, "F3 says so")
	assert_eq(_game.notice_text(), "", "and nothing on screen")


func test_f3_says_a_launch_over_a_save_loaded_it() -> void:
	assert_true(_game.save_game(), "saved")
	_relaunch()
	assert_eq(_game.load_source, SaveGame.SOURCE.SAVE, "the save loads")
	assert_eq(_f3_save_line(), "loaded, format %d" % SaveGame.FORMAT_VERSION, "F3 says so")


func test_a_launch_over_a_broken_save_loads_the_backup_loudly() -> void:
	assert_true(_game.save_game(), "saved once")
	assert_true(_game.save_game(), "and again, so there's a backup")
	_truncate(_save_file())
	_relaunch()

	assert_eq(_game.load_source, SaveGame.SOURCE.BACKUP, "the backup loads")
	assert_gt(_levels().size(), 0, "the world is there")
	assert_not_null(_game.active_actor, "and the player is given control")
	assert_push_error("Loaded the backup save")
	assert_string_contains(_game.notice_text(), "Loaded the backup save")
	assert_string_contains(_game.notice_text(), "cut short")
	assert_string_contains(_game.notice_text(), "world.broken.")
	assert_eq(_f3_save_line(), "loaded from the backup, format %d" % SaveGame.FORMAT_VERSION,
		"F3 says so")


func test_a_launch_with_both_saves_refused_does_not_start_or_save() -> void:
	assert_true(_game.save_game(), "saved once")
	assert_true(_game.save_game(), "and again, so there's a backup")
	_truncate(_save_file())
	_truncate(_backup_file())
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(_save_file())
	var backup_bytes: PackedByteArray = FileAccess.get_file_as_bytes(_backup_file())
	_relaunch()

	assert_eq(_game.load_source, SaveGame.SOURCE.REFUSED, "nothing loads")
	assert_eq(_levels().size(), 0, "no world")
	assert_eq(_actors().size(), 0, "no player")
	assert_null(_game.active_actor, "nobody in control")
	assert_push_error("No save could be loaded")
	assert_false(_game.save_game(), "saving is refused")
	assert_true(FileAccess.get_file_as_bytes(_save_file()) == save_bytes, "world.save untouched")
	assert_true(FileAccess.get_file_as_bytes(_backup_file()) == backup_bytes,
		"the backup untouched")
	var notice: String = _game.notice_text()
	# Each path with its reason: the save's path alone is a prefix of
	# the backup's
	assert_string_contains(notice, ProjectSettings.globalize_path(_save_file()) + " is cut short")
	assert_string_contains(notice, ProjectSettings.globalize_path(_backup_file()) + " is cut short")
	assert_eq(_f3_save_line(), "refused: nothing loaded", "F3 says so")


# --- loading actors (D-091, D-114, D-115) ---

func _actor_with_id(id: int) -> Actor:
	for actor: Actor in _actors():
		if actor.actor_id == id: return actor
	return null


# The player, moved straight down onto -1. The Surface spawn sits
# over -1's home cave, so the landing is open, and off the spawn.
func _player_on_minus_one() -> Actor:
	var actor: Actor = _game.active_actor
	var here: WorldPos = actor.current_WorldPos
	assert_true(actor.move_to(WorldPos.new(here.x, here.y, 1)), "the player moves to -1")
	return actor


# Only an impassable tile sends a loaded actor to the spawn.
func test_a_loaded_actor_on_open_floor_is_not_sent_to_the_spawn() -> void:
	var actor: Actor = _player_on_minus_one()
	var id: int = actor.actor_id
	var tile: WorldPos = actor.current_WorldPos
	assert_true(_game.save_game(), "saved")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	var loaded: Actor = _actor_with_id(id)
	assert_not_null(loaded, "the actor loads")
	if loaded == null: return
	assert_true(loaded.current_WorldPos.equals(tile),
		"on its saved tile %s, got %s" % [tile, loaded.current_WorldPos])


# D-115: rock fills the tile the actor saved on, as a change to
# passability in a later build could. It loads at the world spawn,
# by the path a new player takes, with one warning naming it and the
# tile it was on.
func test_an_actor_saved_on_a_tile_made_impassable_loads_at_the_spawn() -> void:
	var actor: Actor = _player_on_minus_one()
	var id: int = actor.actor_id
	var actor_name: String = actor.actor_name
	var stuck: WorldPos = actor.current_WorldPos
	World.get_level_by_depth(1).level_tiles.set_top(
		stuck.x, stuck.y, TileKind.TOP.MINABLE_ROCK)
	assert_true(_game.save_game(), "saved, standing in rock")
	var spawn: WorldPos = _world_spawn().tile

	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	var loaded: Actor = _actor_with_id(id)
	assert_not_null(loaded, "the actor still loads")
	if loaded == null: return
	assert_true(loaded.current_WorldPos.equals(spawn),
		"at the world spawn %s, got %s" % [spawn, loaded.current_WorldPos])
	assert_eq(loaded.current_level, World.get_level_by_depth(spawn.depth),
		"on the spawn's level")
	assert_eq(_warnings_naming([actor_name, str(stuck)]), 1,
		"one warning naming %s and %s" % [actor_name, stuck])


# How many push_warnings so far contain every one of texts. Each
# found is marked handled. assert_push_warning matches one text only,
# and this leaves the wording free.
func _warnings_naming(texts: Array) -> int:
	var count: int = 0
	for err in gut.error_tracker.get_errors_for_test():
		if err.handled or not err.is_push_warning(): continue
		var all: bool = true
		for text: String in texts:
			if not err.contains_text(text): all = false
		if all:
			err.handled = true
			count += 1
	return count


# A load never saves: a stuck actor moved across a depth would
# otherwise save a world half built, and rotate the good save into
# the backup (D-119).
func test_moving_a_stuck_actor_on_load_does_not_save() -> void:
	var actor: Actor = _player_on_minus_one()
	var actor_name: String = actor.actor_name
	var stuck: WorldPos = actor.current_WorldPos
	World.get_level_by_depth(1).level_tiles.set_top(
		stuck.x, stuck.y, TileKind.TOP.MINABLE_ROCK)
	assert_true(_game.save_game(), "saved, standing in rock")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(_save_file())
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(_save_file() + ".bak")

	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	assert_eq(_warnings_naming([actor_name]), 1, "the move is reported")
	# Compared as a bool: a failing byte compare prints both files
	assert_true(FileAccess.get_file_as_bytes(_save_file()) == saved, "the save is untouched")
	assert_true(FileAccess.get_file_as_bytes(_save_file() + ".bak") == backup,
		"and so is the backup")


# The spawn search keeps clear of every actor already placed, not
# only players (D-091). The NPC is saved first, so it is placed first.
func test_a_stuck_actor_is_moved_clear_of_an_npc_on_the_spawn() -> void:
	var spawn: WorldPos = _world_spawn().tile
	var npc: Actor = _game._create_actor(Actor.create(Global.actor_packed_scene, "Npc",
		spawn, World.get_level_by_depth(spawn.depth), ActorKind.ACTOR.NULL))
	var player: Actor = _player_on_minus_one()
	var id: int = player.actor_id
	var player_name: String = player.actor_name
	var stuck: WorldPos = player.current_WorldPos
	World.get_level_by_depth(1).level_tiles.set_top(
		stuck.x, stuck.y, TileKind.TOP.MINABLE_ROCK)
	var order: Array[Node] = [npc, player]
	_save_actors(order, player)

	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	assert_eq(_warnings_naming([player_name]), 1, "the move is reported")
	var loaded: Actor = _actor_with_id(id)
	var loaded_npc: Actor = _npc_named("Npc")
	assert_not_null(loaded, "the player loads")
	assert_not_null(loaded_npc, "the NPC loads")
	if loaded == null or loaded_npc == null: return
	assert_true(loaded_npc.current_WorldPos.equals(spawn), "the NPC is on the spawn")
	assert_eq(loaded.depth, spawn.depth, "the player is on the spawn's level")
	assert_false(loaded.current_WorldPos.equals(spawn), "but not on the NPC's tile")
	assert_false(loaded.get_world_box().intersects(loaded_npc.get_world_box()),
		"and not in its feet")


# With no spawn to go to, a stuck actor still loads, where it was,
# and the load says so loudly (D-091: no candidate is a loud failure).
func test_a_stuck_actor_with_nowhere_to_go_stays_put_with_an_error() -> void:
	var actor: Actor = _player_on_minus_one()
	var id: int = actor.actor_id
	var stuck: WorldPos = actor.current_WorldPos
	World.get_level_by_depth(1).level_tiles.set_top(
		stuck.x, stuck.y, TileKind.TOP.MINABLE_ROCK)
	var surface: LevelFixtures = World.get_level_by_depth(0).level_fixtures
	surface.remove(_world_spawn().id)
	assert_true(_game.save_game(), "saved, in rock, with no spawn")

	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	assert_push_error("Expected one world spawn, found 0.")
	assert_push_error("with nowhere to go")
	var loaded: Actor = _actor_with_id(id)
	assert_not_null(loaded, "the actor still loads")
	if loaded == null: return
	assert_true(loaded.current_WorldPos.equals(stuck), "on its saved tile")
	assert_eq(_game.active_actor, loaded, "and is still the local player")


# A save holding only an NPC: it loads, nobody is given control, and
# the load says why.
func test_a_save_with_no_player_gives_nobody_control() -> void:
	var spawn: WorldPos = _world_spawn().tile
	var npc: Actor = _game._create_actor(Actor.create(Global.actor_packed_scene, "Npc",
		spawn, World.get_level_by_depth(spawn.depth), ActorKind.ACTOR.NULL))
	var order: Array[Node] = [npc]
	_save_actors(order, null)

	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	assert_push_error("no player to control")
	assert_not_null(_npc_named("Npc"), "the NPC loads")
	assert_eq(_actors().size(), 0, "no players")
	assert_null(_game.active_actor, "no active actor")
	assert_eq(_handler_count(), 0, "no input handler")


func _npc_named(actor_name: String) -> Actor:
	for child in _game.get_node("GameViewport/Actors/NPCs").get_children():
		if child is Actor and child.actor_name == actor_name: return child
	return null


# The game's player and a second one, spawned beside it.
func _two_players() -> Array[Actor]:
	_game._spawn_player("Second")
	var players: Array[Actor] = _actors()
	assert_eq(players.size(), 2, "two players")
	return players


# Saves these actors in this order, naming local (null for none) as
# the local actor. Writes over the game's own save, so the order and
# the local actor are the test's.
func _save_actors(order: Array[Node], local: Actor) -> void:
	assert_true(_game.save_game(), "a slot exists")
	assert_eq(SaveGame.save_game(_game.current_save_slot, _levels(), order, local,
		World.world_seed, _game.tuning_profile_id, 0.0, 0.0, SAVES_ROOT),
		SaveGame.REFUSAL_REASON.NONE, "saved in the chosen order")


# Two players saved, local_actor_id naming the first spawned, in the
# order given.
func _save_two_players(local_first: bool) -> Array[int]:
	var players: Array[Actor] = _two_players()
	var local: Actor = players[0]
	var other: Actor = players[1]
	var order: Array[Node] = [local, other]
	if not local_first: order.reverse()
	_save_actors(order, local)
	return [local.actor_id, other.actor_id]


func _handler_count() -> int:
	return _game.get_children().filter(
		func(child: Node) -> bool: return child is InputHandler).size()


# The local actor gets input, the view, the camera and F3; the other
# gets none of them (D-115, D-094).
func _assert_local_is(local_id: int, other_id: int) -> void:
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	var local: Actor = _actor_with_id(local_id)
	var other: Actor = _actor_with_id(other_id)
	assert_not_null(local, "the local player loads")
	assert_not_null(other, "the other player loads")
	if local == null or other == null: return
	assert_eq(_game.active_actor, local, "the active actor is the one saved as local")
	assert_eq(_handler_count(), 1, "one input handler")
	assert_not_null(_handler_for(local), "input drives the local player")
	assert_null(_handler_for(other), "and not the other")
	assert_eq(_game.view.actor, local, "the view follows the local player")
	assert_eq(_game.get_view_camera().actor, local, "the camera follows the local player")
	var overlay: Node = _game.get_node("DebugOverlay")
	assert_true(overlay.watched_actors.has(local.get_instance_id()), "F3 watches the local player")
	assert_false(overlay.watched_actors.has(other.get_instance_id()), "and not the other")


func test_the_local_player_saved_first_is_the_one_local_actor_id_names() -> void:
	var ids: Array[int] = _save_two_players(true)
	_assert_local_is(ids[0], ids[1])


func test_the_local_player_saved_last_is_the_one_local_actor_id_names() -> void:
	var ids: Array[int] = _save_two_players(false)
	_assert_local_is(ids[0], ids[1])


# D-115's fallback: no local actor saved. The lowest id is local, with
# a warning, and saved second so the order can't be what picks it.
func test_with_no_local_actor_saved_the_lowest_id_player_is_local() -> void:
	var players: Array[Actor] = _two_players()
	var lowest: Actor = players[0]
	var other: Actor = players[1]
	assert_lt(lowest.actor_id, other.actor_id, "spawned first, so the lower id")
	var ids: Array[int] = [lowest.actor_id, other.actor_id]
	var order: Array[Node] = [other, lowest]
	_save_actors(order, null)
	_assert_local_is(ids[0], ids[1])
	assert_push_warning("isn't a loaded player")


# The local actor named in the save didn't load: the same fallback.
func test_a_local_actor_that_did_not_load_falls_back_to_the_lowest_id() -> void:
	var players: Array[Actor] = _two_players()
	var kept: Actor = players[0]
	var missing: Actor = players[1]
	var ids: Array[int] = [kept.actor_id, missing.actor_id]
	var order: Array[Node] = [kept]
	_save_actors(order, missing)
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	assert_null(_actor_with_id(ids[1]), "the missing actor wasn't saved")
	assert_eq(_game.active_actor, _actor_with_id(ids[0]), "the one that loaded is local")
	assert_eq(_handler_count(), 1, "with one input handler")
	assert_push_warning("isn't a loaded player")


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


func test_create_actor_stands_on_the_tile_given() -> void:
	var _pos: WorldPos = WorldPos.new(14, -2, 2)
	var actor: Actor = Actor.create(Global.actor_packed_scene, "TestPlayer", _pos, World.get_level_by_depth(_pos.depth), ActorKind.ACTOR.PLAYER)
	actor = _game._create_actor(actor)
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
	assert_true(actor.move_to(WorldPos.new(here.x, here.y, 1)), "the player moves to -1")
	var renderer: LevelRenderer = _game.get_node("GameViewport/LevelRenderer")
	var top: Texture2D = renderer.material.get_shader_parameter("top_data")
	var expected: int = LevelRenderer.level_width(World.get_level_by_depth(1).level_tiles)
	assert_eq(top.get_width(), expected, "the renderer shows -1, %d tiles wide" % expected)
	assert_eq(_game.view.shown_depth, 1, "and the view says -1")
































