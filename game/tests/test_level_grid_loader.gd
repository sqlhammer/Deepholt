extends GutTest

# LevelGridLoader -- parses a level's three per-layer text grids into a LevelTiles, with each
# grid's own origin marker landing at world (0, 0) (D-049, D-052, D-053). Malformed grids are a
# hard, all-or-nothing failure (D-055); ore may only sit under minable rock (D-056).
#
# Grid layout used by the success test, marker '0' at the center:
#   ground        top           ore
#   rrr           .#.           ...
#   r0r           #0#           .0c
#   rrr           .#.           ...
# so north/south/west/east of the origin are all minable rock, the diagonals are open, and
# the east tile alone carries copper.


func test_small_grid_loads_and_spot_checks_all_four_sides_of_origin() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles,
		"rrr\nr0r\nrrr",
		".#.\n#0#\n.#.",
		"...\n.0c\n...")

	assert_true(ok, "a well-formed grid set should load")
	assert_eq(tiles.get_ground(0, 0), TileKind.GROUND.ROCK, "the origin's ground is rock")
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.OPEN, "the origin's top is open")
	assert_eq(tiles.get_ore(0, 0), TileKind.ORE.NONE, "the origin carries no ore")

	assert_eq(tiles.get_top(0, -1), TileKind.TOP.MINABLE_ROCK, "north of the origin is minable rock")
	assert_eq(tiles.get_top(0, 1), TileKind.TOP.MINABLE_ROCK, "south of the origin is minable rock")
	assert_eq(tiles.get_top(-1, 0), TileKind.TOP.MINABLE_ROCK, "west of the origin is minable rock")
	assert_eq(tiles.get_top(1, 0), TileKind.TOP.MINABLE_ROCK, "east of the origin is minable rock")

	assert_eq(tiles.get_ore(1, 0), TileKind.ORE.COPPER, "east of the origin carries the copper")
	assert_eq(tiles.get_ore(0, -1), TileKind.ORE.NONE, "north of the origin carries no ore")
	assert_eq(tiles.get_ore(0, 1), TileKind.ORE.NONE, "south of the origin carries no ore")
	assert_eq(tiles.get_ore(-1, 0), TileKind.ORE.NONE, "west of the origin carries no ore")


func test_unrecognized_character_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles, "r0", "X0", ".0")
	assert_push_error("Found invalid character: 'X' at index 0", "Expected error found")
	assert_false(ok, "an unrecognised character in any grid should fail the whole load")


func test_ore_under_anything_but_minable_rock_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles, "r0", ".0", "c0")
	assert_false(ok, "ore over anything but minable rock should fail the load")


func test_failed_load_does_not_mutate_tiles() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	LevelGridLoader.load(tiles, "r0", "X0", ".0")
	assert_push_error("Found invalid character: 'X' at index 0", "Expected error found")
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.MINABLE_ROCK,
		"a failed load should leave tile data at its untouched default, not partially written")


func test_ground_grid_missing_origin_marker_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles, "rr", ".0", ".0")
	assert_false(ok, "a ground grid with no origin marker should fail the load")


func test_ground_grid_two_origin_markers_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles, "00", ".0", ".0")
	assert_false(ok, "a ground grid with two origin markers should fail the load")


func test_top_grid_missing_origin_marker_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles, "r0", "..", ".0")
	assert_false(ok, "a top grid with no origin marker should fail the load")


func test_top_grid_two_origin_markers_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles, "r0", "00", ".0")
	assert_false(ok, "a top grid with two origin markers should fail the load")


func test_ore_grid_missing_origin_marker_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles, "r0", ".0", "..")
	assert_false(ok, "an ore grid with no origin marker should fail the load")


func test_ore_grid_two_origin_markers_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles, "r0", ".0", "00")
	assert_false(ok, "an ore grid with two origin markers should fail the load")


# A short/ragged row leaves some in-bounds tiles unmentioned by any
# grid. Those default to minable rock with no ore, rather than
# failing the load. Top and ore grids below are both short on their
# last row, so (0, 1) and (1, 1) are never written by the loader.
func test_missing_tiles_default_to_minable_rock_without_ore() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles,
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


# A grid wider than the level's radius reaches tiles the level can't
# hold. Those are discarded rather than failing the load; in-bounds
# tiles, including the ones right at the edge, still load normally.
func test_tiles_beyond_level_bounds_are_discarded_not_failed() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles,
		"rrrr\nr0rr\nrrrr",
		".#..\n#0#.\n.#..",
		"....\n.0..\n....")

	assert_true(ok, "a grid wider than the level should discard the excess, not fail the load")
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.OPEN, "the origin still loads correctly")
	assert_eq(tiles.get_top(1, 0), TileKind.TOP.MINABLE_ROCK, "the edge tile still loads correctly")
	assert_eq(tiles.get_ground(2, 0), LevelTiles.SENTINEL_OUT_OF_ARRAY,
		"the column beyond the level's radius is never actually there to read back")


# The origin marker isn't always at the grid's geometric center.
# Tiles must land relative to wherever '0' actually sits, not to an
# assumed center of a (radius * 2 + 1) square -- regression test for
# a bug where loading always started at the array's corner instead.
func test_off_center_origin_places_tiles_relative_to_the_marker() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 2)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = LevelGridLoader.load(tiles,
		"rrrr\nr0rr\nrrrr",
		"..#.\n.0#.\n..#.",
		"....\n.0..\n....")

	assert_true(ok, "an off-center origin should still load")
	assert_eq(tiles.get_top(0, 0), TileKind.TOP.OPEN, "the origin cell itself is open")
	assert_eq(tiles.get_top(-1, 0), TileKind.TOP.OPEN, "west of the origin is open")
	assert_eq(tiles.get_top(1, 0), TileKind.TOP.MINABLE_ROCK, "east of the origin is minable rock")










