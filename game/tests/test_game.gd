extends GutTest

# game.gd: spawning the levels and the player, and handing the
# player to input, camera, renderer and overlay. Each test runs a
# fresh game.tscn, so _ready has already spawned all eight levels
# and one player by the time the test body runs.

const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/game"

var _game: Node

# Open floor in -1's hand-made home cave.
static func _minus_one_home() -> WorldPos:
	return WorldPos.new(0, 0, 1)


func before_each() -> void:
	_game = load("res://scenes/game.tscn").instantiate()
	_game.saves_root = SAVES_ROOT
	add_child_autofree(_game)


func after_each() -> void:
	SaveDirs.remove_tree(SAVES_ROOT)


func _levels() -> Array[Level]:
	if _game.world == null: return []
	return _game.world.levels()


# The players in the game's world
func _actors() -> Array[Actor]:
	if _game.world == null: return []
	return _game.world.players()


# Input handlers live directly under Game, outside the game viewport,
# so their _input fires without events being pushed in.
# A handler on its way out (queued for deletion) doesn't count.
func _handler_for(actor: Actor) -> InputHandler:
	for child in _game.get_children():
		if child is InputHandler and child.actor == actor and not child.is_queued_for_deletion():
			return child
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
	assert_true(player.current_level in _levels(), "in the game's world")


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
	assert_true(actor.move_to(_minus_one_home()), "the player moves to -1")
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
func _relaunch(new_game: bool = false) -> void:
	_game.free()
	_game = load("res://scenes/game.tscn").instantiate()
	_game.saves_root = SAVES_ROOT
	_game.new_game = new_game
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


# --- pruning at launch (D-134) ---

func _put_in_slot(file: String) -> void:
	var f: FileAccess = FileAccess.open(SAVES_ROOT.path_join("slot-001").path_join(file),
		FileAccess.WRITE)
	f.store_string("kept")
	f.close()


func test_a_launch_that_loads_prunes_each_kind_to_its_count() -> void:
	assert_true(_game.save_game(), "saved")
	for day: int in [1, 2, 3]:
		_put_in_slot("world.broken.202611%02dT120000Z.save" % day)
		_put_in_slot("world.202611%02dT120000Z.save" % day)
	_game.free()
	_game = load("res://scenes/game.tscn").instantiate()
	_game.saves_root = SAVES_ROOT
	var keep: Dictionary[SaveGame.KEPT_KIND, int] = {
		SaveGame.KEPT_KIND.OLD_WORLD: 1, SaveGame.KEPT_KIND.BROKEN: 2}
	_game.keep_per_kind = keep
	add_child_autofree(_game)

	assert_eq(_game.load_source, SaveGame.SOURCE.SAVE, "the save loaded")
	assert_eq(_slot_files("world.broken.").size(), 2, "two broken saves kept")
	assert_eq(_slot_files("world.2026").size(), 1, "one old world kept")
	assert_true(FileAccess.file_exists(_save_file()), "and world.save is still there")


# The refused files are what D-111 keeps: a game that didn't start
# prunes nothing.
func test_a_launch_that_refuses_to_start_prunes_nothing() -> void:
	assert_true(_game.save_game(), "saved once")
	assert_true(_game.save_game(), "and again, so there's a backup")
	_truncate(_save_file())
	_truncate(_backup_file())
	for day: int in [1, 2, 3, 4, 5]:
		_put_in_slot("world.broken.202611%02dT120000Z.save" % day)
	_relaunch()
	assert_push_error("No save could be loaded")
	assert_eq(_game.load_source, SaveGame.SOURCE.REFUSED, "nothing loads")
	assert_eq(_slot_files("world.broken.").size(), 5, "every broken save kept")


# --- a new game, and the autosave timer (D-110, D-111) ---

