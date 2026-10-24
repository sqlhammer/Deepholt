extends GutTest

# LevelTiles — flat per-layer byte arrays holding a level's tile truth (D-048), with a third
# array for ore (D-054), sized to the square around a level's radial bounds and indexed by
# (x, y) from the level's origin. Reads outside the array or outside the radial disc return
# reserved sentinels rather than an ordinary kind (D-057, D-059).


func test_write_and_read_ground() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 64)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	tiles.set_ground(1, -1, TileKind.GROUND.ROCK)
	assert_eq(tiles.get_ground(1, -1), TileKind.GROUND.ROCK,
		"ground tile should read back what was written")


func test_write_and_read_top() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 64)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	tiles.set_top(1, -1, TileKind.TOP.MINABLE_ROCK)
	assert_eq(tiles.get_top(1, -1), TileKind.TOP.MINABLE_ROCK,
		"top tile should read back what was written")


func test_write_and_read_ore() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 64)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	tiles.set_ore(1, -1, TileKind.ORE.COPPER)
	assert_eq(tiles.get_ore(1, -1), TileKind.ORE.COPPER,
		"ore tile should read back what was written")


func test_writing_one_layer_does_not_affect_another() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 64)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	tiles.set_top(1, 1, TileKind.TOP.MINABLE_ROCK)
	assert_eq(tiles.get_ore(0, 0), TileKind.ORE.NONE,
		"writing the top layer should not leak into the ore layer at the same coordinate")


func test_read_past_positive_x_edge_is_out_of_array() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 64)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	assert_eq(tiles.get_ground(65, 0), TileKind.SENTINEL_OUT_OF_ARRAY,
		"x = radius + 1 is past the array's edge")


func test_read_past_negative_x_edge_is_out_of_array() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 64)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	assert_eq(tiles.get_ground(-65, 0), TileKind.SENTINEL_OUT_OF_ARRAY,
		"x = -(radius + 1) is past the array's edge")


func test_read_past_positive_y_edge_is_out_of_array() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 64)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	assert_eq(tiles.get_ground(0, 65), TileKind.SENTINEL_OUT_OF_ARRAY,
		"y = radius + 1 is past the array's edge")


func test_read_past_negative_y_edge_is_out_of_array() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 64)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	assert_eq(tiles.get_ground(0, -65), TileKind.SENTINEL_OUT_OF_ARRAY,
		"y = -(radius + 1) is past the array's edge")


func test_read_in_square_corner_outside_disc_is_out_of_bounds() -> void:
	# Level -1 has a radius of 64. This covers -64 to 64 but (64,64) is 90.50966
	# which is outside of our circular boundary.
	var level_bounds = LevelBound.new(1, "Unit Test", 64)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	assert_eq(tiles.get_ground(64, 64), TileKind.SENTINEL_OUT_OF_BOUNDS,
		"a square corner outside the radius should read as out-of-bounds, not out-of-array")


func test_sentinels_apply_to_every_layer() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 64)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	assert_eq(tiles.get_top(65, 0), TileKind.SENTINEL_OUT_OF_ARRAY,
		"the top layer should also sentinel out-of-array reads")
	assert_eq(tiles.get_ore(65, 0), TileKind.SENTINEL_OUT_OF_ARRAY,
		"the ore layer should also sentinel out-of-array reads")
	assert_eq(tiles.get_top(64, 64), TileKind.SENTINEL_OUT_OF_BOUNDS,
		"the top layer should also sentinel out-of-bounds reads")
	assert_eq(tiles.get_ore(64, 64), TileKind.SENTINEL_OUT_OF_BOUNDS,
		"the ore layer should also sentinel out-of-bounds reads")


func test_out_of_array_and_out_of_bounds_sentinels_are_distinguishable() -> void:
	assert_ne(TileKind.SENTINEL_OUT_OF_ARRAY, TileKind.SENTINEL_OUT_OF_BOUNDS,
		"the two sentinels must not collide")


# --- is_diggable ---

func test_minable_kinds_are_minable() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_recipes.get_bounds(0))
	tiles.set_top(1, 0, TileKind.TOP.MINABLE_ROCK)
	tiles.set_top(2, 0, TileKind.TOP.MINABLE_DIRT)
	assert_true(tiles.is_diggable(WorldPos.new(1, 0, 0)), "rock is minable")
	assert_true(tiles.is_diggable(WorldPos.new(2, 0, 0)), "dirt is minable")


func test_open_floor_is_not_minable() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_recipes.get_bounds(0))
	tiles.set_top(1, 0, TileKind.TOP.OPEN)
	assert_false(tiles.is_diggable(WorldPos.new(1, 0, 0)), "open floor isn't")


