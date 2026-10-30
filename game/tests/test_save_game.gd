extends GutTest

# SaveGame: live levels to plain save data and back (D-109), the file
# it writes, the slot folders it finds, and what a refused load leaves
# behind. The data holds plain types only, so it can be read back with
# allow_objects off (slice 003 trap 3). Tile layers are saved by name,
# each compressed with ZSTD, with each level's bound and seed (D-109,
# D-112, D-116).

const SaveDirs = preload("res://tests/save_dirs.gd")

# The tests' own saves root, outside the real saves folder.
const TEST_ROOT: String = SaveDirs.TEST_ROOT + "/save_game"
const TEST_SLOT: String = TEST_ROOT + "/slot-001"
const TEST_SEED: int = 123456789


func before_each() -> void:
	SaveDirs.remove_tree(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(TEST_SLOT)


func after_each() -> void:
	SaveDirs.remove_tree(TEST_ROOT)


func _level(depth: int) -> Level:
	var level: Level = Level.new()
	level.setup(depth)
	return autofree(level)


func _radius(depth: int) -> int:
	return World.level_recipes.get_bounds(depth).radius


func _size(depth: int) -> int:
	var width: int = 2 * _radius(depth) + 1
	return width * width


func _filled(size: int, kind: int) -> PackedByteArray:
	var bytes: PackedByteArray = []
	bytes.resize(size)
	bytes.fill(kind)
	return bytes


func _packed(bytes: PackedByteArray) -> PackedByteArray:
	return bytes.compress(SaveGame.COMPRESSION_MODE)


func _unpacked(packed: PackedByteArray, depth: int) -> PackedByteArray:
	return packed.decompress(_size(depth), SaveGame.COMPRESSION_MODE)


# One saved level as the file holds it: layers compressed. The raw
# layers are dirt ground, open top and copper ore throughout.
func _level_data(depth: int) -> Dictionary:
	return {
		"level_seed": TEST_SEED,
		"bound": {"depth": depth, "radius": _radius(depth)},
		"tiles": {
			"ground": _packed(_filled(_size(depth), TileKind.GROUND.DIRT)),
			"top": _packed(_filled(_size(depth), TileKind.TOP.OPEN)),
			"ore": _packed(_filled(_size(depth), TileKind.ORE.COPPER)),
		},
	}


func _serialize(levels: Array[Level]) -> Dictionary:
	return SaveGame._serialize_levels(levels)


# Saved levels to live ones, by depth. Every level built is freed
# after the test.
func _deserialize(levels_data: Dictionary) -> Dictionary:
	var levels: Dictionary = SaveGame._deserialize_levels(levels_data)
	for depth: Variant in levels:
		autofree(levels[depth])
	return levels


func _sorted_keys(dict: Dictionary) -> Array:
	var keys: Array = dict.keys()
	keys.sort()
	return keys


# Walks a value and returns the path of the first Object in it, or "".
func _object_in(value: Variant, path: String) -> String:
	if value is Object:
		return path
	if value is Dictionary:
		for key: Variant in value:
			if key is Object:
				return "%s key %s" % [path, key]
			var found: String = _object_in(value[key], "%s.%s" % [path, key])
			if found != "":
				return found
	if value is Array:
		for i in value.size():
			var found: String = _object_in(value[i], "%s[%d]" % [path, i])
			if found != "":
				return found
	return ""


func _orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


# --- serialize ---

func test_serialize_keys_levels_by_their_int_depth() -> void:
	var levels: Dictionary = _serialize([_level(0), _level(1), _level(2)])
	assert_eq(_sorted_keys(levels), [0, 1, 2], "one entry per level, keyed by depth")
	for key: Variant in levels:
		assert_eq(typeof(key), TYPE_INT, "depth keys stay ints")


func test_serialize_keys_each_level_by_its_bounds_depth() -> void:
	var levels: Dictionary = _serialize([_level(0), _level(1)])
	for key: Variant in levels:
		assert_eq(levels[key]["bound"]["depth"], key, "depth %d agrees" % key)


func test_serialize_saves_the_bound_as_plain_ints() -> void:
	var bound: Variant = _serialize([_level(1)])[1]["bound"]
	assert_true(bound is Dictionary, "the bound is data, not the LevelBound resource")
	assert_eq(bound["depth"], 1, "depth saved")
	assert_eq(bound["radius"], _radius(1), "radius saved")


func test_serialize_saves_every_layer_by_name() -> void:
	var level: Level = _level(0)
	level.level_tiles.set_top(1, 1, TileKind.TOP.OPEN)
	level.level_tiles.set_ore(2, 0, TileKind.ORE.COPPER)
	level.level_tiles.set_ground(0, 3, TileKind.GROUND.DIRT)
	var tiles: Dictionary = _serialize([level])[0]["tiles"]
	assert_eq(_unpacked(tiles["ground"], 0), level.level_tiles.ground,
		"ground saved byte for byte")
	assert_eq(_unpacked(tiles["top"], 0), level.level_tiles.top, "top saved byte for byte")
	assert_eq(_unpacked(tiles["ore"], 0), level.level_tiles.ore, "ore saved byte for byte")


func test_serialize_compresses_every_layer() -> void:
	var tiles: Dictionary = _serialize([_level(0)])[0]["tiles"]
	for layer: String in ["ground", "top", "ore"]:
		assert_lt(tiles[layer].size(), _size(0), "%s is smaller than raw" % layer)


func test_serialize_saves_the_level_seed_as_a_number() -> void:
	var level: Level = _level(1)
	var levels: Dictionary = _serialize([level])
	assert_eq(levels[1]["level_seed"], level.level_seed, "the seed as it is now")


# Anything that is an Object can't come back with allow_objects off,
# so nothing in the data may be one. This guards every field added
# later too.
func test_serialize_holds_no_objects() -> void:
	var levels: Dictionary = _serialize([_level(0), _level(1)])
	assert_eq(_object_in(levels, "levels"), "", "an Object in the save data")


func test_serialize_skips_a_null_level() -> void:
	var levels: Array[Level] = [_level(0), null]
	assert_eq(_serialize(levels).keys(), [0], "only the real level is saved")


func test_serialize_with_no_levels_is_empty() -> void:
	assert_eq(_serialize([]), {}, "an empty world, not an error")


func test_serialized_data_survives_store_var_with_objects_off() -> void:
	var levels: Dictionary = _serialize([_level(0)])
	var back: Variant = bytes_to_var(var_to_bytes(levels))
	assert_eq(back, levels, "plain data round-trips through Godot's encoding")


# --- deserialize ---

func test_deserialize_builds_one_level_per_entry() -> void:
	var levels: Dictionary = _deserialize({0: _level_data(0), 1: _level_data(1)})
	assert_eq(_sorted_keys(levels), [0, 1], "a level for each saved depth")


func test_deserialize_takes_the_saved_layers() -> void:
	var level: Level = _deserialize({1: _level_data(1)})[1]
	assert_eq(level.level_tiles.ground, _filled(_size(1), TileKind.GROUND.DIRT),
		"ground decompressed and loaded")
	assert_eq(level.level_tiles.top, _filled(_size(1), TileKind.TOP.OPEN),
		"top decompressed and loaded")
	assert_eq(level.level_tiles.ore, _filled(_size(1), TileKind.ORE.COPPER),
		"ore decompressed and loaded")


# Trap 7: the saved number is the seed. Re-hashing a string on load
# could give a different answer in another Godot version.
func test_deserialize_takes_the_saved_seed_without_rehashing() -> void:
	var level: Level = _deserialize({1: _level_data(1)})[1]
	assert_eq(level.level_seed, TEST_SEED, "the seed from the save")


func test_deserialize_skips_a_level_with_no_seed() -> void:
	var saved: Dictionary = _level_data(1)
	saved.erase("level_seed")
	var levels: Dictionary = _deserialize({0: _level_data(0), 1: saved})
	assert_eq(levels.keys(), [0], "only the level with a seed loads")


func test_deserialize_missing_layer_keeps_its_default() -> void:
	var saved: Dictionary = _level_data(1)
	saved["tiles"].erase("ore")
	var level: Level = _deserialize({1: saved})[1]
	assert_eq(level.level_tiles.get_ore(0, 0), TileKind.ORE.NONE, "ore is the default")
	assert_eq(level.level_tiles.top, _filled(_size(1), TileKind.TOP.OPEN),
		"the other layers loaded")


func test_deserialize_skips_a_level_whose_layer_is_the_wrong_size() -> void:
	var bad: Dictionary = _level_data(1)
	bad["tiles"]["top"] = _packed(_filled(_size(1) - 1, TileKind.TOP.OPEN))
	var levels: Dictionary = _deserialize({0: _level_data(0), 1: bad})
	assert_false(levels.has(1), "the broken level is not loaded")
	assert_true(levels.has(0), "the good level still is")


# B's staging: a saved radius that doesn't match the recipe can't be
# taken yet, so the level is skipped. C builds from the saved bound
# instead (D-112), and this test changes then.
func test_deserialize_skips_a_level_saved_with_another_radius() -> void:
	var radius: int = _radius(1) + 1
	var width: int = 2 * radius + 1
	var saved: Dictionary = {
		"level_seed": TEST_SEED,
		"bound": {"depth": 1, "radius": radius},
		"tiles": {"top": _packed(_filled(width * width, TileKind.TOP.OPEN))},
	}
	assert_eq(_deserialize({1: saved}), {}, "skipped, not resized")


func test_deserialize_skips_a_key_that_is_not_an_int() -> void:
	var levels: Dictionary = _deserialize({"1": _level_data(1)})
	assert_eq(levels, {}, "a depth key must be an int")


func test_deserialize_skips_a_level_with_no_bound() -> void:
	var saved: Dictionary = _level_data(1)
	saved.erase("bound")
	var levels: Dictionary = _deserialize({0: _level_data(0), 1: saved})
	assert_eq(levels.keys(), [0], "only the level with a bound loads")


# The radius sizes every layer's decompression; without it the level
# can't be read.
func test_deserialize_skips_a_level_with_no_radius() -> void:
	var saved: Dictionary = _level_data(1)
	saved["bound"].erase("radius")
	var levels: Dictionary = _deserialize({0: _level_data(0), 1: saved})
	assert_eq(levels.keys(), [0], "only the level with a radius loads")


# A save is a file anyone can edit: every wrong type skips the level
# it's in and leaves the rest of the load alone, never a script error.
func _assert_bad_level_skipped(saved: Variant, why: String) -> void:
	var levels: Dictionary = _deserialize({0: _level_data(0), 1: saved})
	assert_eq(levels.keys(), [0], "%s: only the good level loads" % why)


func test_deserialize_skips_an_entry_that_is_not_a_dictionary() -> void:
	_assert_bad_level_skipped("level one", "entry is a String")


func test_deserialize_skips_a_seed_that_is_not_an_int() -> void:
	var saved: Dictionary = _level_data(1)
	saved["level_seed"] = "123"
	_assert_bad_level_skipped(saved, "seed is a String")


func test_deserialize_skips_a_bound_that_is_not_a_dictionary() -> void:
	var saved: Dictionary = _level_data(1)
	saved["bound"] = [1, _radius(1)]
	_assert_bad_level_skipped(saved, "bound is an Array")


func test_deserialize_skips_a_depth_that_is_not_an_int() -> void:
	var saved: Dictionary = _level_data(1)
	saved["bound"]["depth"] = 1.0
	_assert_bad_level_skipped(saved, "depth is a float")


func test_deserialize_skips_a_radius_that_is_not_an_int() -> void:
	var saved: Dictionary = _level_data(1)
	saved["bound"]["radius"] = "64"
	_assert_bad_level_skipped(saved, "radius is a String")


func test_deserialize_skips_a_negative_radius() -> void:
	var saved: Dictionary = _level_data(1)
	saved["bound"]["radius"] = -1
	_assert_bad_level_skipped(saved, "radius is negative")


func test_deserialize_skips_tiles_that_are_not_a_dictionary() -> void:
	var saved: Dictionary = _level_data(1)
	saved["tiles"] = PackedByteArray()
	_assert_bad_level_skipped(saved, "tiles is a PackedByteArray")


func test_deserialize_skips_a_layer_that_is_not_bytes() -> void:
	var saved: Dictionary = _level_data(1)
	saved["tiles"]["top"] = [1, 2, 3]
	_assert_bad_level_skipped(saved, "top is an Array")


# The right type with the wrong contents: bytes that aren't ZSTD at
# all, and a real compressed layer cut short as a truncated file would.
func test_deserialize_skips_a_layer_of_garbage_bytes() -> void:
	var saved: Dictionary = _level_data(1)
	saved["tiles"]["top"] = PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8])
	_assert_bad_level_skipped(saved, "top is not ZSTD")


