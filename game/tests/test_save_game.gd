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
	return LevelRecipes.TABLE.get_bounds(depth).radius


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


# Saved levels to live ones, by depth, built into a world that is
# freed after the test, with every level in it.
func _deserialize(levels_data: Dictionary) -> Dictionary:
	var world: World = _loaded_world(levels_data)
	var levels: Dictionary = {}
	for level: Level in world.levels():
		levels[level.depth] = level
	return levels


# A world built from saved levels, as a load builds it; freed after
# the test.
func _loaded_world(levels_data: Dictionary) -> World:
	var world: World = autofree(World.new())
	SaveGame._deserialize_levels(levels_data, world)
	return world


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
# all, and a real compressed layer cut short as a truncated file
# would.
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


# A depth with no recipe row is refused, not folded onto the last
# level by Level.set_depth's clamp. The last row's level is the one it
# would have overwritten.
func test_deserialize_refuses_a_depth_with_no_recipe_row() -> void:
	var last: int = LevelRecipes.TABLE.rows.size() - 1
	var beyond: int = last + 1
	var saved: Dictionary = _level_data(last)
	saved["bound"]["depth"] = beyond
	var world: World = autofree(World.new())
	var before: int = _orphans()
	SaveGame._deserialize_levels({beyond: saved}, world)
	assert_eq(world.levels(), [] as Array[Level], "no level for a depth with no recipe")
	assert_push_warning("Saved depth %d has no recipe row" % beyond)
	assert_eq(_orphans(), before, "nothing was built for the refused depth")


func test_deserialize_with_no_levels_is_empty() -> void:
	assert_eq(_deserialize({}), {}, "nothing to load")


# A level built and then refused must be freed, or every bad load
# leaks a node.
func test_deserialize_frees_a_level_it_refuses() -> void:
	var bad: Dictionary = _level_data(1)
	bad["tiles"]["ore"] = _packed(_filled(_size(1) - 1, TileKind.ORE.NONE))
	var world: World = autofree(World.new())
	var before: int = _orphans()
	SaveGame._deserialize_levels({1: bad}, world)
	assert_eq(world.levels(), [] as Array[Level], "the level isn't in the world")
	assert_eq(_orphans(), before, "a refused level is freed")


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


# --- fixtures (D-104, D-113) ---

# A ladder and the world spawn on -1, each with its own id.
func _level_with_fixtures() -> Level:
	var level: Level = _level(1)
	level.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(4, -3, 1), 41))
	level.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.WORLD_SPAWN, WorldPos.new(-2, 5, 1), 42))
	return level


func _fixture_entry(kind: int, x: int, y: int, id: int) -> Dictionary:
	return {"kind": kind, "x": x, "y": y, "id": id}


# Kind, tile and id, as numbers; the depth is the level's.
func _fixtures_of(level: Level) -> Array:
	var found: Array = []
	for fixture: Fixture in level.level_fixtures.all():
		found.append([fixture.kind, fixture.tile.x, fixture.tile.y, fixture.tile.depth, fixture.id])
	return found


# Every level, as generation builds it. Freed after the test.
func _generated_world() -> Array[Level]:
	var levels: Array[Level] = []
	var fixture_ids: IdAllocator = IdAllocator.new()
	for recipe: LevelRecipe in LevelRecipes.TABLE.rows:
		levels.append(autofree(LevelGenerator.generate_level(recipe, 0, fixture_ids)))
	return levels


func test_serialize_saves_each_fixture_as_kind_tile_and_id() -> void:
	var saved: Dictionary = _serialize([_level_with_fixtures()])[1]
	assert_eq(saved["fixtures"], [
		_fixture_entry(ObjectKind.OBJECT.LADDER, 4, -3, 41),
		_fixture_entry(ObjectKind.OBJECT.WORLD_SPAWN, -2, 5, 42),
	], "one entry per fixture, in the store's order")
	for entry: Dictionary in saved["fixtures"]:
		for field: String in entry:
			assert_eq(typeof(entry[field]), TYPE_INT, "%s is a plain int" % field)


func test_serialize_saves_a_level_with_no_fixtures_as_an_empty_list() -> void:
	assert_eq(_serialize([_level(0)])[0]["fixtures"], [], "saved, and empty")


func test_serialized_fixtures_hold_no_objects() -> void:
	var levels: Dictionary = _serialize([_level_with_fixtures()])
	assert_eq(_object_in(levels, "levels"), "", "plain data only")


func test_deserialize_replaces_the_generated_fixtures_with_the_saved() -> void:
	var saved: Dictionary = _level_data(0)
	saved["fixtures"] = [_fixture_entry(ObjectKind.OBJECT.LADDER, 7, 8, 300)]
	var level: Level = _deserialize({0: saved})[0]
	assert_eq(_fixtures_of(level), [[ObjectKind.OBJECT.LADDER, 7, 8, 0, 300]],
		"only the saved ladder: the generated spawn is gone")


func test_deserialize_with_an_empty_fixture_list_leaves_none() -> void:
	var saved: Dictionary = _level_data(0)
	saved["fixtures"] = []
	assert_eq(_deserialize({0: saved})[0].level_fixtures.all(), [] as Array[Fixture],
		"an empty list is no fixtures, not the generated ones")


# A save written before fixtures were saved keeps what generation put
# there, the way a missing tile layer keeps its default.
func test_deserialize_without_a_fixtures_entry_keeps_the_generated() -> void:
	var generated: Level = autofree(LevelGenerator.generate_level(LevelRecipes.TABLE.get_recipe(0), 0,
		IdAllocator.new()))
	var level: Level = _deserialize({0: _level_data(0)})[0]
	assert_eq(_fixtures_of(level).size(), _fixtures_of(generated).size(),
		"as many fixtures as generation places")
	assert_gt(level.level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN).size(), 0,
		"the Surface's generated spawn among them")


func test_deserialize_skips_fixtures_that_are_not_a_list() -> void:
	var saved: Dictionary = _level_data(1)
	saved["fixtures"] = {"kind": 1}
	_assert_bad_level_skipped(saved, "fixtures is a Dictionary")


func test_deserialize_skips_a_fixture_that_is_not_a_dictionary() -> void:
	var saved: Dictionary = _level_data(1)
	saved["fixtures"] = [[ObjectKind.OBJECT.LADDER, 0, 0, 1]]
	_assert_bad_level_skipped(saved, "a fixture is an Array")


func test_deserialize_skips_a_fixture_missing_a_field_or_of_the_wrong_type() -> void:
	for field: String in ["kind", "x", "y", "id"]:
		var missing: Dictionary = _fixture_entry(ObjectKind.OBJECT.LADDER, 0, 0, 1)
		missing.erase(field)
		var as_float: Dictionary = _fixture_entry(ObjectKind.OBJECT.LADDER, 0, 0, 1)
		as_float[field] = 1.0
		for entry: Dictionary in [missing, as_float]:
			var saved: Dictionary = _level_data(1)
			saved["fixtures"] = [entry]
			_assert_bad_level_skipped(saved, "fixture %s: %s" % [field, entry])