func _slot_files(prefix: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(SAVES_ROOT.path_join("slot-001")):
		if file.begins_with(prefix): found.append(file)
	return found


func _slot_bytes(file: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SAVES_ROOT.path_join("slot-001").path_join(file))


# A Surface tile the generator leaves as rock, to dig.
func _a_rock_tile() -> Vector2i:
	var tiles: LevelTiles = _game.world.level_at(0).level_tiles
	for x: int in range(-10, 11):
		for y: int in range(-10, 11):
			if tiles.get_top(x, y) == TileKind.TOP.MINABLE_ROCK: return Vector2i(x, y)
	return Vector2i(999, 999)


func test_the_command_line_flag_is_new_game_after_the_double_dash() -> void:
	assert_false(_game.new_game, "the test run has no --new-game")


func test_a_new_game_moves_the_save_and_backup_aside_and_starts_fresh() -> void:
	var tile: Vector2i = _a_rock_tile()
	assert_ne(tile, Vector2i(999, 999), "there's rock to dig")
	_game.world.level_at(0).level_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)
	assert_true(_game.save_game(), "saved once")
	assert_true(_game.save_game(), "and again, so there's a backup")
	var save_bytes: PackedByteArray = _slot_bytes(SaveGame.SAVE_BASE_NAME)
	var backup_bytes: PackedByteArray = _slot_bytes(SaveGame.BACKUP_NAME)
	_relaunch(true)

	assert_eq(_game.load_source, SaveGame.SOURCE.NEW, "a new world")
	assert_eq(_game.world.level_at(0).level_tiles.get_top(tile.x, tile.y),
		TileKind.TOP.MINABLE_ROCK, "fresh: the dig isn't in it")
	assert_not_null(_game.active_actor, "with a player")
	assert_false(FileAccess.file_exists(_save_file()), "world.save is moved aside")
	assert_false(FileAccess.file_exists(_backup_file()), "and so is the backup")
	var old_save: PackedStringArray = _slot_files("world.2")
	var old_backup: PackedStringArray = _slot_files("world.backup.")
	assert_eq(old_save.size(), 1, "the old save is beside it: %s" % [old_save])
	assert_eq(old_backup.size(), 1, "and the old backup: %s" % [old_backup])
	if old_save.size() == 1:
		assert_true(Global.is_regex_match(old_save[0], r"^world\.\d{8}T\d{6}Z\.save$"),
			"named world.<UTC time>.save (D-123)")
		assert_true(_slot_bytes(old_save[0]) == save_bytes, "intact")
	if old_backup.size() == 1:
		assert_true(_slot_bytes(old_backup[0]) == backup_bytes, "intact")


func test_a_new_game_with_no_save_just_starts() -> void:
	_relaunch(true)
	assert_eq(_game.load_source, SaveGame.SOURCE.NEW, "a new world")
	assert_gt(_levels().size(), 0, "generated")


# The way out of a slot whose saves are both refused (D-111).
func test_a_new_game_moves_refused_saves_aside_and_starts() -> void:
	assert_true(_game.save_game(), "saved once")
	assert_true(_game.save_game(), "and again, so there's a backup")
	_truncate(_save_file())
	_truncate(_backup_file())
	_relaunch(true)
	assert_eq(_game.load_source, SaveGame.SOURCE.NEW, "a new world")
	assert_true(_game.save_game(), "and it saves")
	assert_eq(_slot_files("world.2").size(), 1, "the refused save is kept")
	assert_eq(_slot_files("world.backup.").size(), 1, "and so is its backup")


func _autosave() -> Timer:
	return _game.get_node_or_null("AutosaveTimer")


func test_the_autosave_timer_runs_at_its_named_interval_while_playing() -> void:
	var timer: Timer = _autosave()
	assert_not_null(timer, "a new world has an autosave timer")
	if timer == null: return
	assert_eq(timer.wait_time, _game.world.tuning.autosave_interval_seconds,
		"at the profile's interval")
	assert_false(timer.is_stopped(), "running")
	assert_false(timer.one_shot, "and repeating")
	assert_eq(timer.process_mode, Node.PROCESS_MODE_PAUSABLE, "paused with the game")


func test_the_autosave_timer_saves_when_it_fires() -> void:
	assert_false(FileAccess.file_exists(_save_file()), "no save yet")
	_autosave().timeout.emit()
	assert_true(FileAccess.file_exists(_save_file()), "the timer saved")


