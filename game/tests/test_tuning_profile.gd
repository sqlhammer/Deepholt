extends GutTest

# The tuning profile (D-037, D-135): every tuning number in one
# resource the world holds, found by id under TuningProfile.DIR. A
# load runs the world under the profile its save names, or the
# default with a warning (D-136).

const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/tuning"


func after_each() -> void:
	SaveDirs.remove_tree(SAVES_ROOT)


func _default() -> TuningProfile:
	return TuningProfile.default_profile()


# A profile with other numbers, built in code so no test file needs a
# second .tres in content/.
func _other(profile_id: String = "other") -> TuningProfile:
	var profile: TuningProfile = _default().duplicate()
	profile.id = profile_id
	profile.walk_speed = 40.0
	profile.autosave_interval_seconds = 60.0
	return profile


# --- the default profile ---

func test_the_default_profile_is_found_by_its_id() -> void:
	var profile: TuningProfile = _default()
	assert_not_null(profile, "content/tuning/default.tres loads")
	if profile == null: return
	assert_eq(profile.id, TuningProfile.DEFAULT_ID, "its id matches its file")


# The numbers the code held before the profile existed (D-110, D-081,
# tuning appendix §4), now in one place.
func test_the_default_holds_the_numbers_the_code_had() -> void:
	var profile: TuningProfile = _default()
	assert_eq(profile.autosave_interval_seconds, 300.0, "autosave every 5 minutes")
	assert_eq(profile.walk_speed, 85.0, "walk speed")
	assert_eq(profile.hardness_of(TileKind.TOP.MINABLE_ROCK), 6.0, "rock is 6")
	assert_eq(profile.hardness_of(TileKind.TOP.MINABLE_DIRT), 4.0, "dirt is 4")
	assert_eq(profile.ore_dig_multiplier, 1.5, "ore takes 1.5x")


# TileKind says what can be dug; every profile must say how hard. A
# hardness of zero or less would finish a dig on its first tick, or
# be read as "not diggable".
func test_every_diggable_kind_has_a_positive_hardness() -> void:
	for kind: int in TileKind.DIGGABLE:
		assert_true(_default().hardness.has(kind), "kind %d has a hardness" % kind)
		assert_gt(_default().hardness_of(kind), 0.0, "kind %d takes time to dig" % kind)


func test_every_hardness_entry_is_a_diggable_kind() -> void:
	for kind: int in _default().hardness:
		assert_true(TileKind.is_diggable(kind), "kind %d can be dug" % kind)


func test_an_undiggable_kind_has_no_hardness() -> void:
	assert_lt(_default().hardness_of(TileKind.TOP.OPEN), 0.0, "open floor")
	assert_lt(_default().dig_hardness(TileKind.TOP.OPEN, TileKind.ORE.COPPER), 0.0,
		"and ore doesn't make it diggable")


# A diggable kind the profile forgot is loud, and reads as undiggable
# rather than as instant.
func test_a_profile_missing_a_kinds_hardness_is_an_error() -> void:
	var profile: TuningProfile = _other()
	profile.hardness = {}
	assert_lt(profile.hardness_of(TileKind.TOP.MINABLE_ROCK), 0.0, "no hardness")
	assert_push_error("has no hardness")


func test_ore_multiplies_the_hardness() -> void:
	var rock: float = _default().hardness_of(TileKind.TOP.MINABLE_ROCK)
	assert_eq(_default().dig_hardness(TileKind.TOP.MINABLE_ROCK, TileKind.ORE.NONE), rock,
		"plain rock")
	assert_eq(_default().dig_hardness(TileKind.TOP.MINABLE_ROCK, TileKind.ORE.COPPER),
		rock * _default().ore_dig_multiplier, "rock with copper")


# --- finding a profile ---

func test_a_profile_this_build_lacks_is_null() -> void:
	assert_null(TuningProfile.find("no-such-profile"), "not in content/tuning")
	assert_null(TuningProfile.find(""), "no id")
	assert_null(TuningProfile.find("../default"), "not a file name")


func test_a_missing_profile_falls_back_to_the_default_with_a_warning() -> void:
	var profile: TuningProfile = TuningProfile.find_or_default("none", "The save")
	assert_eq(profile.id, TuningProfile.DEFAULT_ID, "the default")