# A saved fixture goes in without the placement rules (D-113): one on
# solid rock, under no hole, still comes back.
func test_deserialize_takes_a_fixture_the_rules_would_refuse() -> void:
	var saved: Dictionary = _level_data(1)
	saved["tiles"].erase("top")
	saved["fixtures"] = [_fixture_entry(ObjectKind.OBJECT.LADDER, 9, 9, 5)]
	var level: Level = _deserialize({1: saved})[1]
	assert_eq(_fixtures_of(level), [[ObjectKind.OBJECT.LADDER, 9, 9, 1, 5]], "it loads")


func test_deserialize_skips_a_second_fixture_with_the_same_id() -> void:
	var saved: Dictionary = _level_data(1)
	saved["fixtures"] = [
		_fixture_entry(ObjectKind.OBJECT.LADDER, 1, 1, 5),
		_fixture_entry(ObjectKind.OBJECT.WORLD_SPAWN, 2, 2, 5),
	]
	var level: Level = _deserialize({1: saved})[1]
	assert_eq(_fixtures_of(level), [[ObjectKind.OBJECT.LADDER, 1, 1, 1, 5]], "the first is kept")
	assert_push_warning("Saved fixture id 5 is on depth 1 twice")


func test_round_trip_keeps_every_fixtures_kind_tile_and_id() -> void:
	var original: Level = _level_with_fixtures()
	var loaded: Level = _deserialize(_serialize([original]))[1]
	assert_eq(_fixtures_of(loaded), _fixtures_of(original), "the same fixtures, in order")


# The world spawn is a fixture (D-091), so it comes back like a
# ladder, with its tile and id, not placed again at random.
func test_round_trip_brings_the_world_spawn_back_where_it_was() -> void:
	var originals: Array[Level] = _generated_world()
	var spawn: Fixture = Spawning.world_spawn(originals)
	var loaded: Dictionary = _deserialize(_serialize(originals))
	var loaded_levels: Array[Level] = []
	loaded_levels.assign(loaded.values())
	var back: Fixture = Spawning.world_spawn(loaded_levels)
	assert_true(back.tile.equals(spawn.tile), "on the same tile: %s" % spawn.tile)
	assert_eq(back.id, spawn.id, "with the same id")


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


# Levels only, in a world made for the save and taken apart after, so
# the test keeps its levels.
func _save(levels: Array[Level], slot: String = TEST_SLOT) -> SaveGame.REFUSAL_REASON:
	var world: World = World.new()
	world.world_seed = TEST_SEED
	for level: Level in levels:
		world.add_level(level)
	var result: SaveGame.REFUSAL_REASON = SaveGame.save_game(slot, world,
		SaveSession.new(-1), TEST_ROOT)
	for level: Level in levels:
		level.get_parent().remove_child(level)
		level.world = null
	world.free()
	return result


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


# Unix seconds and the offset, both ints, from one read of the clock
# (D-122).
func test_the_save_time_is_unix_seconds_and_the_utc_offset() -> void:
	var before: int = int(Time.get_unix_time_from_system())
	_save(_world_with_dig(1))
	var after: int = int(Time.get_unix_time_from_system())
	var data: Variant = _read("world.save")
	assert_eq(typeof(data.get("saved_at")), TYPE_INT, "the time is an int")
	assert_between(data.get("saved_at"), before, after, "and it's now")
	assert_eq(data.get("saved_at_utc_offset"), Time.get_time_zone_from_system().bias,
		"the offset is the system's, in minutes")


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


# Slice 003 trap 3: an Object in a save file could carry a script, so
# a load reads with allow_objects off. A file written with objects on
# must come back as no data at all, never as the Object.
func test_a_save_file_holding_an_object_is_not_decoded_as_one() -> void:
	var f: FileAccess = FileAccess.open(_path(SaveGame.SAVE_BASE_NAME), FileAccess.WRITE)
	f.store_var({"format_version": SaveGame.FORMAT_VERSION}, false)
	var smuggled: Resource = Resource.new()
	f.store_var({"levels": smuggled, "actors": {"Someone": smuggled}}, true)
	f.close()

	var data: Dictionary = SaveGame.get_save_data(TEST_SLOT)
	assert_eq(_object_in(data, "data"), "", "no Object came out of the file")
	assert_false(data.has("levels"), "the body that held it is dropped whole")
	assert_null(SaveGame.load_game(TEST_SLOT), "and the load is refused")
	# Each read logs three: the refused Object, then the failed decode
	# passed up twice. get_save_data and load_game read once each.
	assert_engine_error_count(6, "Godot refuses the Object on each read")


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


# A crash mid-write leaves a .tmp behind; the next save writes over
# it.
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


# "<root>-old" starts with "<root>" as a string, but it isn't inside
# it.
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


# Launch continues the first slot, so the list is in name order, not
# the order the folders were made in (R-P6).
func test_slots_are_listed_in_name_order() -> void:
	for dir: String in ["slot-009", "slot-003", "slot-010"]:
		DirAccess.make_dir_recursive_absolute(TEST_ROOT.path_join(dir))
	var slots: Array = Array(SaveGame.get_save_slots(TEST_ROOT))
	var names: Array = slots.map(func(path: String) -> String: return path.get_file())
	assert_eq(names, ["slot-001", "slot-003", "slot-009", "slot-010"], "sorted by name")


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

# The save as given, with every required header key it leaves out
# filled in, so a test only spells out what it's about (D-121, D-122).
func _write_save(data: Dictionary) -> void:
	_write_raw_save(data.merged(_required_header()))


func _write_raw_save(data: Dictionary) -> void:
	SaveGame._overwrite_data(SaveGame.FORMAT_VERSION, data, _path(SaveGame.SAVE_BASE_NAME))


func _required_header() -> Dictionary:
	return {
		"world_seed": TEST_SEED,
		"game_version": Global.get_game_version(),
		"saved_at": 1793569749,
		"saved_at_utc_offset": -300,
	}


# One level's save data, as save_game writes it. The level it was
# taken from is freed, so it isn't counted as an orphan.
func _saved_levels() -> Dictionary:
	var level: Level = Level.new()
	level.setup(0)
	var levels: Array[Level] = [level]
	var data: Dictionary = SaveGame._serialize_levels(levels)
	level.free()
	return data


func test_load_refuses_levels_that_are_not_a_dictionary() -> void:
	_write_save({"levels": [_level_data(0)], "actors": {}})
	assert_null(SaveGame.load_game(TEST_SLOT), "levels is an Array")


func test_load_refuses_a_save_with_no_levels_entry() -> void:
	_write_save({"actors": {}})
	assert_null(SaveGame.load_game(TEST_SLOT), "nothing to load")


func test_load_refuses_a_save_with_empty_levels() -> void:
	_write_save({"levels": {}, "actors": {}})
	assert_null(SaveGame.load_game(TEST_SLOT), "nothing to load")