func test_a_loaded_world_has_an_autosave_timer_too() -> void:
	assert_true(_game.save_game(), "saved")
	_relaunch()
	assert_eq(_game.load_source, SaveGame.SOURCE.SAVE, "loaded")
	assert_not_null(_autosave(), "the timer runs")


func test_a_game_that_did_not_start_has_no_autosave_timer() -> void:
	assert_true(_game.save_game(), "saved once")
	assert_true(_game.save_game(), "and again, so there's a backup")
	_truncate(_save_file())
	_truncate(_backup_file())
	_relaunch()
	assert_push_error("No save could be loaded")
	assert_null(_autosave(), "nothing to save")


func test_f3_shows_how_long_the_last_save_and_load_took() -> void:
	assert_true(_game.save_game(), "saved")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded")
	var overlay: Node = _game.get_node("DebugOverlay")
	assert_gte(_game.last_save_msec, 0.0, "the save was timed")
	assert_gte(_game.last_load_msec, 0.0, "and the load")
	assert_string_ends_with(overlay.debug_text[overlay.SAVE_TIME_SECTION].text, " ms")
	assert_string_ends_with(overlay.debug_text[overlay.LOAD_TIME_SECTION].text, " ms")


# --- loading actors (D-091, D-114, D-115) ---

func _actor_with_id(id: int) -> Actor:
	for actor: Actor in _actors():
		if actor.actor_id == id: return actor
	return null


# The player, moved onto -1's home cave: open, and off the spawn,
# which is now out on the Surface's road (D-180).
func _player_on_minus_one() -> Actor:
	var actor: Actor = _game.active_actor
	var here: WorldPos = actor.current_WorldPos
	assert_true(actor.move_to(_minus_one_home()), "the player moves to -1")
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
	_game.world.level_at(1).level_tiles.set_top(
		stuck.x, stuck.y, TileKind.TOP.MINABLE_ROCK)
	assert_true(_game.save_game(), "saved, standing in rock")
	var spawn: WorldPos = _world_spawn().tile

	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	var loaded: Actor = _actor_with_id(id)
	assert_not_null(loaded, "the actor still loads")
	if loaded == null: return
	assert_true(loaded.current_WorldPos.equals(spawn),
		"at the world spawn %s, got %s" % [spawn, loaded.current_WorldPos])
	assert_eq(loaded.current_level, _game.world.level_at(spawn.depth),
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
	_game.world.level_at(1).level_tiles.set_top(
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
		spawn, _game.world.level_at(spawn.depth), ActorKind.ACTOR.NULL))
	var player: Actor = _player_on_minus_one()
	var id: int = player.actor_id
	var player_name: String = player.actor_name
	var stuck: WorldPos = player.current_WorldPos
	_game.world.level_at(1).level_tiles.set_top(
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
	_game.world.level_at(1).level_tiles.set_top(
		stuck.x, stuck.y, TileKind.TOP.MINABLE_ROCK)
	var surface: LevelFixtures = _game.world.level_at(0).level_fixtures
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
		spawn, _game.world.level_at(spawn.depth), ActorKind.ACTOR.NULL))
	var order: Array[Node] = [npc]
	_save_actors(order, null)

	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	assert_push_error("no player to control")
	assert_not_null(_npc_named("Npc"), "the NPC loads")
	assert_eq(_actors().size(), 0, "no players")
	assert_null(_game.active_actor, "no active actor")
	assert_eq(_handler_count(), 0, "no input handler")