# --- the world holds it (D-135) ---

func test_a_world_runs_under_the_default_unless_given_one() -> void:
	var world: World = autofree(World.new())
	assert_eq(world.tuning.id, TuningProfile.DEFAULT_ID, "the default")
	var other: World = autofree(World.new(_other()))
	assert_eq(other.tuning.id, "other", "the one it was given")


func test_two_worlds_can_run_under_different_profiles() -> void:
	var first: World = autofree(LevelGenerator.generate_world(1))
	var second: World = autofree(LevelGenerator.generate_world(1, _other()))
	assert_eq(first.tuning.walk_speed, 85.0, "the first walks at the default")
	assert_eq(second.tuning.walk_speed, 40.0, "the second at its own")


func test_an_actor_walks_at_its_worlds_speed() -> void:
	var world: World = add_child_autofree(LevelGenerator.generate_world(1, _other()))
	var spawn: WorldPos = Spawning.world_spawn(world.levels()).tile
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Walker", spawn,
		world.level_at(spawn.depth), ActorKind.ACTOR.PLAYER)
	world.add_actor(actor)
	assert_eq(actor.speed, 40.0, "the profile's walk speed")


# --- saving and loading (D-136) ---

func _saved_world(tuning: TuningProfile) -> String:
	var slot: String = SAVES_ROOT.path_join("slot-001")
	DirAccess.make_dir_recursive_absolute(slot)
	var world: World = autofree(LevelGenerator.generate_world(7, tuning))
	var spawn: WorldPos = Spawning.world_spawn(world.levels()).tile
	world.add_actor(Actor.create(Global.actor_packed_scene, "Saver", spawn,
		world.level_at(spawn.depth), ActorKind.ACTOR.PLAYER))
	assert_eq(SaveGame.save_game(slot, world, SaveSession.new(), SAVES_ROOT),
		SaveGame.REFUSAL_REASON.NONE, "saved")
	return slot


func test_a_save_records_the_worlds_profile() -> void:
	var slot: String = _saved_world(_default())
	var data: Dictionary = SaveGame.get_save_data(slot)
	assert_eq(data.get("tuning_profile_id"), TuningProfile.DEFAULT_ID, "the world's profile id")


func test_a_load_runs_the_world_under_the_profile_its_save_names() -> void:
	var slot: String = _saved_world(_default())
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(slot)
	if loaded == null:
		fail_test("the load was refused")
		return
	assert_eq(loaded.header.tuning_profile_id, TuningProfile.DEFAULT_ID, "the save names it")
	assert_eq(loaded.world.tuning.id, TuningProfile.DEFAULT_ID, "and the world runs under it")
	loaded.free_world()


# A save naming a profile this build lacks still loads (D-136).
func test_a_save_naming_a_missing_profile_loads_under_the_default() -> void:
	var slot: String = _saved_world(_other("retired-playtest"))
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(slot)
	if loaded == null:
		fail_test("the load was refused")
		return
	assert_eq(loaded.header.tuning_profile_id, "retired-playtest", "what the save named")
	assert_eq(loaded.world.tuning.id, TuningProfile.DEFAULT_ID, "the world runs under the default")
	loaded.free_world()


# --- the game (D-135, D-136) ---

func _game(tuning_id: String = "") -> Node:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.saves_root = SAVES_ROOT
	game.tuning_id = tuning_id
	add_child_autofree(game)
	return game


func test_the_autosave_interval_is_the_worlds() -> void:
	var game: Node = _game()
	var timer: Timer = game.get_node("AutosaveTimer")
	assert_eq(timer.wait_time, game.world.tuning.autosave_interval_seconds, "from the profile")


func test_an_unknown_tuning_flag_starts_the_default() -> void:
	var game: Node = _game("no-such-profile")
	assert_eq(game.world.tuning.id, TuningProfile.DEFAULT_ID, "the default")


func test_f3_shows_the_profile_in_use() -> void:
	var game: Node = _game()
	var overlay: Node = game.get_node("DebugOverlay")
	assert_eq(overlay.debug_text[overlay.TUNING_SECTION].text, TuningProfile.DEFAULT_ID)
