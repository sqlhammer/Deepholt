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
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[0])
	tiles.set_top(1, 0, TileKind.TOP.MINABLE_ROCK)
	tiles.set_top(2, 0, TileKind.TOP.MINABLE_DIRT)
	assert_true(tiles.is_diggable(WorldPos.new(1, 0, 0)), "rock is minable")
	assert_true(tiles.is_diggable(WorldPos.new(2, 0, 0)), "dirt is minable")


func test_open_floor_is_not_minable() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[0])
	tiles.set_top(1, 0, TileKind.TOP.OPEN)
	assert_false(tiles.is_diggable(WorldPos.new(1, 0, 0)), "open floor isn't")


func test_outside_the_level_is_not_minable() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[0])
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
	return LevelTiles.new(World.level_bounds.rows[0])


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