# D-132: with nobody to follow, the loaded world is still what's on
# screen, at its spawn's depth, and nothing draws the freed one.
func test_a_save_with_no_player_is_still_shown() -> void:
	var spawn: WorldPos = _world_spawn().tile
	var npc: Actor = _game._create_actor(Actor.create(Global.actor_packed_scene, "Npc",
		spawn, _game.world.level_at(spawn.depth), ActorKind.ACTOR.NULL))
	var order: Array[Node] = [npc]
	_save_actors(order, null)

	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "the load succeeds")
	assert_push_error("no player to control")
	var view: View = _game.view
	assert_eq(view.shown_world, _game.world, "the loaded world is shown")
	assert_eq(view.shown_depth, spawn.depth, "at its spawn's depth")
	assert_null(view.actor, "following nobody")

	var level: Level = _game.world.level_at(spawn.depth)
	var tiles: LevelRenderer = _game.get_node("GameViewport/LevelRenderer")
	tiles.upload_changed_layers()
	level.level_tiles.set_top(1, 1, TileKind.TOP.MINABLE_DIRT)
	assert_true(tiles._dirty_layers.has("top"), "the level renderer hears the new world")
	var fixtures: FixtureRenderer = _game.get_node("GameViewport/FixtureRenderer")
	level.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.LADDER, spawn, 9003))
	assert_not_null(fixtures.sprite_for(9003), "and so does the fixture renderer")
	assert_eq(_game.get_node("DebugOverlay").world, _game.world, "F3 reads it")


func _npc_named(actor_name: String) -> Actor:
	for actor: Actor in _game.world.actors():
		if actor.actor_kind != ActorKind.ACTOR.PLAYER and actor.actor_name == actor_name:
			return actor
	return null


# The game's player and a second one, spawned beside it.
func _two_players() -> Array[Actor]:
	_game._spawn_player("Second")
	var players: Array[Actor] = _actors()
	assert_eq(players.size(), 2, "two players")
	return players


# Saves only these actors, in this order, naming local (null for none)
# as the local actor. The world's other actors are freed first, and
# these are put in this order under their parents, since the save
# writes the world's own actors. Writes over the game's own save, so
# the order and the local actor are the test's.
func _save_actors(order: Array[Node], local: Actor) -> void:
	assert_true(_game.save_game(), "a slot exists")
	var local_id: int = local.actor_id if local else -1
	var world: World = _game.world
	for actor: Actor in world.actors():
		if actor not in order: actor.free()
	for actor: Node in order:
		actor.get_parent().move_child(actor, -1)
	var session: SaveSession = SaveSession.new(local_id)
	assert_eq(SaveGame.save_game(_game.current_save_slot, world, session, SAVES_ROOT),
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
		func(child: Node) -> bool:
			return child is InputHandler and not child.is_queued_for_deletion()).size()


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

# A new game generates only the profile's starting depths (D-143),
# each once; the rest wait for an arrival.
func test_ready_spawns_each_starting_depth_once() -> void:
	var starting: Array[int] = _game.world.tuning.levels_to_generate_on_new_game
	for depth in range(LevelRecipes.TABLE.rows.size()):
		var count: int = _levels().filter(
			func(level: Level) -> bool: return level.depth == depth).size()
		var expected: int = 1 if depth in starting else 0
		assert_eq(count, expected, "%d level(s) at depth %d" % [expected, depth])


# Inside the game viewport, at the origin, so a level's and an
# actor's transforms stay the identity (D-128, trap 5).
func test_the_world_sits_at_the_origin_inside_the_game_viewport() -> void:
	var world: World = _game.world
	assert_eq(world.get_parent(), _game.get_node("GameViewport"), "in the game viewport")
	assert_eq(world.position, Vector2.ZERO, "at the origin")
	assert_eq(_actors()[0].get_parent().get_parent().get_parent(), world,
		"and the player is the world's own")


func test_get_level_finds_every_generated_depth() -> void:
	for depth: int in _game.world.tuning.levels_to_generate_on_new_game:
		var level: Level = _game.world.level_at(depth)
		assert_not_null(level, "depth %d is resident" % depth)
		if level: assert_eq(level.depth, depth, "and is the right one")


func test_get_level_returns_null_for_a_missing_depth() -> void:
	assert_null(_game.world.level_at(99), "no level exists at depth 99")


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
	var tiles: LevelTiles = _game.world.level_at(actor.depth).level_tiles
	var pos: WorldPos = actor.current_WorldPos
	assert_eq(tiles.get_top(pos.x, pos.y), TileKind.TOP.OPEN,
		"the spawn tile is open floor, not inside rock")


