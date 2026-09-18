extends GutTest

# LevelGridLoader -- stamps an authored TilePrefab's three per-layer text grids
# into a LevelTiles, with each grid's own anchor marker landing on the anchor
# coordinate given (D-060). Malformed grids are a hard, all-or-nothing failure
# (D-055); a grid that merely says nothing about a tile is not malformed, and
# that tile keeps the level's default (D-062). Ore may only sit inside minable
# rock (D-056).
#
# Grid layout used by the success tests, marker '0' at the center:
#   ground        top           ore
#   rrr           .#.           ...
#   r0r           #0#           .0c
#   rrr           .#.           ...
# so north/south/west/east of the anchor are all minable rock, the diagonals
# are open, and the east tile alone carries copper.


func _stamp(tiles: LevelTiles, ground: String, top: String, ore: String, anchor: Vector2i = Vector2i.ZERO) -> bool:
	var prefab: TilePrefab = TilePrefab.from_grids(&"test_prefab", ground, top, ore)
	return LevelGridLoader.stamp(tiles, prefab, anchor)


func test_small_grid_loads_and_spot_checks_all_four_sides_of_anchor() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles,
		"rrr\nr0r\nrrr",
		".#.\n#0#\n.#.",
		"...\n.0c\n...")

	assert_true(ok, "a well-formed grid set should load")
	assert_eq(tiles.get_ground(0, 0), TileKind.GROUND.ROCK, "the anchor's ground is rock")
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.OPEN, "the anchor's top is open")
	assert_eq(tiles.get_ore(0, 0), TileKind.ORE.NONE, "the anchor carries no ore")

	assert_eq(tiles.get_top(0, -1), TileKind.TOP.MINABLE_ROCK, "north of the anchor is minable rock")
	assert_eq(tiles.get_top(0, 1), TileKind.TOP.MINABLE_ROCK, "south of the anchor is minable rock")
	assert_eq(tiles.get_top(-1, 0), TileKind.TOP.MINABLE_ROCK, "west of the anchor is minable rock")
	assert_eq(tiles.get_top(1, 0), TileKind.TOP.MINABLE_ROCK, "east of the anchor is minable rock")

	assert_eq(tiles.get_ore(1, 0), TileKind.ORE.COPPER, "east of the anchor carries the copper")
	assert_eq(tiles.get_ore(0, -1), TileKind.ORE.NONE, "north of the anchor carries no ore")
	assert_eq(tiles.get_ore(0, 1), TileKind.ORE.NONE, "south of the anchor carries no ore")
	assert_eq(tiles.get_ore(-1, 0), TileKind.ORE.NONE, "west of the anchor carries no ore")


# The whole point of the prefab: the same grids stamp anywhere, and the marker
# lands on the anchor rather than on world (0, 0). Depth 0 is used so the
# level's radial bound is far away and only the anchor maths is under test.
func test_prefab_stamps_relative_to_a_non_zero_anchor() -> void:
	var level_bounds = LevelBound.new(0, "Unit Test", 4)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles,
		"rrr\nr0r\nrrr",
		".#.\n#0#\n.#.",
		"...\n.0c\n...",
		Vector2i(2, -1))

	assert_true(ok, "a prefab should stamp at an arbitrary anchor")
	assert_eq(tiles.get_top(2, -1), TileKind.TOP.OPEN, "the marker lands on the anchor itself")
	assert_eq(tiles.get_top(2, -2), TileKind.TOP.MINABLE_ROCK, "north of the anchor is minable rock")
	assert_eq(tiles.get_top(1, -1), TileKind.TOP.MINABLE_ROCK, "west of the anchor is minable rock")
	assert_eq(tiles.get_ore(3, -1), TileKind.ORE.COPPER, "the copper moves with the anchor")
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.MINABLE_ROCK,
		"world (0, 0) is untouched -- it is no longer where the marker goes")


func test_unrecognized_character_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "r0", "X0", ".0")
	assert_push_error("Found invalid character: 'X' at index 0", "Expected error found")
	assert_false(ok, "an unrecognised character in any grid should fail the whole load")


func test_ore_under_anything_but_minable_rock_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "r0", ".0", "c0")
	assert_false(ok, "ore over anything but minable rock should fail the load")


# A tile the top grid never mentions defaults to minable rock, which is what
# ore requires -- so ore there is legal rather than a failure. Without this,
# authoring an ore pocket would force the top grid to be filled out around it.
func test_ore_over_a_tile_the_top_grid_never_mentions_is_allowed() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "r0", "0", "c0")

	assert_true(ok, "ore over an unmentioned top tile should load")
	assert_eq(tiles.get_top(-1, 0), TileKind.TOP.MINABLE_ROCK, "that tile defaulted to minable rock")
	assert_eq(tiles.get_ore(-1, 0), TileKind.ORE.COPPER, "and it carries the copper")