func test_deserialize_skips_a_layer_cut_short() -> void:
	var saved: Dictionary = _level_data(1)
	var packed: PackedByteArray = saved["tiles"]["top"]
	saved["tiles"]["top"] = packed.slice(0, packed.size() / 2)
	_assert_bad_level_skipped(saved, "top is half a layer")


func test_deserialize_skips_a_key_that_disagrees_with_its_bound() -> void:
	var saved: Dictionary = _level_data(1)
	saved["bound"]["depth"] = 2
	_assert_bad_level_skipped(saved, "keyed 1, bound says 2")


func test_deserialize_with_no_levels_is_empty() -> void:
	assert_eq(_deserialize({}), {}, "nothing to load")


# A level built and then refused must be freed, or every bad load
# leaks a node.
func test_deserialize_frees_a_level_it_refuses() -> void:
	var bad: Dictionary = _level_data(1)
	bad["tiles"]["ore"] = _packed(_filled(_size(1) - 1, TileKind.ORE.NONE))
	_deserialize({1: bad})
	assert_no_new_orphans("a refused level is freed")


func test_deserialized_layers_are_not_shared_with_the_data() -> void:
	var saved: Dictionary = _level_data(1)
	var top_before: PackedByteArray = saved["tiles"]["top"].duplicate()
	var level: Level = _deserialize({1: saved})[1]
	level.level_tiles.set_top(0, 0, TileKind.TOP.MINABLE_ROCK)
	assert_eq(saved["tiles"]["top"], top_before, "a dig doesn't reach the save data")