func _world_spawn() -> Fixture:
	return _game.world.level_at(0).level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN)[0]


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
	var fixtures: LevelFixtures = _game.world.level_at(0).level_fixtures
	fixtures.remove(_world_spawn().id)
	var before: int = _actors().size()
	_game._spawn_player("TestPlayer")
	assert_push_error("Expected one world spawn, found 0.")
	assert_push_error("Nowhere to spawn TestPlayer.")
	assert_eq(_actors().size(), before, "no actor is created")


func test_create_actor_stands_on_the_tile_given() -> void:
	var _pos: WorldPos = WorldPos.new(14, -2, 1)
	var actor: Actor = Actor.create(Global.actor_packed_scene, "TestPlayer", _pos, _game.world.level_at(_pos.depth), ActorKind.ACTOR.PLAYER)
	actor = _game._create_actor(actor)
	assert_true(actor in _actors(), "the actor is added under Players")
	assert_true(actor.current_WorldPos.equals(_pos),
		"on that tile, at that depth")


# --- user control ---

# Generates the depth first if a new game hasn't yet (D-143).
func _actor_at_depth(depth: int) -> Actor:
	if _game.world.level_at(depth) == null:
		LevelGenerator.generate_into(_game.world, depth)
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(0, 0, depth), _game.world.level_at(depth), ActorKind.ACTOR.PLAYER)
	_game.world.add_actor(actor)
	return actor


func test_user_control_gives_the_actor_an_input_handler() -> void:
	var actor: Actor = _actor_at_depth(0)
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
	assert_true(handler.is_queued_for_deletion(), "the renamed handler is on its way to being freed")
	assert_null(handler.actor, "cut off from its actor until then")
	assert_false(handler.is_processing_input(), "and from input")
	assert_false(handler.is_physics_processing(), "and drives nothing")
	assert_eq(handler.get_parent(), _game, "but left in the tree, so it's never an orphan")
	assert_true(is_instance_valid(lookalike), "the lookalike is left alone")
	assert_eq(_game._input_handlers.size(), 0, "and the list is emptied")
	await get_tree().process_frame
	assert_false(is_instance_valid(handler), "freed by the end of the frame")


# The debug load key reaches the load from inside the handler's own
# _input: the world is built then, and swapped in at the end of the
# frame, when no handler or actor code is running (R-B8, D-129, trap
# 4).
func test_the_load_key_swaps_the_world_in_at_the_end_of_the_frame() -> void:
	assert_true(_game.save_game(), "saved")
	var old_world: World = _game.world
	var old_player: Actor = _game.active_actor
	var handler: InputHandler = _handler_for(old_player)
	var press: InputEventAction = InputEventAction.new()
	press.action = "load"
	press.pressed = true
	handler._input(press)
	assert_eq(_game.world, old_world, "nothing is swapped during the key's own call")
	assert_true(is_instance_valid(old_player), "and nothing freed")
	assert_eq(_handler_for(old_player), handler, "its handler still drives it")
	await get_tree().process_frame
	assert_ne(_game.world, old_world, "the loaded world is in by the end of the frame")
	assert_false(is_instance_valid(old_world), "and the old one freed")
	assert_eq(_handler_count(), 1, "one handler, for the loaded player")
	assert_ne(_handler_for(_game.active_actor), handler, "a new one")
	await get_tree().process_frame
	assert_false(is_instance_valid(handler), "the old one is freed")


func test_the_quick_save_key_saves_through_the_handler() -> void:
	var handler: InputHandler = _handler_for(_game.active_actor)
	var press: InputEventAction = InputEventAction.new()
	press.action = "quick_save"
	press.pressed = true
	assert_false(FileAccess.file_exists(_save_file()), "no save yet")
	handler._input(press)
	assert_true(FileAccess.file_exists(_save_file()), "the game heard the request and saved")


# A loaded world draws no fixture ids, so the counter is moved past
# every id it brought back: a fixture placed after a fresh launch's
# load can't take one already in the world (R-P2).
func test_after_a_load_new_fixture_ids_are_past_every_loaded_one() -> void:
	assert_true(_game.save_game(), "saved")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded")
	var next: int = _game.world.fixture_ids.peek()
	assert_gt(next, SaveGame.highest_fixture_id(_levels()), "the next id is a new one")