# Both save time keys are required ints: a save from before them, or
# from when the time was saved as date strings, is refused (D-122).
func test_load_refuses_a_save_time_missing_or_not_an_int() -> void:
	var broken: Dictionary = {
		"no saved_at": ["saved_at", null],
		"saved_at a date string": ["saved_at", "2026-11-01T14:30:05"],
		"no offset": ["saved_at_utc_offset", null],
		"offset a string": ["saved_at_utc_offset", "-300"],
	}
	for case: String in broken:
		var data: Dictionary = {"levels": _saved_levels(), "actors": {10: _actor_entry(0)}}
		data.merge(_required_header())
		var key: String = broken[case][0]
		if broken[case][1] == null: data.erase(key)
		else: data[key] = broken[case][1]
		_write_raw_save(data)
		var before: int = _orphans()
		assert_null(SaveGame.load_game(TEST_SLOT), "%s is refused" % case)
		assert_eq(_orphans(), before, "%s builds nothing" % case)


func test_a_load_refused_for_its_actors_builds_no_levels() -> void:
	_write_save({"levels": _saved_levels(), "actors": "not a dictionary"})
	var before: int = _orphans()
	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	assert_null(loaded_game, "the load is refused")
	assert_eq(_orphans(), before, "and no level was left orphaned")


func test_free_world_frees_the_loaded_world_with_its_levels_and_actors() -> void:
	var before: int = _orphans()
	var loaded: SaveGame.LoadedGame = SaveGame.LoadedGame.new()
	loaded.world = World.new()
	SaveGame._deserialize_levels(_saved_levels(), loaded.world)
	var actors: Array[Actor] = SaveGame._deserialize_actors({10: _actor_entry(0)}, loaded.world)
	assert_gt(_orphans(), before, "the loaded nodes are orphans until placed")
	loaded.free_world()
	assert_null(loaded.world, "the load holds no world afterwards")
	assert_eq(_orphans(), before, "and none are left once freed")
	assert_false(is_instance_valid(actors[0]), "the actor too")


# --- load_game: actors stand on the levels the load built ---

func _actor_entry(depth: int) -> Dictionary:
	return {
		"actor_name": "Loaded",
		"actor_kind": 1,
		"worldpos": {"x": 3, "y": -2, "depth": depth},
		"facing": {"x": -1, "y": 0},
	}


# The old world's level is still in the tree when a load builds its
# actors (bug 6 of the review): they must not stand on it.
func test_loaded_actors_stand_on_the_loaded_levels() -> void:
	var old_level: Level = Global.level_packed_scene.instantiate()
	old_level.setup(0)
	add_child_autofree(old_level)
	var world: World = _loaded_world(_saved_levels())
	var actors: Array[Actor] = SaveGame._deserialize_actors({"local_actor_id": 10, 10: _actor_entry(0)}, world)
	var actor: Actor = actors[0]
	assert_eq(actor.current_level, world.level_at(0), "on the loaded level")
	assert_ne(actor.current_level, old_level, "not the one in the tree")
	assert_eq(world.actors(), [actor] as Array[Actor], "and in the loaded world")
	assert_true(actor.current_WorldPos.equals(WorldPos.new(3, -2, 0)), "on its saved tile")
	assert_eq(actor.facing, Vector2i(-1, 0), "facing as saved")


func test_an_actor_on_a_depth_that_did_not_load_is_skipped() -> void:
	var world: World = _loaded_world(_saved_levels())
	var before: int = _orphans()
	var actors: Array[Actor] = SaveGame._deserialize_actors({10: _actor_entry(5)}, world)
	assert_eq(actors, [] as Array[Actor], "no actor without its level")
	assert_push_warning("didn't load")
	assert_eq(_orphans(), before, "and none was left orphaned")


# --- load_game: the fixture report (D-113) ---

func test_a_loaded_world_of_legal_fixtures_reports_no_problems() -> void:
	_write_save({"levels": SaveGame._serialize_levels(_generated_world()),
		"actors": {10: _actor_entry(0)}})
	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	assert_eq(loaded_game.problems, [] as Array[String], "the generated world is clean")
	loaded_game.free_world()


func test_a_fixture_that_breaks_a_placement_rule_loads_and_is_reported() -> void:
	var levels: Dictionary = _saved_levels()
	# The Surface saved all rock: a ladder there has no floor and no
	# level above.
	levels[0]["fixtures"] = [_fixture_entry(ObjectKind.OBJECT.LADDER, 2, 3, 77)]
	_write_save({"levels": levels, "actors": {10: _actor_entry(0)}})

	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	var surface: Level = loaded_game.world.level_at(0)
	assert_not_null(surface.level_fixtures.find(77), "the ladder loaded")
	# Once by the placement rules, once by the world's ladder check.
	assert_eq(loaded_game.problems.size(), 2, "two reports: %s" % [loaded_game.problems])
	assert_string_contains(loaded_game.problems[0], "#77")
	assert_string_contains(loaded_game.problems[0], "TILE_NOT_PASSABLE")
	assert_string_contains(loaded_game.problems[1], "no level above")
	assert_push_warning("breaks a placement rule")
	assert_push_warning("has no level above it")
	loaded_game.free_world()


# The world's own checks run too: a ramp end with no other end below
# it is reported.
func test_a_load_reports_a_ramp_problem() -> void:
	var levels: Dictionary = _saved_levels()
	var ground: PackedByteArray = _filled(_size(0), TileKind.GROUND.ROCK)
	var top: PackedByteArray = _filled(_size(0), TileKind.TOP.MINABLE_ROCK)
	var index: int = LevelTiles.new(LevelRecipes.TABLE.get_bounds(0)).get_index(0, 0)
	ground[index] = _a_down_ramp()
	top[index] = TileKind.TOP.OPEN
	levels[0]["tiles"]["ground"] = _packed(ground)
	levels[0]["tiles"]["top"] = _packed(top)
	_write_save({"levels": levels, "actors": {10: _actor_entry(0)}})

	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	assert_eq(loaded_game.problems.size(), 1, "the lone ramp end: %s" % [loaded_game.problems])
	assert_push_warning("which has no level")
	loaded_game.free_world()


func _a_down_ramp() -> int:
	for kind: int in TileKind.RAMPS:
		if TileKind.RAMPS[kind].down: return kind
	return -1


# --- what can't be saved, and what can't be loaded ---

# A slot folder with no save in it yet: nothing to load, no crash.
func test_loading_a_slot_with_no_save_file_is_refused() -> void:
	assert_null(SaveGame.load_game(TEST_SLOT), "nothing to load")
	assert_push_error("world.save")
	assert_push_error_count(1, "one error, naming the file, not an upgrade failure")


func test_serialize_skips_a_level_with_no_tiles() -> void:
	var level: Level = _level(0)
	level.level_tiles = null
	assert_eq(_serialize([level]), {0: {}}, "nothing saved for it")


func test_serialize_skips_an_actor_with_no_position() -> void:
	var actor: Actor = autofree(Global.actor_packed_scene.instantiate())
	var actors: Array[Actor] = [actor]
	assert_eq(SaveGame._serialize_actors(actors), {},
		"an actor never set up isn't saved")