# --- round trip ---

func test_round_trip_is_byte_identical_on_every_layer() -> void:
	var originals: Array[Level] = [_level(0), _level(1), _level(2)]
	originals[0].level_tiles.set_top(1, 0, TileKind.TOP.OPEN)
	originals[1].level_tiles.set_ore(-2, 1, TileKind.ORE.COPPER)
	originals[2].level_tiles.set_ground(0, -3, TileKind.GROUND.DIRT)

	var loaded: Dictionary = _deserialize(_serialize(originals))
	for original: Level in originals:
		var back: Level = loaded[original.depth]
		var where: String = "depth %d" % original.depth
		assert_eq(back.level_tiles.ground, original.level_tiles.ground, "%s ground" % where)
		assert_eq(back.level_tiles.top, original.level_tiles.top, "%s top" % where)
		assert_eq(back.level_tiles.ore, original.level_tiles.ore, "%s ore" % where)
		assert_eq(back.level_tiles.level_bound.radius,
			original.level_tiles.level_bound.radius, "%s radius" % where)


func test_round_trip_keeps_each_levels_seed() -> void:
	var originals: Array[Level] = [_level(0), _level(1)]
	var loaded: Dictionary = _deserialize(_serialize(originals))
	for original: Level in originals:
		assert_eq(loaded[original.depth].level_seed, original.level_seed,
			"depth %d's seed" % original.depth)