func test_outside_the_level_is_not_minable() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_recipes.get_bounds(0))
	assert_false(tiles.is_diggable(WorldPos.new(90, 1, 0)),
		"outside the radial bounds (254) isn't")
	assert_false(tiles.is_diggable(WorldPos.new(91, 0, 0)),
		"past the array (255) isn't")


# --- the change notification (D-065) ---

# Every write that changes a tile announces it from the tile data
# itself, naming the tile and the layer, so a renderer (or anything
# else mirroring tile data) hears about every writer without any of
# them knowing it exists.

func _surface() -> LevelTiles:
	return LevelTiles.new(World.level_recipes.get_bounds(0))


func test_changing_a_top_tile_announces_it_once() -> void:
	var tiles: LevelTiles = _surface()
	watch_signals(tiles)
	tiles.set_top(3, -2, TileKind.TOP.OPEN)
	assert_signal_emit_count(tiles, "tile_changed", 1, "one write, one notice")
	assert_eq(get_signal_parameters(tiles, "tile_changed"),
		[3, -2, LevelTiles.LAYER.TOP, tiles],
		"naming the tile, the top layer, and the tiles it came from")


func test_each_layer_names_itself() -> void:
	var tiles: LevelTiles = _surface()
	watch_signals(tiles)
	tiles.set_ground(1, 0, TileKind.GROUND.DIRT)
	assert_eq(get_signal_parameters(tiles, "tile_changed", 0)[2], LevelTiles.LAYER.GROUND,
		"a ground write says ground")
	tiles.set_ore(1, 0, TileKind.ORE.COPPER)
	assert_eq(get_signal_parameters(tiles, "tile_changed", 1)[2], LevelTiles.LAYER.ORE,
		"an ore write says ore")


func test_writing_the_same_value_announces_nothing() -> void:
	var tiles: LevelTiles = _surface()
	watch_signals(tiles)
	tiles.set_top(1, 0, TileKind.TOP.MINABLE_ROCK)
	tiles.set_ground(1, 0, TileKind.GROUND.ROCK)
	tiles.set_ore(1, 0, TileKind.ORE.NONE)
	assert_signal_not_emitted(tiles, "tile_changed",
		"rewriting what's already there isn't a change")


func test_writes_outside_the_level_announce_nothing() -> void:
	var tiles: LevelTiles = _surface()
	watch_signals(tiles)
	tiles.set_top(90, 1, TileKind.TOP.OPEN)
	tiles.set_top(91, 0, TileKind.TOP.OPEN)
	assert_signal_not_emitted(tiles, "tile_changed",
		"outside the radial bounds (254) and past the array (255) nothing is written")


# A listener re-reads the tile when it hears about it, so the new
# value must already be in place.
func test_the_new_value_is_in_place_when_the_notice_arrives() -> void:
	var tiles: LevelTiles = _surface()
	var seen: Array = []
	tiles.tile_changed.connect(func(x: int, y: int, _layer: int, _source: LevelTiles) -> void:
		seen.append(tiles.get_top(x, y)))
	tiles.set_top(1, 0, TileKind.TOP.OPEN)
	assert_eq(seen, [TileKind.TOP.OPEN], "the listener reads the new kind, not the old one")


func test_changing_a_tile_back_announces_both_changes() -> void:
	var tiles: LevelTiles = _surface()
	watch_signals(tiles)
	tiles.set_top(1, 0, TileKind.TOP.OPEN)
	tiles.set_top(1, 0, TileKind.TOP.MINABLE_ROCK)
	assert_signal_emit_count(tiles, "tile_changed", 2, "open, then rock again")


# bypass_signals writes the tile but tells no one: anything mirroring
# tile data (the renderer) will not see the change. For writes that
# happen before anything is listening.
func test_a_bypassed_write_changes_the_tile_silently() -> void:
	var tiles: LevelTiles = _surface()
	watch_signals(tiles)
	tiles.set_top(1, 0, TileKind.TOP.OPEN, true)
	assert_eq(tiles.get_top(1, 0), TileKind.TOP.OPEN, "the tile changed")
	assert_signal_not_emitted(tiles, "tile_changed", "and nothing was announced")


# Trap 6 of the dig lesson: writing an array directly skips the
# notification, so the screen never hears of it. The arrays are
# guarded, and replacing one warns.
func test_replacing_a_layer_array_warns() -> void:
	var tiles: LevelTiles = _surface()
	tiles.top = tiles.top
	assert_push_warning("Use set_top() to modify individual elements.",
		"go through set_top so the change is announced")


# A level's bounds come from its own shape, not from looking its
# depth up in World: tile storage knows its shape and nothing about
# how it was generated (D-085).
func test_bounds_come_from_the_tiles_own_shape() -> void:
	# Depth 1 is radius 64 in the recipes; this shape says 3.
	var tiles: LevelTiles = LevelTiles.new(LevelBound.new(1, "Unit Test", 3))
	assert_eq(tiles.get_top(3, 0), TileKind.TOP.MINABLE_ROCK, "(3, 0) is inside radius 3")
	assert_eq(tiles.get_top(2, 3), TileKind.SENTINEL_OUT_OF_BOUNDS,
		"(2, 3) is outside radius 3, though well inside 64")