# Every way an actor entry can be malformed is skipped, as each field
# of a level is: a save is a file anyone can edit.
func test_deserialize_skips_each_malformed_actor_entry() -> void:
	var world: World = _loaded_world(_saved_levels())
	var broken: Array = []
	broken.append("not a dictionary")
	for field: String in ["actor_kind", "actor_name", "worldpos", "facing"]:
		var missing: Dictionary = _actor_entry(0)
		missing.erase(field)
		broken.append(missing)
	for field: String in ["x", "y", "depth"]:
		var bad: Dictionary = _actor_entry(0)
		bad.worldpos[field] = 1.0
		broken.append(bad)
	for field: String in ["x", "y"]:
		var bad: Dictionary = _actor_entry(0)
		bad.facing[field] = "west"
		broken.append(bad)

	var before: int = _orphans()
	for entry: Variant in broken:
		assert_eq(SaveGame._deserialize_actors({10: entry}, world), [] as Array[Actor],
			"skipped: %s" % [entry])
	assert_eq(_orphans(), before, "and no actor was built for any of them")


# Actors are keyed by id; a save keyed by name, as before, is skipped
# rather than handing a String to an int parameter.
func test_deserialize_skips_an_actor_not_keyed_by_an_int_id() -> void:
	var world: World = _loaded_world(_saved_levels())
	var before: int = _orphans()
	assert_eq(SaveGame._deserialize_actors({"Loaded": _actor_entry(0)}, world), [] as Array[Actor],
		"skipped")
	assert_eq(_orphans(), before, "and no actor was built")


func test_deserialize_takes_its_id_from_the_key() -> void:
	var world: World = _loaded_world(_saved_levels())
	var actors: Array[Actor] = SaveGame._deserialize_actors({42: _actor_entry(0)}, world)
	assert_eq(actors[0].actor_id, 42, "the key is the id")


# --- round trip: actors (D-114) ---

# A tile an actor can stand on: passable, not a ramp. The first found
# row by row, or the last, so two picks on one level can differ.
func _open_tile(level: Level, last: bool = false) -> WorldPos:
	var tiles: LevelTiles = level.level_tiles
	var radius: int = tiles.level_bound.radius
	var found: WorldPos = null
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var ground: int = tiles.get_ground(x, y)
			if not TileKind.is_passable(tiles.get_top(x, y), ground): continue
			if TileKind.is_ramp(ground): continue
			found = WorldPos.new(x, y, level.depth)
			if not last: return found
	return found


func _player_on(tile: WorldPos, world: World, actor_name: String, id: int = -1) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, actor_name, tile,
		world.level_at(tile.depth), ActorKind.ACTOR.PLAYER, id)
	world.add_actor(actor)
	return actor


func _actor_in(world: World, id: int) -> Actor:
	for actor: Actor in world.actors():
		if actor.actor_id == id: return actor
	return null


func _save_world(world: World, local_actor_id: int = -1) -> SaveGame.REFUSAL_REASON:
	return SaveGame.save_game(TEST_SLOT, world, SaveSession.new(local_actor_id), TEST_ROOT)


# Each actor comes back on its own depth and tile, both on open
# floor, so nothing about the tile could send it to the spawn.
func test_two_actors_on_different_depths_round_trip_each_to_its_own() -> void:
	var world: World = autofree(LevelGenerator.generate_world(TEST_SEED))
	var tile_a: WorldPos = _open_tile(world.level_at(1))
	var tile_b: WorldPos = _open_tile(world.level_at(2), true)
	assert_not_null(tile_a, "-1 has open floor")
	assert_not_null(tile_b, "-2 has open floor")
	var a: Actor = _player_on(tile_a, world, "Upper", 10)
	_player_on(tile_b, world, "Lower", 11)
	assert_eq(_save_world(world, a.actor_id), SaveGame.REFUSAL_REASON.NONE, "the save succeeds")

	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	assert_true(loaded_game != null, "the load succeeds")
	if loaded_game == null: return
	var back_a: Actor = _actor_in(loaded_game.world, 10)
	var back_b: Actor = _actor_in(loaded_game.world, 11)
	assert_true(back_a != null and back_b != null, "both actors load")
	if back_a:
		assert_true(back_a.current_WorldPos.equals(tile_a),
			"Upper on %s, got %s" % [tile_a, back_a.current_WorldPos])
		assert_eq(back_a.current_level, loaded_game.world.level_at(1), "and on the loaded -1 level")
	if back_b:
		assert_true(back_b.current_WorldPos.equals(tile_b),
			"Lower on %s, got %s" % [tile_b, back_b.current_WorldPos])
		assert_eq(back_b.current_level, loaded_game.world.level_at(2), "and on the loaded -2 level")
	loaded_game.free_world()


# --- a slot's launch: the save, its backup, and broken files (D-111)
# ---

# Two saves that load, told apart by their world seeds.
const SAVE_SEED: int = 111
const BACKUP_SEED: int = 222


func _good_save(file: String, world_seed: int, version: int = SaveGame.FORMAT_VERSION) -> void:
	var data: Dictionary = {"levels": _saved_levels(), "actors": {10: _actor_entry(0)}}
	data.merge(_required_header())
	data["world_seed"] = world_seed
	SaveGame._overwrite_data(version, data, _path(file))


func _newer_save(file: String) -> void:
	_good_save(file, SAVE_SEED, SaveGame.FORMAT_VERSION + 1)


# A save that stops halfway, as a crash mid-write would leave it.
func _truncated_save(file: String) -> void:
	_good_save(file, SAVE_SEED)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_path(file))
	var f: FileAccess = FileAccess.open(_path(file), FileAccess.WRITE)
	f.store_buffer(bytes.slice(0, bytes.size() / 2))
	f.close()


func _unreadable_save(file: String) -> void:
	var f: FileAccess = FileAccess.open(_path(file), FileAccess.WRITE)
	f.store_string("this is not a save file")
	f.close()