func test_round_trip_keeps_each_depths_digs_its_own() -> void:
	var originals: Array[Level] = [_level(0), _level(1)]
	originals[0].level_tiles.set_top(1, 0, TileKind.TOP.OPEN)

	var loaded: Dictionary = _deserialize(_serialize(originals))
	assert_eq(loaded[0].level_tiles.get_top(1, 0), TileKind.TOP.OPEN, "the Surface dig")
	assert_eq(loaded[1].level_tiles.get_top(1, 0), TileKind.TOP.MINABLE_ROCK,
		"−1 untouched at the same (x, y)")


# --- save_game: writing the file (save-files.md §4, D-111) ---
# Write the temporary file, move the old save to the backup, then
# rename the temporary file into place. Never written in place.

func _path(file: String) -> String:
	return TEST_SLOT.path_join(file)


func _exists(file: String) -> bool:
	return FileAccess.file_exists(_path(file))


# A save file holds two values: the header, then the body. Each is
# read the way a load must, with objects off.
func _read_header(file: String) -> Variant:
	var f: FileAccess = FileAccess.open(_path(file), FileAccess.READ)
	if f == null:
		return null
	return f.get_var(false)


func _read(file: String) -> Variant:
	var f: FileAccess = FileAccess.open(_path(file), FileAccess.READ)
	if f == null:
		return null
	f.get_var(false)
	return f.get_var(false)