# The disc a level reads is the one World.is_in_bounds describes,
# tile for tile, at every real depth's radius.
func test_the_disc_matches_world_is_in_bounds() -> void:
	for depth in [0, 1, 2, 6]:
		var tiles: LevelTiles = LevelTiles.new(World.level_recipes.get_bounds(depth))
		var radius: int = tiles.level_bound.radius
		var mismatches: int = 0
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var outside: bool = tiles.get_top(x, y) == TileKind.SENTINEL_OUT_OF_BOUNDS
				if outside == World.is_in_bounds(WorldPos.new(x, y, depth)):
					mismatches += 1
		assert_eq(mismatches, 0, "depth %d's disc matches World's" % depth)


# --- bulk_load_tile_arrays: a load replaces whole layers at once ---
# A load needs its own path: the public setters warn, and the per-tile
# set_* functions emit tile_changed once per tile (slice 003 trap 5).
# Layers come by name; a missing layer keeps its default, and a layer
# that is present but the wrong size refuses the whole load (D-112).

const BULK_RADIUS: int = 3


func _bulk_tiles() -> LevelTiles:
	return LevelTiles.new(LevelBound.new(1, "Unit Test", BULK_RADIUS))


func _bulk_size() -> int:
	var width: int = 2 * BULK_RADIUS + 1
	return width * width


func _filled(size: int, kind: int) -> PackedByteArray:
	var bytes: PackedByteArray = []
	bytes.resize(size)
	bytes.fill(kind)
	return bytes


# Every byte different from its neighbor, so a match means every
# position matched, not just the count of each value.
func _patterned(size: int, offset: int) -> PackedByteArray:
	var bytes: PackedByteArray = []
	bytes.resize(size)
	for i in size:
		bytes[i] = (i + offset) % 200
	return bytes


func _layers() -> Dictionary:
	return {
		"ground": _filled(_bulk_size(), TileKind.GROUND.DIRT),
		"top": _filled(_bulk_size(), TileKind.TOP.OPEN),
		"ore": _filled(_bulk_size(), TileKind.ORE.COPPER),
	}


func test_bulk_load_takes_every_layer_byte_for_byte() -> void:
	var tiles: LevelTiles = _bulk_tiles()
	var ground: PackedByteArray = _patterned(_bulk_size(), 0)
	var top: PackedByteArray = _patterned(_bulk_size(), 1)
	var ore: PackedByteArray = _patterned(_bulk_size(), 2)
	var result: LevelTiles.REFUSAL_REASON = tiles.bulk_load_tile_arrays(
		{"ground": ground, "top": top, "ore": ore})
	assert_eq(result, LevelTiles.REFUSAL_REASON.NONE, "a well-sized load is taken")
	assert_eq(tiles.ground, ground, "ground is byte-identical")
	assert_eq(tiles.top, top, "top is byte-identical")
	assert_eq(tiles.ore, ore, "ore is byte-identical")


# The corners of the square outside the disc are in the arrays too,
# so a byte-identical load includes them.
func test_bulk_load_reads_back_through_the_getters() -> void:
	var tiles: LevelTiles = _bulk_tiles()
	tiles.bulk_load_tile_arrays(_layers())
	assert_eq(tiles.get_ground(0, 0), TileKind.GROUND.DIRT, "ground read")
	assert_eq(tiles.get_top(1, -1), TileKind.TOP.OPEN, "top read")
	assert_eq(tiles.get_ore(-1, 2), TileKind.ORE.COPPER, "ore read")
	assert_eq(tiles.get_top(BULK_RADIUS, BULK_RADIUS), TileKind.SENTINEL_OUT_OF_BOUNDS,
		"a loaded corner still reads as outside the disc")


func test_bulk_load_emits_no_tile_changed() -> void:
	var tiles: LevelTiles = _bulk_tiles()
	watch_signals(tiles)
	tiles.bulk_load_tile_arrays(_layers())
	assert_signal_emit_count(tiles, "tile_changed", 0,
		"a load is not a tile-by-tile change")


func test_bulk_load_announces_tiles_replaced_once() -> void:
	var tiles: LevelTiles = _bulk_tiles()
	watch_signals(tiles)
	tiles.bulk_load_tile_arrays(_layers())
	assert_signal_emit_count(tiles, "tiles_replaced", 1, "one announcement per load")
	# The announcement names the tiles that changed.
	assert_signal_emitted_with_parameters(tiles, "tiles_replaced", [tiles])