# Every level in the save fails its checks: the save is refused before
# anything is freed, and the running world carries on (R-B3, R-S2).
func test_a_load_where_every_level_fails_leaves_the_running_world() -> void:
	assert_true(_game.save_game(), "saved once, so there's no backup to fall back to")
	var data: Dictionary = SaveGame.get_save_data(SAVES_ROOT.path_join("slot-001"))
	for depth: Variant in data.levels:
		data.levels[depth]["level_seed"] = "not a seed"
	SaveGame._overwrite_data(SaveGame.FORMAT_VERSION, data, _save_file())
	var levels: Array[Level] = _levels()
	var actor: Actor = _game.active_actor

	assert_eq(_game.load_game(), _game.REFUSAL_REASON.LOAD_REFUSED, "the load is refused")
	assert_push_error("No save could be loaded")
	assert_eq(_levels(), levels, "the same levels, still in the tree")
	assert_true(is_instance_valid(actor), "the player wasn't freed")
	assert_eq(_game.active_actor, actor, "and is still in control")
	assert_true(_game.save_game(), "and the game still saves")


# A load onto the depth already shown: the fixtures are drawn from the
# loaded level, not the one it replaced (R-B9).
func test_a_load_onto_the_shown_depth_redraws_its_fixtures() -> void:
	var depth: int = _game.view.shown_depth
	assert_true(_game.save_game(), "saved")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded")
	assert_eq(_game.view.shown_depth, depth, "onto the same depth")
	var renderer: FixtureRenderer = _game.get_node("GameViewport/FixtureRenderer")
	var level: Level = _game.world.level_at(depth)
	assert_eq(renderer._fixtures, level.level_fixtures, "drawing the loaded level's fixtures")
	assert_eq(renderer._shown_tiles, level.level_tiles, "and its tiles for the ladder tops")
	var below: Level = _game.world.level_at(depth + 1)
	if below != null:
		assert_eq(renderer._below, below.level_fixtures, "and the loaded level below's ladders")


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
	var expected: int = LevelRenderer.level_width(_game.world.level_at(3).level_tiles)
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


# --- the level-change fade (D-142) ---

func _player_down_a_level() -> Actor:
	var actor: Actor = _game.active_actor
	var here: WorldPos = actor.current_WorldPos
	assert_true(actor.move_to(_minus_one_home()), "the player moves to -1")
	return actor


func _fade_seconds() -> float:
	return _game.world.tuning.level_change_fade_seconds


func test_a_level_change_fades_and_switches_at_the_midpoint() -> void:
	var view: View = _game.view
	var actor: Actor = _player_down_a_level()
	assert_eq(actor.depth, 1, "the move itself is instant")
	assert_true(view.is_transitioning(), "the fade starts")
	assert_eq(view.shown_depth, 0, "still showing the Surface")
	assert_true(actor.visible, "and the player is still drawn")
	view.advance_transition(_fade_seconds() * 0.25)
	assert_almost_eq(view.fade, 0.5, 0.01, "halfway to black")
	var overlay: ColorRect = _game.get_node("Display/Fade")
	assert_almost_eq(overlay.color.a, 0.5, 0.01, "and the screen shows it")
	view.advance_transition(_fade_seconds() * 0.3)
	assert_eq(view.shown_depth, 1, "past the midpoint, -1 is shown")
	view.advance_transition(_fade_seconds())
	assert_false(view.is_transitioning(), "the fade is over")
	assert_eq(overlay.color.a, 0.0, "and the screen is clear")


func test_input_is_paused_during_the_fade_and_resumes_after() -> void:
	var actor: Actor = _game.active_actor
	var handler: InputHandler = _handler_for(actor)
	actor.move(Vector2.RIGHT)
	actor.primary_action(true)
	_player_down_a_level()
	assert_true(handler.paused, "input waits")
	assert_eq(actor.move_intent, Vector2.ZERO, "the player stops walking")
	assert_false(actor.action_intent, "and digging")
	_game.view.finish_transition()
	assert_false(handler.paused, "input is read again once it ends")