# Levels only: actors need levels in the tree, which these don't use.
func _save(levels: Array[Level], slot: String = TEST_SLOT) -> SaveGame.REFUSAL_REASON:
	var no_actors: Array[Node] = []
	return SaveGame.save_game(slot, levels, no_actors, null, TEST_ROOT)


# A save whose Surface has one tile dug at (x, 0), so two saves can
# be told apart by which tile is open.
func _world_with_dig(x: int) -> Array[Level]:
	var level: Level = _level(0)
	level.level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	return [level]


func _saved_top(file: String) -> PackedByteArray:
	var data: Variant = _read(file)
	var packed: PackedByteArray = data["levels"][0]["tiles"]["top"]
	return packed.decompress(_size(0), SaveGame.COMPRESSION_MODE)


func _top_of(levels: Array[Level]) -> PackedByteArray:
	return levels[0].level_tiles.top


func test_first_save_writes_world_save_only() -> void:
	var result: SaveGame.REFUSAL_REASON = _save(_world_with_dig(1))
	assert_eq(result, SaveGame.REFUSAL_REASON.NONE, "the save succeeds")
	assert_true(_exists("world.save"), "world.save written")
	assert_false(_exists("world.save.tmp"), "no temporary file left behind")
	assert_false(_exists("world.save.bak"), "nothing to back up on the first save")


# The header is its own value, so a later format can be detected
# before the body is read.
func test_the_header_holds_the_current_format_version() -> void:
	_save(_world_with_dig(1))
	var header: Variant = _read_header("world.save")
	assert_true(header is Dictionary, "the header is plain data")
	assert_eq(typeof(header.get("format_version")), TYPE_INT, "the version is an int")
	assert_eq(header.get("format_version"), SaveGame.FORMAT_VERSION,
		"the build's own version")


func test_saved_file_reads_back_as_the_serialized_data() -> void:
	var levels: Array[Level] = _world_with_dig(1)
	_save(levels)
	var body: Variant = _read("world.save")
	assert_eq(body.get("levels"), _serialize(levels),
		"the file holds exactly what serialize produced")
	assert_eq(body.get("format_version"), SaveGame.FORMAT_VERSION,
		"and the version again")


func test_saved_file_is_a_dictionary_with_objects_off() -> void:
	_save(_world_with_dig(1))
	assert_true(_read("world.save") is Dictionary,
		"get_var with allow_objects off gives back plain data")


func test_second_save_moves_the_first_to_the_backup() -> void:
	var first: Array[Level] = _world_with_dig(1)
	var second: Array[Level] = _world_with_dig(2)
	_save(first)
	var result: SaveGame.REFUSAL_REASON = _save(second)
	assert_eq(result, SaveGame.REFUSAL_REASON.NONE, "the second save succeeds")
	assert_eq(_saved_top("world.save"), _top_of(second), "world.save is the newest")
	assert_eq(_saved_top("world.save.bak"), _top_of(first), "the backup is the one before")
	assert_false(_exists("world.save.tmp"), "no temporary file left behind")


func test_only_one_backup_is_kept() -> void:
	_save(_world_with_dig(1))
	var second: Array[Level] = _world_with_dig(2)
	_save(second)
	var third: Array[Level] = _world_with_dig(3)
	_save(third)
	assert_eq(_saved_top("world.save"), _top_of(third), "world.save is the third")
	assert_eq(_saved_top("world.save.bak"), _top_of(second), "the backup is the second")
	assert_eq(DirAccess.get_files_at(TEST_SLOT).size(), 2, "just the save and one backup")


# A crash mid-write leaves a .tmp behind; the next save writes over it.
func test_a_leftover_temporary_file_is_replaced() -> void:
	var f: FileAccess = FileAccess.open(_path("world.save.tmp"), FileAccess.WRITE)
	f.store_string("half a save")
	f.close()
	var levels: Array[Level] = _world_with_dig(1)
	var result: SaveGame.REFUSAL_REASON = _save(levels)
	assert_eq(result, SaveGame.REFUSAL_REASON.NONE, "the save succeeds")
	assert_false(_exists("world.save.tmp"), "the leftover is gone")
	assert_eq(_saved_top("world.save"), _top_of(levels), "world.save is the new save")