func test_bulk_load_trips_no_setter_warning() -> void:
	var tiles: LevelTiles = _bulk_tiles()
	tiles.bulk_load_tile_arrays(_layers())
	assert_push_warning_count(0, "a load must not go through the warning setters")


func test_bulk_load_keeps_the_level_bound() -> void:
	var tiles: LevelTiles = _bulk_tiles()
	var bound: LevelBound = tiles.level_bound
	tiles.bulk_load_tile_arrays(_layers())
	assert_same(tiles.level_bound, bound, "a load replaces tiles, not the shape")


func test_bulk_load_missing_layer_keeps_its_default() -> void:
	var tiles: LevelTiles = _bulk_tiles()
	var default_ore: PackedByteArray = tiles.ore
	var layers: Dictionary = _layers()
	layers.erase("ore")
	var result: LevelTiles.REFUSAL_REASON = tiles.bulk_load_tile_arrays(layers)
	assert_eq(result, LevelTiles.REFUSAL_REASON.NONE,
		"an older save without a layer is not broken")
	assert_eq(tiles.ore, default_ore, "the missing layer keeps its default")
	assert_eq(tiles.ground, layers["ground"], "the present layers are still taken")
	assert_eq(tiles.top, layers["top"], "the present layers are still taken")


func test_bulk_load_with_no_layers_changes_nothing() -> void:
	var tiles: LevelTiles = _bulk_tiles()
	var ground: PackedByteArray = tiles.ground
	var top: PackedByteArray = tiles.top
	var ore: PackedByteArray = tiles.ore
	var result: LevelTiles.REFUSAL_REASON = tiles.bulk_load_tile_arrays({})
	assert_eq(result, LevelTiles.REFUSAL_REASON.NONE, "every layer missing is not an error")
	assert_eq(tiles.ground, ground, "ground kept")
	assert_eq(tiles.top, top, "top kept")
	assert_eq(tiles.ore, ore, "ore kept")


# A refused load must leave the level exactly as it was: taking
# ground and top and then refusing ore would leave it half old and
# half new.
func _assert_refused_and_untouched(layers: Dictionary, why: String) -> void:
	var tiles: LevelTiles = _bulk_tiles()
	var ground: PackedByteArray = tiles.ground
	var top: PackedByteArray = tiles.top
	var ore: PackedByteArray = tiles.ore
	watch_signals(tiles)
	var result: LevelTiles.REFUSAL_REASON = tiles.bulk_load_tile_arrays(layers)
	assert_eq(result, LevelTiles.REFUSAL_REASON.LAYER_SIZE_MISMATCH, why)
	assert_eq(tiles.ground, ground, "%s: ground untouched" % why)
	assert_eq(tiles.top, top, "%s: top untouched" % why)
	assert_eq(tiles.ore, ore, "%s: ore untouched" % why)
	assert_signal_emit_count(tiles, "tiles_replaced", 0,
		"%s: a refused load announces nothing" % why)


func test_bulk_load_refuses_a_short_layer() -> void:
	var layers: Dictionary = _layers()
	layers["ore"] = _filled(_bulk_size() - 1, TileKind.ORE.COPPER)
	_assert_refused_and_untouched(layers, "ore one byte short")


func test_bulk_load_refuses_a_long_layer() -> void:
	var layers: Dictionary = _layers()
	layers["ground"] = _filled(_bulk_size() + 1, TileKind.GROUND.DIRT)
	_assert_refused_and_untouched(layers, "ground one byte long")


# Present but empty is a broken save, not a missing layer: the check
# is whether the key exists, not whether the array has anything in it.
func test_bulk_load_refuses_a_present_but_empty_layer() -> void:
	var layers: Dictionary = _layers()
	layers["top"] = PackedByteArray()
	_assert_refused_and_untouched(layers, "top present but empty")


func test_bulk_load_refuses_a_layer_sized_for_another_bound() -> void:
	var layers: Dictionary = _layers()
	var width: int = 2 * (BULK_RADIUS + 1) + 1
	layers["ground"] = _filled(width * width, TileKind.GROUND.DIRT)
	layers["top"] = _filled(width * width, TileKind.TOP.OPEN)
	layers["ore"] = _filled(width * width, TileKind.ORE.COPPER)
	_assert_refused_and_untouched(layers, "every layer sized for radius + 1")


# Packed arrays are copy-on-write: a dig after a load must not reach
# back into the data the level was loaded from.
func test_digging_after_a_load_leaves_the_loaded_data_alone() -> void:
	var tiles: LevelTiles = _bulk_tiles()
	var layers: Dictionary = _layers()
	var top_before: PackedByteArray = layers["top"].duplicate()
	tiles.bulk_load_tile_arrays(layers)
	tiles.set_top(0, 0, TileKind.TOP.MINABLE_ROCK)
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.MINABLE_ROCK, "the dig landed")
	assert_eq(layers["top"], top_before, "the loaded data is unchanged")