func test_the_fade_length_is_the_profiles() -> void:
	assert_eq(_fade_seconds(), 0.5, "0.5 s in the default profile")


# A load mid-fade shows the loaded world at once (D-142, D-132).
func test_a_load_mid_fade_ends_the_fade() -> void:
	assert_true(_game.save_game(), "saved")
	_player_down_a_level()
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded")
	assert_false(_game.view.is_transitioning(), "no fade left running")
	assert_eq(_game.view.fade, 0.0, "the screen is clear")
	assert_false(_handler_for(_game.active_actor).paused, "and the new player's input runs")


# The screen follows the player down (D-094). The Surface spawn sits
# over -1's home cave, so the landing is open.
func test_the_screen_follows_the_player_down_a_level() -> void:
	var actor: Actor = _actors()[0]
	var here: WorldPos = actor.current_WorldPos
	assert_true(actor.move_to(_minus_one_home()), "the player moves to -1")
	# The screen switches halfway through the fade (D-142)
	_game.view.finish_transition()
	var renderer: LevelRenderer = _game.get_node("GameViewport/LevelRenderer")
	var top: Texture2D = renderer.material.get_shader_parameter("top_data")
	var expected: int = LevelRenderer.level_width(_game.world.level_at(1).level_tiles)
	assert_eq(top.get_width(), expected, "the renderer shows -1, %d tiles wide" % expected)
	assert_eq(_game.view.shown_depth, 1, "and the view says -1")


































# F3 reads the counters of the world being played (slice 004 outcome
# 3).
func test_f3_shows_the_running_worlds_next_ids() -> void:
	var world: World = _game.world
	assert_eq(_game.get_node("DebugOverlay").next_ids_text(),
		"fixture #%d  actor #%d" % [world.fixture_ids.peek(), world.actor_ids.peek()])
	assert_eq(world.actor_ids.peek(), IdAllocator.FIRST_ID + 1, "the one player took actor id 1")


# Trap 6: after a load, a new player takes an id no loaded actor has,
# and the loaded world's counters carry on past every loaded id.
func test_a_player_created_after_a_load_gets_a_new_id() -> void:
	_game._spawn_player("Second")
	assert_true(_game.save_game(), "saved with two players")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded")
	var loaded_ids: Array[int] = []
	for actor: Actor in _game.world.actors():
		loaded_ids.append(actor.actor_id)
	assert_gt(_game.world.actor_ids.peek(), loaded_ids.max(), "the counter is past every loaded id")
	_game._spawn_player("Third")
	var third: Actor = _actors()[-1]
	assert_eq(third.actor_name, "Third", "the new player")
	assert_false(third.actor_id in loaded_ids, "with an id no loaded actor has")


# The load hands back a whole world; the game uses it as it came.
func test_a_load_puts_the_saved_world_in() -> void:
	var seed_before: int = _game.world.world_seed
	var old_world: World = _game.world
	assert_true(_game.save_game(), "saved")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded")
	assert_ne(_game.world, old_world, "a different world node")
	assert_eq(_game.world.world_seed, seed_before, "with the saved seed")
	assert_eq(_game.active_actor.current_level.world, _game.world,
		"and the player in it")


# --- the swap (slice 004 section E) ---

func _press_load() -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = "load"
	press.pressed = true
	_handler_for(_game.active_actor)._input(press)