# Trap 4: if the new save can't be written, the old one must survive
# untouched, and must not be moved to the backup. A folder named
# world.save.tmp makes the write fail.
func test_a_failed_write_leaves_the_old_save_alone() -> void:
	var first: Array[Level] = _world_with_dig(1)
	_save(first)
	DirAccess.make_dir_absolute(_path("world.save.tmp"))
	var result: SaveGame.REFUSAL_REASON = _save(_world_with_dig(2))
	assert_ne(result, SaveGame.REFUSAL_REASON.NONE, "the save reports failure")
	assert_eq(_saved_top("world.save"), _top_of(first), "the old save is untouched")
	assert_false(_exists("world.save.bak"), "and was not moved to the backup")


func test_saving_an_empty_world_writes_a_readable_file() -> void:
	var result: SaveGame.REFUSAL_REASON = _save([])
	assert_eq(result, SaveGame.REFUSAL_REASON.NONE, "the save succeeds")
	assert_eq(_read("world.save").get("levels"), {}, "an empty world, still readable")


# Whatever save_game does about a missing slot folder, it must never
# report success without a save on disk.
func test_success_always_means_a_file_exists() -> void:
	var missing: String = TEST_SLOT.path_join("no-such-slot")
	var result: SaveGame.REFUSAL_REASON = _save(_world_with_dig(1), missing)
	if result == SaveGame.REFUSAL_REASON.NONE:
		assert_true(FileAccess.file_exists(missing.path_join("world.save")),
			"success, so the file is there")
	else:
		assert_false(FileAccess.file_exists(missing.path_join("world.save")),
			"failure, and no file claims otherwise")


# --- save_game: refusing paths outside the saves root ---

func test_save_refuses_a_slot_outside_the_root() -> void:
	var result: SaveGame.REFUSAL_REASON = _save(_world_with_dig(1), "user://elsewhere/slot-001")
	assert_eq(result, SaveGame.REFUSAL_REASON.SAVE_FAILED, "not inside the root")
	assert_push_error("Failed to save outside of save path")


# "<root>-old" starts with "<root>" as a string, but it isn't inside it.
func test_save_refuses_a_sibling_that_shares_the_roots_name() -> void:
	var result: SaveGame.REFUSAL_REASON = _save(_world_with_dig(1), TEST_ROOT + "-old/slot-001")
	assert_eq(result, SaveGame.REFUSAL_REASON.SAVE_FAILED, "a sibling, not inside")
	assert_push_error("Failed to save outside of save path")


func test_save_refuses_a_path_that_climbs_out_of_the_root() -> void:
	var result: SaveGame.REFUSAL_REASON = _save(_world_with_dig(1), TEST_ROOT + "/../elsewhere")
	assert_eq(result, SaveGame.REFUSAL_REASON.SAVE_FAILED, ".. leaves the root")
	assert_push_error("Failed to save outside of save path")


func test_save_refuses_the_root_itself() -> void:
	var result: SaveGame.REFUSAL_REASON = _save(_world_with_dig(1), TEST_ROOT)
	assert_eq(result, SaveGame.REFUSAL_REASON.SAVE_FAILED, "a slot is a folder inside it")
	assert_push_error("Failed to save outside of save path")


# --- slots ---

func test_setup_makes_the_first_slot_under_the_root_given() -> void:
	SaveDirs.remove_tree(TEST_ROOT)
	SaveGame.setup(TEST_ROOT)
	assert_true(DirAccess.dir_exists_absolute(TEST_SLOT), "slot-001 under the given root")


func test_only_folders_named_exactly_like_a_slot_are_slots() -> void:
	for dir: String in ["slot-002", "slot-0012", "old-slot-001-copy", "slot-01"]:
		DirAccess.make_dir_recursive_absolute(TEST_ROOT.path_join(dir))
	var slots: Array = Array(SaveGame.get_save_slots(TEST_ROOT))
	slots.sort()
	assert_eq(slots, [TEST_ROOT.path_join("slot-001"), TEST_ROOT.path_join("slot-002")],
		"slot- and exactly three digits, nothing before or after")


# --- Global.is_regex_match ---

func test_a_regex_matches_anywhere_unless_anchored() -> void:
	assert_true(Global.is_regex_match("old-slot-001", r"slot-\d{3}"), "unanchored")
	assert_false(Global.is_regex_match("old-slot-001", r"^slot-\d{3}$"), "anchored")
	assert_true(Global.is_regex_match("slot-001", r"^slot-\d{3}$"), "an exact match")