func _bytes(file: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(_path(file))


func _broken_files() -> PackedStringArray:
	var broken: PackedStringArray = []
	for file: String in DirAccess.get_files_at(TEST_SLOT):
		if file.begins_with("world.broken."): broken.append(file)
	return broken


func _seed_of(slot: SaveGame.SlotLoad) -> Variant:
	return slot.loaded.header.world_seed if slot.loaded else null


func test_an_empty_slot_is_a_new_game() -> void:
	var slot: SaveGame.SlotLoad = SaveGame.load_slot(TEST_SLOT)
	assert_eq(slot.source, SaveGame.SOURCE.NEW, "nothing to load")
	assert_null(slot.loaded, "no world")
	assert_eq(slot.refusals, [] as Array[String], "and nothing refused")


func test_a_save_that_loads_is_used_and_the_backup_is_not_read() -> void:
	_good_save(SaveGame.SAVE_BASE_NAME, SAVE_SEED)
	_unreadable_save(SaveGame.BACKUP_NAME)
	var slot: SaveGame.SlotLoad = SaveGame.load_slot(TEST_SLOT)
	assert_eq(slot.source, SaveGame.SOURCE.SAVE, "the save loads")
	assert_eq(_seed_of(slot), SAVE_SEED, "the save's world")
	assert_eq(slot.refusals, [] as Array[String], "the broken backup is never tried")
	assert_eq(_broken_files(), PackedStringArray(), "and nothing is moved aside")
	slot.loaded.free_world()


# A refused world.save is kept, renamed, and the backup loads.
func _assert_refused_save_falls_back(break_save: Callable, reason: String) -> void:
	break_save.call(SaveGame.SAVE_BASE_NAME)
	_good_save(SaveGame.BACKUP_NAME, BACKUP_SEED)
	var broken_bytes: PackedByteArray = _bytes(SaveGame.SAVE_BASE_NAME)

	var slot: SaveGame.SlotLoad = SaveGame.load_slot(TEST_SLOT)
	assert_eq(slot.source, SaveGame.SOURCE.BACKUP, "the backup loads")
	assert_eq(_seed_of(slot), BACKUP_SEED, "the backup's world")
	assert_eq(slot.refusals.size(), 1, "one file refused")
	if slot.refusals.size() == 1:
		assert_string_contains(slot.refusals[0], _path(SaveGame.SAVE_BASE_NAME))
		assert_string_contains(slot.refusals[0], reason)
	assert_false(_exists(SaveGame.SAVE_BASE_NAME), "world.save is moved aside")
	assert_true(_exists(SaveGame.BACKUP_NAME), "the backup stays where it is")
	var broken: PackedStringArray = _broken_files()
	assert_eq(broken.size(), 1, "one broken save is kept")
	if broken.size() == 1:
		assert_eq(slot.broken_path, _path(broken[0]), "the load says where")
		assert_true(Global.is_regex_match(broken[0], r"^world\.broken\.\d{8}T\d{6}Z\.save$"),
			"named with the UTC time (D-123): %s" % broken[0])
		assert_true(_bytes(broken[0]) == broken_bytes, "kept exactly as it was")
	slot.loaded.free_world()


func test_a_save_from_a_newer_version_is_kept_and_the_backup_loads() -> void:
	_assert_refused_save_falls_back(_newer_save, "newer than this build's")


func test_a_truncated_save_is_kept_and_the_backup_loads() -> void:
	_assert_refused_save_falls_back(_truncated_save, "cut short")


func test_an_unreadable_save_is_kept_and_the_backup_loads() -> void:
	_assert_refused_save_falls_back(_unreadable_save, "unreadable")


# A crash between a write's two renames leaves a backup and no save.
func test_a_backup_with_no_save_loads_the_backup() -> void:
	_good_save(SaveGame.BACKUP_NAME, BACKUP_SEED)
	var slot: SaveGame.SlotLoad = SaveGame.load_slot(TEST_SLOT)
	assert_eq(slot.source, SaveGame.SOURCE.BACKUP, "a fallback, never a new game")
	assert_eq(_seed_of(slot), BACKUP_SEED, "the backup's world")
	assert_eq(slot.refusals, [] as Array[String], "nothing was refused")
	assert_eq(slot.broken_path, "", "nothing to move aside")
	assert_true(_exists(SaveGame.BACKUP_NAME), "the backup stays where it is")
	slot.loaded.free_world()


func test_with_both_refused_nothing_loads_and_both_files_are_left_alone() -> void:
	_truncated_save(SaveGame.SAVE_BASE_NAME)
	_newer_save(SaveGame.BACKUP_NAME)
	var save_bytes: PackedByteArray = _bytes(SaveGame.SAVE_BASE_NAME)
	var backup_bytes: PackedByteArray = _bytes(SaveGame.BACKUP_NAME)
	var before: int = _orphans()

	var slot: SaveGame.SlotLoad = SaveGame.load_slot(TEST_SLOT)
	assert_eq(slot.source, SaveGame.SOURCE.REFUSED, "refused")
	assert_null(slot.loaded, "no world")
	assert_eq(_orphans(), before, "and none left orphaned")
	assert_eq(slot.refusals.size(), 2, "both files refused")
	if slot.refusals.size() == 2:
		assert_string_contains(slot.refusals[0], _path(SaveGame.SAVE_BASE_NAME))
		assert_string_contains(slot.refusals[0], "cut short")
		assert_string_contains(slot.refusals[1], _path(SaveGame.BACKUP_NAME))
		assert_string_contains(slot.refusals[1], "newer than this build's")
	assert_true(_bytes(SaveGame.SAVE_BASE_NAME) == save_bytes, "world.save untouched")
	assert_true(_bytes(SaveGame.BACKUP_NAME) == backup_bytes, "the backup untouched")
	assert_eq(_broken_files(), PackedStringArray(), "nothing moved aside")


func test_a_refused_save_with_no_backup_is_refused_never_new() -> void:
	_unreadable_save(SaveGame.SAVE_BASE_NAME)
	var slot: SaveGame.SlotLoad = SaveGame.load_slot(TEST_SLOT)
	assert_eq(slot.source, SaveGame.SOURCE.REFUSED, "not a new game over it")
	assert_true(_exists(SaveGame.SAVE_BASE_NAME), "and the file stays")


func test_a_second_broken_save_in_the_same_second_never_overwrites_the_first() -> void:
	_unreadable_save("a.save")
	_unreadable_save("b.save")
	var first: String = SaveGame.move_aside(_path("a.save"), "broken", 1793569749)
	var second: String = SaveGame.move_aside(_path("b.save"), "broken", 1793569749)
	assert_eq(first, _path("world.broken.20261101T214909Z.save"), "the first takes the name")
	assert_eq(second, _path("world.broken.20261101T214909Z-2.save"),
		"the second gets a counter")


func test_moving_aside_with_no_label_names_it_world_and_the_time() -> void:
	_unreadable_save("a.save")
	assert_eq(SaveGame.move_aside(_path("a.save"), "", 1793569749),
		_path("world.20261101T214909Z.save"), "for a new game's old save (D-111)")


func test_a_file_timestamp_is_utc_in_iso_basic_format() -> void:
	assert_eq(SaveGame.file_timestamp(1793569749), "20261101T214909Z", "D-123")
	assert_eq(SaveGame.file_timestamp(0), "19700101T000000Z", "zero padded")


# --- pruning kept saves (D-134) ---

func _touch(file: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_SLOT)
	var f: FileAccess = FileAccess.open(_path(file), FileAccess.WRITE)
	f.store_string("kept")
	f.close()


func _kept_name(label: String, day: int, n: int = 1) -> String:
	var stem: String = "world.%s" % label if label else "world"
	var suffix: String = "-%d" % n if n > 1 else ""
	return "%s.202611%02dT120000Z%s.save" % [stem, day, suffix]


func _kept_files() -> Array:
	var files: Array = Array(DirAccess.get_files_at(TEST_SLOT))
	files.sort()
	return files


func test_each_kind_keeps_its_own_count_newest_first() -> void:
	for label: String in ["", "backup", "broken"]:
		for day: int in [1, 2, 3, 4]:
			_touch(_kept_name(label, day))
	var keep: Dictionary[SaveGame.KEPT_KIND, int] = {
		SaveGame.KEPT_KIND.OLD_WORLD: 1,
		SaveGame.KEPT_KIND.OLD_BACKUP: 2,
		SaveGame.KEPT_KIND.BROKEN: 3,
	}
	var deleted: Array[String] = SaveGame.prune_kept(TEST_SLOT, keep)
	assert_eq(deleted.size(), 3 + 2 + 1, "the older ones past each kind's count")
	var expected: Array = [
		_kept_name("", 4),
		_kept_name("backup", 3), _kept_name("backup", 4),
		_kept_name("broken", 2), _kept_name("broken", 3), _kept_name("broken", 4),
	]
	expected.sort()
	assert_eq(_kept_files(), expected, "the newest of each kind, by its own count")


func test_pruning_never_touches_the_save_its_backup_or_other_files() -> void:
	var untouched: Array = [SaveGame.SAVE_BASE_NAME, SaveGame.BACKUP_NAME,
		SaveGame.SAVE_BASE_NAME + ".tmp", "notes.txt",
		"world.other.20261101T120000Z.save", "world.20261101T120000Z.save.bak"]
	for file: String in untouched:
		_touch(file)
	var keep: Dictionary[SaveGame.KEPT_KIND, int] = {
		SaveGame.KEPT_KIND.OLD_WORLD: 0,
		SaveGame.KEPT_KIND.OLD_BACKUP: 0,
		SaveGame.KEPT_KIND.BROKEN: 0,
	}
	assert_eq(SaveGame.prune_kept(TEST_SLOT, keep), [] as Array[String], "nothing pruned")
	untouched.sort()
	assert_eq(_kept_files(), untouched, "every file still there")


# Two moved aside in the same second get -2, -3, ... (D-123): -10 is
# newer than -2, so the order is numeric, not by the name's text.
func test_files_from_the_same_second_are_ordered_by_their_number() -> void:
	for n: int in [1, 2, 10]:
		_touch(_kept_name("broken", 5, n))
	var keep: Dictionary[SaveGame.KEPT_KIND, int] = {SaveGame.KEPT_KIND.BROKEN: 1}
	SaveGame.prune_kept(TEST_SLOT, keep)
	assert_eq(_kept_files(), [_kept_name("broken", 5, 10)], "the last one moved aside")


func test_a_kind_with_no_count_is_never_pruned() -> void:
	for day: int in [1, 2, 3, 4, 5]:
		_touch(_kept_name("broken", day))
	var keep: Dictionary[SaveGame.KEPT_KIND, int] = {SaveGame.KEPT_KIND.OLD_WORLD: 0}
	assert_eq(SaveGame.prune_kept(TEST_SLOT, keep), [] as Array[String], "none pruned")
	assert_eq(_kept_files().size(), 5, "all five broken saves kept")


func test_by_default_three_of_each_kind_are_kept() -> void:
	for kind: SaveGame.KEPT_KIND in SaveGame.KEPT_KIND.values():
		assert_eq(SaveGame.KEEP_PER_KIND.get(kind), 3, "%s" % SaveGame.KEPT_KIND.keys()[kind])


# Only the required keys refuse a save; the rest load as their
# defaults (D-121).
func test_a_save_with_optional_keys_missing_loads_them_as_their_defaults() -> void:
	_good_save(SaveGame.SAVE_BASE_NAME, SAVE_SEED)
	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	assert_true(loaded_game != null,
		"a save with no tuning profile, stats or local actor loads")
	var session: SaveSession = loaded_game.session
	assert_eq(loaded_game.header.tuning_profile_id, TuningProfile.DEFAULT_ID,
		"the tuning profile is the default")
	assert_eq(session.local_actor_id, -1, "no local actor: the game picks one (D-115)")
	assert_eq(session.active_play_time, -1.0, "no active clock: the timer keeps its count")
	assert_eq(session.total_play_time, -1.0, "nor total (D-120, D-131)")
	loaded_game.free_world()


# A load hands back the session a save took in (D-131).
func test_the_session_saved_is_the_session_loaded() -> void:
	var world: World = autofree(LevelGenerator.generate_world(5))
	var local: int = _player_on(_open_tile(world.level_at(1)), world, "Local", 10).actor_id
	var session: SaveSession = SaveSession.new(local, 12.0, 30.0)
	assert_eq(SaveGame.save_game(TEST_SLOT, world, session, TEST_ROOT),
		SaveGame.REFUSAL_REASON.NONE, "saved")
	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	if loaded_game == null:
		fail_test("the load was refused")
		return
	var back: SaveSession = loaded_game.session
	assert_eq(back.local_actor_id, local, "the local actor")
	assert_eq(loaded_game.header.tuning_profile_id, TuningProfile.DEFAULT_ID,
		"the world's profile")
	assert_eq(back.active_play_time, 12.0, "active play")
	assert_eq(back.total_play_time, 30.0, "total play")
	assert_eq(loaded_game.header.world_seed, 5, "the header's seed")
	assert_eq(loaded_game.header.format_version, SaveGame.FORMAT_VERSION, "and its version")
	loaded_game.free_world()


# Optional keys of the wrong type load as their defaults too (D-121).
func test_session_keys_of_the_wrong_type_load_as_their_defaults() -> void:
	var data: Dictionary = {"levels": _saved_levels(), "actors": {10: _actor_entry(0)}}
	data.merge(_required_header())
	data["local_actor_id"] = "ten"
	data["tuning_profile_id"] = 7
	data["stats"] = {"active_play_time": "long", "total_play_time": 30}
	_write_raw_save(data)
	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	if loaded_game == null:
		fail_test("the load was refused")
		return
	var session: SaveSession = loaded_game.session
	assert_eq(session.local_actor_id, -1, "the local actor")
	assert_eq(loaded_game.header.tuning_profile_id, TuningProfile.DEFAULT_ID, "the profile")
	assert_eq(session.active_play_time, -1.0, "a clock that isn't a number")
	assert_eq(session.total_play_time, 30.0, "an int clock reads as a float")
	loaded_game.free_world()


func test_a_save_missing_a_required_key_is_refused_saying_which() -> void:
	for key: String in SaveGame.REQUIRED_HEADER:
		var data: Dictionary = {"levels": _saved_levels(), "actors": {10: _actor_entry(0)}}
		data.merge(_required_header())
		data.erase(key)
		_write_raw_save(data)
		var refusals: Array[String] = []
		assert_null(SaveGame.load_file(_path(SaveGame.SAVE_BASE_NAME), refusals),
			"no %s, refused" % key)
		assert_eq(refusals.size(), 1, "with a reason")
		if refusals.size() == 1:
			assert_string_contains(refusals[0], "has no %s" % key)


# Older saves come up one step at a time; the first step is a no-op
# (world-runtime §7).
func test_a_version_0_save_is_migrated_and_loads() -> void:
	_good_save(SaveGame.SAVE_BASE_NAME, SAVE_SEED, 0)
	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	assert_true(loaded_game != null, "it loads")
	assert_eq(loaded_game.header.format_version, 0, "reporting the version it was saved in")
	loaded_game.free_world()


func test_a_version_with_no_migration_is_refused() -> void:
	_good_save(SaveGame.SAVE_BASE_NAME, SAVE_SEED, -1)
	var refusals: Array[String] = []
	assert_null(SaveGame.load_file(_path(SaveGame.SAVE_BASE_NAME), refusals), "refused")
	assert_eq(refusals.size(), 1, "with a reason")
	if refusals.size() == 1:
		assert_string_contains(refusals[0], "no migration")


# The header's version is the one checked: the body's copy can't make
# a newer save look loadable (R-B10).
func test_the_headers_version_wins_over_the_bodys() -> void:
	var data: Dictionary = {"levels": _saved_levels(), "actors": {10: _actor_entry(0)}}
	data.merge(_required_header())
	data["format_version"] = SaveGame.FORMAT_VERSION
	SaveGame._overwrite_data(SaveGame.FORMAT_VERSION + 1, data, _path(SaveGame.SAVE_BASE_NAME))
	var refusals: Array[String] = []
	assert_null(SaveGame.load_file(_path(SaveGame.SAVE_BASE_NAME), refusals),
		"refused as the newer version its header says")
	assert_eq(refusals.size(), 1, "with a reason")
	if refusals.size() == 1:
		assert_string_contains(refusals[0], "newer than this build's")


# --- a level built from the save, the layer list, the radius cap
# (R-P2, R-P8, R-P9) ---

# A level the save holds whole is built from it alone: no fixture ids
# drawn, no world spawn placed from the re-hashed seed (R-P2).
func test_a_whole_saved_level_is_built_without_generating() -> void:
	var saved: Dictionary = _level_data(0)
	saved["fixtures"] = []
	var levels: Dictionary = _deserialize({0: saved})
	assert_eq(levels[0].level_fixtures.all(), [] as Array[Fixture],
		"and no world spawn was placed: the saved list is all there is")
	assert_eq(levels[0].level_seed, TEST_SEED, "with the saved seed")


# One from before fixtures were saved is generated first, so it keeps
# the generated ones (C).
func test_a_saved_level_missing_its_fixtures_is_generated_first() -> void:
	var levels: Dictionary = _deserialize({0: _level_data(0)})
	assert_gt(levels[0].level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN).size(), 0,
		"the generated world spawn is kept")