func test_failed_load_does_not_mutate_tiles() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	_stamp(tiles, "r0", "X0", ".0")
	assert_push_error("Found invalid character: 'X' at index 0", "Expected error found")
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.MINABLE_ROCK,
		"a failed load should leave tile data at its untouched default, not partially written")


func test_ground_grid_missing_anchor_marker_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "rr", ".0", ".0")
	assert_false(ok, "a ground grid with no anchor marker should fail the load")


func test_ground_grid_two_anchor_markers_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "00", ".0", ".0")
	assert_false(ok, "a ground grid with two anchor markers should fail the load")


func test_top_grid_missing_anchor_marker_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "r0", "..", ".0")
	assert_false(ok, "a top grid with no anchor marker should fail the load")


func test_top_grid_two_anchor_markers_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "r0", "00", ".0")
	assert_false(ok, "a top grid with two anchor markers should fail the load")


func test_ore_grid_missing_anchor_marker_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "r0", ".0", "..")
	assert_false(ok, "an ore grid with no anchor marker should fail the load")


func test_ore_grid_two_anchor_markers_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "r0", ".0", "00")
	assert_false(ok, "an ore grid with two anchor markers should fail the load")


# A short/ragged row leaves some in-bounds tiles unmentioned by any grid.
# Those default to minable rock with no ore, rather than failing the load.
# Top and ore grids below are both short on their last row, so (0, 1) and
# (1, 1) are never written by the loader.
func test_missing_tiles_default_to_minable_rock_without_ore() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles,
		"rrr\nr0\nrrr",
		".#.\n#0#\n.",
		"...\n.0.\n.")

	assert_true(ok, "a short row should default missing tiles, not fail the load")
	assert_eq(tiles.get_top(-1, 1), TileKind.TOP.OPEN, "a tile the grid did specify keeps its value")
	assert_eq(tiles.get_top(0, 1), TileKind.TOP.MINABLE_ROCK, "a missing tile defaults to minable rock")
	assert_eq(tiles.get_top(1, 1), TileKind.TOP.MINABLE_ROCK, "a missing tile defaults to minable rock")
	assert_eq(tiles.get_ore(0, 1), TileKind.ORE.NONE, "a missing tile carries no ore")
	assert_eq(tiles.get_ore(1, 1), TileKind.ORE.NONE, "a missing tile carries no ore")
	assert_eq(tiles.get_ground(1, 0), TileKind.GROUND.ROCK, "a missing ground tile is a rock")


# Grids are aligned to each other by their markers, not by position in the
# string -- so layers of different shapes still line up. Here the top grid has
# a leading column the ore grid does not, putting the same tile at a different
# raw string index in each.
func test_layers_of_different_shapes_align_by_their_markers() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 2)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles,
		"rrr\nr0r\nrrr",
		"..#\n.0#\n..#",
		"0c")

	assert_true(ok, "grids of different shapes should align by marker")
	assert_eq(tiles.get_top(1, 0), TileKind.TOP.MINABLE_ROCK, "east of the anchor is minable rock")
	assert_eq(tiles.get_ore(1, 0), TileKind.ORE.COPPER, "and the ore grid put its copper in that tile")
	assert_eq(tiles.get_ore(0, 0), TileKind.ORE.NONE, "the anchor itself carries no ore")


# A grid wider than the level's radius reaches tiles the level can't hold.
# Those are discarded rather than failing the load; in-bounds tiles, including
# the ones right at the edge, still load normally.
func test_tiles_beyond_level_bounds_are_discarded_not_failed() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles,
		"rrrr\nr0rr\nrrrr",
		".#..\n#0#.\n.#..",
		"....\n.0..\n....")

	assert_true(ok, "a grid wider than the level should discard the excess, not fail the load")
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.OPEN, "the anchor still loads correctly")
	assert_eq(tiles.get_top(1, 0), TileKind.TOP.MINABLE_ROCK, "the edge tile still loads correctly")
	assert_eq(tiles.get_ground(2, 0), LevelTiles.SENTINEL_OUT_OF_ARRAY,
		"the column beyond the level's radius is never actually there to read back")


# The anchor marker isn't always at the grid's geometric center. Tiles must
# land relative to wherever '0' actually sits, not to an assumed center of a
# (radius * 2 + 1) square -- regression test for a bug where loading always
# started at the array's corner instead.
func test_off_center_marker_places_tiles_relative_to_the_marker() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 2)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles,
		"rrrr\nr0rr\nrrrr",
		"..#.\n.0#.\n..#.",
		"....\n.0..\n....")

	assert_true(ok, "an off-center marker should still load")
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.OPEN, "the anchor cell itself is open")
	assert_eq(tiles.get_top(-1, 0), TileKind.TOP.OPEN, "west of the anchor is open")
	assert_eq(tiles.get_top(1, 0), TileKind.TOP.MINABLE_ROCK, "east of the anchor is minable rock")