func test_a_pattern_that_wont_compile_matches_nothing() -> void:
	assert_false(Global.is_regex_match("anything", "("), "no match")
	assert_push_error("Invalid regex pattern")
	assert_engine_error("missing closing parenthesis")


# --- load_game: refusals, and what they leave behind ---

func _write_save(data: Dictionary) -> void:
	SaveGame._overwrite_data(SaveGame.FORMAT_VERSION, data, _path(SaveGame.SAVE_BASE_NAME))


# One level's save data, as save_game writes it. The level it was taken
# from is freed, so it isn't counted as an orphan.
func _saved_levels() -> Dictionary:
	var level: Level = Level.new()
	level.setup(0)
	var levels: Array[Level] = [level]
	var data: Dictionary = SaveGame._serialize_levels(levels)
	level.free()
	return data


func test_load_refuses_levels_that_are_not_a_dictionary() -> void:
	_write_save({"levels": [_level_data(0)], "actors": {}})
	assert_eq(SaveGame.load_game(TEST_SLOT), {}, "levels is an Array")


func test_load_refuses_a_save_with_no_levels_entry() -> void:
	_write_save({"actors": {}})
	assert_eq(SaveGame.load_game(TEST_SLOT), {}, "nothing to load")


func test_load_refuses_a_save_with_empty_levels() -> void:
	_write_save({"levels": {}, "actors": {}})
	assert_eq(SaveGame.load_game(TEST_SLOT), {}, "nothing to load")


func test_a_load_refused_for_its_actors_builds_no_levels() -> void:
	_write_save({"levels": _saved_levels(), "actors": "not a dictionary"})
	var before: int = _orphans()
	var game_data: Dictionary = SaveGame.load_game(TEST_SLOT)
	assert_eq(game_data, {}, "the load is refused")
	assert_eq(_orphans(), before, "and no level was left orphaned")


func test_free_game_data_frees_its_levels_and_actors() -> void:
	var before: int = _orphans()
	var actor: Actor = Global.actor_packed_scene.instantiate()
	var game_data: Dictionary = {
		"levels": SaveGame._deserialize_levels(_saved_levels()),
		"actors": {"Someone": {"actor_obj": actor}},
	}
	assert_gt(_orphans(), before, "the loaded nodes are orphans until placed")
	SaveGame.free_game_data(game_data)
	assert_eq(_orphans(), before, "and none are left once freed")
	assert_false(is_instance_valid(actor), "the actor too")


# --- load_game: actors stand on the levels the load built ---

func _actor_entry(depth: int) -> Dictionary:
	return {
		"is_active": true,
		"actor_name": "Loaded",
		"worldpos": {"x": 3, "y": -2, "depth": depth},
		"facing": {"x": -1, "y": 0},
	}


# The old world's level is still in the tree when a load builds its
# actors (bug 6 of the review): they must not stand on it.
func test_loaded_actors_stand_on_the_loaded_levels() -> void:
	var old_level: Level = Global.level_packed_scene.instantiate()
	old_level.setup(0)
	add_child_autofree(old_level)
	var levels: Dictionary = SaveGame._deserialize_levels(_saved_levels())
	var actors: Dictionary = SaveGame._deserialize_actors({"Loaded": _actor_entry(0)}, levels)
	var actor: Actor = actors["Loaded"]["actor_obj"]
	assert_eq(actor.current_level, levels[0], "on the loaded level")
	assert_ne(actor.current_level, old_level, "not the one in the tree")
	assert_true(actor.current_WorldPos.equals(WorldPos.new(3, -2, 0)), "on its saved tile")
	assert_eq(actor.facing, Vector2i(-1, 0), "facing as saved")
	SaveGame.free_game_data({"levels": levels, "actors": actors})


func test_an_actor_on_a_depth_that_did_not_load_is_skipped() -> void:
	var levels: Dictionary = SaveGame._deserialize_levels(_saved_levels())
	var before: int = _orphans()
	var actors: Dictionary = SaveGame._deserialize_actors({"Loaded": _actor_entry(5)}, levels)
	assert_eq(actors, {}, "no actor without its level")
	assert_push_warning("didn't load")
	assert_eq(_orphans(), before, "and none was left orphaned")
	SaveGame.free_game_data({"levels": levels})