func test_a_saved_level_missing_a_layer_is_generated_first() -> void:
	var saved: Dictionary = _level_data(0)
	saved["fixtures"] = []
	saved["tiles"].erase("ore")
	var levels: Dictionary = _deserialize({0: saved})
	assert_eq(levels[0].level_tiles.get_ore(0, 0), TileKind.ORE.NONE,
		"generated, so the missing ore layer is the prefab's, not all copper")


func test_the_highest_fixture_id_is_found_across_levels() -> void:
	var a: Level = _level(0)
	var b: Level = _level(1)
	a.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.WORLD_SPAWN, WorldPos.new(0, 0, 0), 7))
	b.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(1, 1, 1), 42))
	assert_eq(SaveGame.highest_fixture_id([a, b]), 42, "the highest of all levels")
	assert_eq(SaveGame.highest_fixture_id([] as Array[Level]), -1, "none at all")


# Exactly the layers the list names are saved, and read back (R-P8).
func test_the_saved_layers_are_exactly_the_shared_list() -> void:
	var saved: Dictionary = _serialize([_level(0)])
	var names: Array = saved[0]["tiles"].keys()
	names.sort()
	var expected: Array = SaveGame.TILE_LAYERS.duplicate()
	expected.sort()
	assert_eq(names, expected, "ground, top and ore")