# Trap 3: anything listening to the old world goes silent when it's
# freed, with no error. After a load, each thing that draws hears a
# change in the new world, and nothing from the old one.
func test_after_a_load_everything_that_draws_follows_the_new_world_only() -> void:
	assert_true(_game.save_game(), "saved")
	var depth: int = _game.view.shown_depth
	var old_level: Level = _game.world.level_at(depth)
	# Kept past the old level's free: they're RefCounted
	var old_tiles: LevelTiles = old_level.level_tiles
	var old_fixtures: LevelFixtures = old_level.level_fixtures
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded")
	var level: Level = _game.world.level_at(depth)

	var tiles: LevelRenderer = _game.get_node("GameViewport/LevelRenderer")
	tiles.upload_changed_layers()
	old_tiles.set_top(1, 1, TileKind.TOP.MINABLE_DIRT)
	assert_true(tiles._dirty_layers.is_empty(), "the level renderer doesn't hear the old world")
	level.level_tiles.set_top(1, 1, TileKind.TOP.MINABLE_DIRT)
	assert_true(tiles._dirty_layers.has("top"), "it hears the new one")

	var fixtures: FixtureRenderer = _game.get_node("GameViewport/FixtureRenderer")
	var spot: WorldPos = _game.active_actor.current_WorldPos
	old_fixtures.add(Fixture.new(ObjectKind.OBJECT.LADDER, spot, 9001))
	assert_null(fixtures.sprite_for(9001), "the fixture renderer doesn't hear the old world")
	level.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.LADDER, spot, 9002))
	assert_not_null(fixtures.sprite_for(9002), "it hears the new one")

	var overlay: Node = _game.get_node("DebugOverlay")
	assert_eq(overlay.world, _game.world, "F3 reads the new world")
	_game.world.fixture_ids.allocate()
	assert_eq(overlay.next_ids_text(), "fixture #%d  actor #%d" % [
		_game.world.fixture_ids.peek(), _game.world.actor_ids.peek()], "and its counters")

	var dig: CapabilityDig = _game.active_actor.get_node("Capabilities/CapabilityDig")
	assert_true(_game.world.tile_dug.is_connected(dig._on_tile_dug),
		"the loaded player's dig hears the new world's gatekeeper")


# Outcome 2: F6 on a save cut short (and no backup) changes nothing:
# not the world, not the screen, not F3, not the ids.
func test_f6_on_a_truncated_save_changes_nothing() -> void:
	assert_true(_game.save_game(), "saved once, so there's no backup")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_save_file())
	var file: FileAccess = FileAccess.open(_save_file(), FileAccess.WRITE)
	file.store_buffer(bytes.slice(0, bytes.size() / 2))
	file.close()

	var world: World = _game.world
	var player: Actor = _game.active_actor
	var depth: int = _game.view.shown_depth
	var overlay: Node = _game.get_node("DebugOverlay")
	var ids: String = overlay.next_ids_text()
	var tiles: LevelRenderer = _game.get_node("GameViewport/LevelRenderer")
	var shown: LevelTiles = tiles._tiles

	_press_load()
	await get_tree().process_frame
	assert_push_error("No save could be loaded")
	assert_eq(_game.world, world, "the same world")
	assert_true(is_instance_valid(player), "the player wasn't freed")
	assert_eq(_game.active_actor, player, "and is still in control")
	assert_eq(_handler_count(), 1, "with its one handler")
	assert_eq(_game.view.shown_depth, depth, "the same depth on screen")
	assert_eq(tiles._tiles, shown, "drawing the same level")
	assert_eq(overlay.world, world, "F3 reads the same world")
	assert_eq(overlay.next_ids_text(), ids, "and the same ids")
	assert_string_contains(_game.notice_text(), "unchanged", "the notice says the world carries on")


# Outcome 3: loading twice in a row shows the same next ids both
# times: they don't restart, and they don't climb.
func test_loading_twice_shows_the_same_next_ids() -> void:
	_game._spawn_player("Second")
	assert_true(_game.save_game(), "saved")
	var overlay: Node = _game.get_node("DebugOverlay")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded once")
	var first: String = overlay.next_ids_text()
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "and again")
	assert_eq(overlay.next_ids_text(), first, "the same next ids")
	assert_ne(first, "fixture #1  actor #1", "and not restarted")


func test_a_new_game_comes_in_through_the_swap() -> void:
	var world: World = _game.world
	_game._swap_world(LevelGenerator.generate_world(1))
	assert_false(is_instance_valid(world), "the old world is freed")
	assert_eq(_game.world.world_seed, 1, "the new one is in")
	assert_eq(_game.world.get_parent(), _game.get_node("GameViewport"), "in the game viewport")
	assert_eq(_handler_count(), 0, "with no input until a player is given control")