func test_a_layer_not_in_the_list_is_not_read() -> void:
	var saved: Dictionary = _level_data(0)
	saved["tiles"]["light"] = _packed(_filled(_size(0), 1))
	var layers: Dictionary = SaveGame._deserialize_tile_layers(saved)
	assert_false(layers.has("light"), "unknown layers are ignored")


# An edited save can't ask for gigabytes (R-P9).
func test_deserialize_skips_a_radius_past_the_cap() -> void:
	var saved: Dictionary = _level_data(1)
	saved["bound"]["radius"] = SaveGame.MAX_SAVED_RADIUS + 1
	_assert_bad_level_skipped(saved, "radius past the cap")


func test_a_radius_at_the_cap_passes_the_check() -> void:
	var saved: Dictionary = _level_data(1)
	saved["bound"]["radius"] = SaveGame.MAX_SAVED_RADIUS
	saved.erase("tiles")
	assert_true(SaveGame._is_valid_level_entry(1, saved), "the cap itself is allowed")


func test_the_cap_is_past_every_recipe() -> void:
	for recipe: LevelRecipe in LevelRecipes.TABLE.rows:
		assert_lt(recipe.bound.radius, SaveGame.MAX_SAVED_RADIUS,
			"depth %d fits under the cap" % recipe.bound.depth)


# All or nothing: a save with a level that won't load is refused, not
# loaded without it (R-B3).
func test_a_save_with_a_level_that_wont_load_is_refused_naming_it() -> void:
	var levels: Dictionary = {0: _level_data(0), 1: _level_data(1)}
	levels[0]["fixtures"] = []
	levels[1]["fixtures"] = []
	levels[1]["level_seed"] = "not a seed"
	var data: Dictionary = {"levels": levels, "actors": {10: _actor_entry(0)}}
	data.merge(_required_header())
	_write_raw_save(data)
	var before: int = _orphans()
	var refusals: Array[String] = []
	assert_null(SaveGame.load_file(_path(SaveGame.SAVE_BASE_NAME), refusals), "refused")
	assert_eq(_orphans(), before, "and the level that did load is freed")
	assert_eq(refusals.size(), 1, "with a reason")
	if refusals.size() == 1:
		assert_string_contains(refusals[0], "couldn't be loaded: [1]")


func test_a_save_missing_a_level_falls_back_to_the_backup() -> void:
	var levels: Dictionary = {0: _level_data(0), 1: _level_data(1)}
	levels[1]["bound"]["depth"] = 2
	var data: Dictionary = {"levels": levels, "actors": {10: _actor_entry(0)}}
	data.merge(_required_header())
	_write_raw_save(data)
	_good_save(SaveGame.BACKUP_NAME, BACKUP_SEED)
	var slot: SaveGame.SlotLoad = SaveGame.load_slot(TEST_SLOT)
	assert_eq(slot.source, SaveGame.SOURCE.BACKUP, "the backup loads instead")
	assert_eq(_seed_of(slot), BACKUP_SEED, "the backup's world")
	slot.loaded.free_world()


# --- a whole World saved and loaded (slice 004 section D) ---

# A generated world with a player on the Surface's open floor.
func _world_with_player() -> World:
	var world: World = autofree(LevelGenerator.generate_world(TEST_SEED))
	_player_on(_open_tile(world.level_at(0)), world, "Saver")
	return world


func test_the_header_holds_the_worlds_counters() -> void:
	var world: World = _world_with_player()
	world.fixture_ids.restore(40)
	world.actor_ids.restore(9)
	assert_eq(_save_world(world), SaveGame.REFUSAL_REASON.NONE, "saved")
	var data: Dictionary = _read(SaveGame.SAVE_BASE_NAME)
	assert_eq(data.get("next_fixture_id"), 40, "the next fixture id (D-130)")
	assert_eq(data.get("next_actor_id"), 9, "and the next actor id")
	assert_eq(_read_header(SaveGame.SAVE_BASE_NAME).format_version, 1,
		"with no format version bump while version 1 is unsettled")


func test_the_session_names_the_local_actor_and_the_rest() -> void:
	var world: World = _world_with_player()
	var session: SaveSession = SaveSession.new(world.players()[0].actor_id, 12.0, 30.0)
	SaveGame.save_game(TEST_SLOT, world, session, TEST_ROOT)
	var data: Dictionary = _read(SaveGame.SAVE_BASE_NAME)
	assert_eq(data.get("local_actor_id"), world.players()[0].actor_id, "the local actor")
	assert_eq(data.get("tuning_profile_id"), world.tuning.id, "the world's tuning profile")
	assert_eq(data.get("stats"), {"active_play_time": 12.0, "total_play_time": 30.0}, "the clocks")


func test_a_session_with_no_local_actor_writes_none() -> void:
	var world: World = _world_with_player()
	_save_world(world, -1)
	assert_false(_read(SaveGame.SAVE_BASE_NAME).has("local_actor_id"), "the game picks one on load")


func test_a_load_returns_a_world_outside_the_tree_with_its_levels_and_actors() -> void:
	var world: World = _world_with_player()
	_save_world(world)
	var slot: SaveGame.SlotLoad = SaveGame.load_slot(TEST_SLOT)
	var loaded: World = slot.world
	assert_not_null(loaded, "the slot result holds the world (D-127)")
	if loaded == null: return
	assert_false(loaded.is_inside_tree(), "built outside the tree")
	assert_eq(loaded.world_seed, TEST_SEED, "with its seed")
	assert_eq(loaded.levels().size(), world.levels().size(), "every level")
	for level: Level in loaded.levels():
		assert_eq(level.world, loaded, "each knowing its world (D-126)")
	assert_eq(loaded.players().size(), 1, "and its actor, already in it (D-128)")
	slot.loaded.free_world()


# The counters come back from the header, then move past every id the
# load brought back (D-130).
func test_saved_counters_are_restored() -> void:
	var world: World = _world_with_player()
	world.fixture_ids.restore(40)
	world.actor_ids.restore(9)
	_save_world(world)
	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	assert_eq(loaded_game.world.fixture_ids.peek(), 40, "the fixture counter carries on")
	assert_eq(loaded_game.world.actor_ids.peek(), 9, "and the actor counter")
	loaded_game.free_world()


func test_a_stale_counter_is_moved_past_every_loaded_id() -> void:
	var world: World = _world_with_player()
	var data: Dictionary = SaveGame._serialize_all(world, SaveSession.new())
	data["next_fixture_id"] = 1
	data["next_actor_id"] = 1
	SaveGame._overwrite_data(SaveGame.FORMAT_VERSION, data, _path(SaveGame.SAVE_BASE_NAME))
	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	var loaded: World = loaded_game.world
	assert_gt(loaded.fixture_ids.peek(), SaveGame.highest_fixture_id(loaded.levels()),
		"a hand-edited fixture counter can't hand out an id in use")
	assert_gt(loaded.actor_ids.peek(), loaded.players()[0].actor_id,
		"nor can the actor counter (trap 6)")
	loaded_game.free_world()


# A save from slice 003 has no counters: they come from the ids alone.
func test_a_save_with_no_counters_gets_them_from_the_ids() -> void:
	var world: World = _world_with_player()
	var data: Dictionary = SaveGame._serialize_all(world, SaveSession.new())
	data.erase("next_fixture_id")
	data.erase("next_actor_id")
	SaveGame._overwrite_data(SaveGame.FORMAT_VERSION, data, _path(SaveGame.SAVE_BASE_NAME))
	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	var loaded: World = loaded_game.world
	assert_eq(loaded.fixture_ids.peek(), SaveGame.highest_fixture_id(loaded.levels()) + 1,
		"the next fixture id is just past the highest loaded")
	assert_eq(loaded.actor_ids.peek(), loaded.players()[0].actor_id + 1,
		"and the next actor id just past the loaded actor's")
	loaded_game.free_world()


func test_a_counter_that_isnt_an_int_loads_as_missing() -> void:
	var world: World = _world_with_player()
	var data: Dictionary = SaveGame._serialize_all(world, SaveSession.new())
	data["next_actor_id"] = "nine"
	SaveGame._overwrite_data(SaveGame.FORMAT_VERSION, data, _path(SaveGame.SAVE_BASE_NAME))
	var loaded_game: SaveGame.LoadedGame = SaveGame.load_game(TEST_SLOT)
	assert_eq(loaded_game.world.actor_ids.peek(), loaded_game.world.players()[0].actor_id + 1,
		"from the ids, as if it weren't there")
	loaded_game.free_world()


# A level the save holds whole, saved with a radius the recipe doesn't
# have, comes back at the saved radius (D-112, R-B4).
func test_a_level_saved_with_another_radius_loads_with_that_radius() -> void:
	var saved: Dictionary = _level_data(1)
	var radius: int = _radius(1) + 5
	var width: int = 2 * radius + 1
	saved["bound"]["radius"] = radius
	saved["fixtures"] = []
	for layer: String in ["ground", "top", "ore"]:
		saved["tiles"][layer] = _packed(_filled(width * width, 0))
	var levels: Dictionary = _deserialize({1: saved})
	assert_true(levels.has(1), "the level loads")
	if not levels.has(1): return
	assert_eq(levels[1].level_tiles.level_bound.radius, radius, "at the saved radius")
	assert_eq(levels[1].level_tiles.level_bound.name, LevelRecipes.TABLE.get_bounds(1).name,
		"keeping the recipe's name")


# The same for a level the save holds only in part: it's generated to
# the saved bound, so the saved layers still fit.
func test_a_partial_level_saved_with_another_radius_is_generated_to_it() -> void:
	var saved: Dictionary = _level_data(1)
	var radius: int = _radius(1) + 5
	var width: int = 2 * radius + 1
	saved["bound"]["radius"] = radius
	saved["tiles"] = {"top": _packed(_filled(width * width, TileKind.TOP.OPEN))}
	var levels: Dictionary = _deserialize({1: saved})
	assert_true(levels.has(1), "the level loads")
	if not levels.has(1): return
	assert_eq(levels[1].level_tiles.level_bound.radius, radius, "at the saved radius")


# A level generated because the save holds it in part draws fixture
# ids; every saved id is claimed first, so none collides.
func test_a_generated_level_never_takes_a_saved_fixture_id() -> void:
	var levels_data: Dictionary = _saved_levels()
	# The Surface, with no fixtures entry, is generated: its world spawn
	# draws an id
	levels_data[0].erase("fixtures")
	var deeper: Dictionary = _level_data(1)
	deeper["fixtures"] = [_fixture_entry(ObjectKind.OBJECT.WORLD_SPAWN, 0, 0, 1)]
	levels_data[1] = deeper
	var world: World = _loaded_world(levels_data)
	var spawns: Array[Fixture] = world.level_at(0).level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN)
	assert_eq(spawns.size(), 1, "the Surface's generated spawn")
	if spawns.size() == 1:
		assert_gt(spawns[0].id, 1, "takes an id past the saved one")


# Refused after levels were built (no actor could be placed): the one
# world built is freed, and nothing else (D-127).
func test_a_load_refused_after_building_leaves_no_orphans() -> void:
	_write_save({"levels": _saved_levels(), "actors": {10: _actor_entry(5)}})
	var before: int = _orphans()
	var refusals: Array[String] = []
	assert_null(SaveGame.load_file(_path(SaveGame.SAVE_BASE_NAME), refusals), "refused")
	assert_push_warning("didn't load")
	assert_eq(refusals.size(), 1, "with a reason")
	if refusals.size() == 1:
		assert_string_contains(refusals[0], "no actor that could be placed")
	assert_eq(_orphans(), before, "no orphan nodes (outcome 7)")
