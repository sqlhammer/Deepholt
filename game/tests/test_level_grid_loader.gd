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


# Every tile a prefab mentions, it mentions on all three layers (D-102).
# Ore over a tile the top grid leaves out used to be legal, because the
# default happened to be rock; now the prefab fails to load first.
func test_ore_over_a_tile_the_top_grid_never_mentions_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "r0", "0", "c0")

	assert_false(ok, "the top grid doesn't cover (-1, 0), so the prefab is rejected")
	assert_eq(tiles.get_ore(-1, 0), TileKind.ORE.NONE, "and nothing was written")


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


# A prefab may be jagged, as long as all three layers share the shape
# exactly (D-102). Here every grid's last row is one tile long, so (0, 1)
# and (1, 1) are mentioned by no grid, and keep the level's default.
func test_a_jagged_prefab_loads_when_every_layer_shares_its_shape() -> void:
	# Radius 2: the 3 x 3 grid's corners, (+-1, +-1), are outside radius 1.
	var level_bounds = LevelBound.new(1, "Unit Test", 2)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles,
		"ddd\nd0d\nd",
		".#.\n#0#\n.",
		"...\n.0.\n.")

	assert_true(ok, "a jagged shape shared by every layer loads")
	assert_eq(tiles.get_top(-1, 1), TileKind.TOP.OPEN, "a tile the grids specify keeps its value")
	assert_eq(tiles.get_ground(-1, 1), TileKind.GROUND.DIRT, "on every layer")


# Tiles a prefab doesn't mention at all keep the level's default on every
# layer: a prefab is smaller than the level (D-062, kept by D-102).
func test_tiles_outside_the_prefab_keep_the_level_default() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 2)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	_stamp(tiles, "ddd\nd0d\nd", ".#.\n#0#\n.", "...\n.0.\n.")

	for tile: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, -2)]:
		assert_eq(tiles.get_top(tile.x, tile.y), TileKind.TOP.MINABLE_ROCK, "%s top is the default" % tile)
		assert_eq(tiles.get_ground(tile.x, tile.y), TileKind.GROUND.ROCK, "%s ground is the default" % tile)
		assert_eq(tiles.get_ore(tile.x, tile.y), TileKind.ORE.NONE, "%s has no ore" % tile)


func test_a_short_row_on_one_layer_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 2)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles,
		"rrr\nr0r\nrrr",
		".#.\n#0#\n.",
		"...\n.0.\n...")

	assert_false(ok, "the top grid's last row is short, so two tiles are half-described")
	assert_eq(tiles.get_top(-1, -1), TileKind.TOP.MINABLE_ROCK, "and nothing was written")


# Grids are aligned to each other by their markers, not by position in the
# string. Here every grid covers the same tiles (D-102), but the ore grid is
# written with a blank first line, so the same tile sits at a different raw
# string index in each. Measured from the markers, they still line up.
func test_layers_align_by_their_markers_not_their_strings() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 2)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles,
		"rr\n0r",
		".#\n0#",
		"\n..\n0c")

	assert_true(ok, "the same tiles, written differently, align by marker")
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
	assert_eq(tiles.get_ground(2, 0), TileKind.SENTINEL_OUT_OF_ARRAY,
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


# --- regex_escape ---

# The loader builds a regex character class out of the allowed grid
# characters. Three characters mean something inside a class and must
# be escaped; anything else passes through, and only single
# characters are accepted.

func test_class_special_characters_are_escaped() -> void:
	assert_eq(LevelGridLoader.regex_escape("]"), "\\]", "] would close the class")
	assert_eq(LevelGridLoader.regex_escape("-"), "\\-", "- would make a range")
	assert_eq(LevelGridLoader.regex_escape("\\"), "\\\\",
		"a backslash would escape the next character")


func test_ordinary_characters_pass_through() -> void:
	for character: String in ["#", ".", "0", "r", "c"]:
		assert_eq(LevelGridLoader.regex_escape(character), character,
			"'%s' needs no escaping" % character)


func test_more_than_one_character_is_refused() -> void:
	assert_eq(LevelGridLoader.regex_escape("ab"), "", "only single characters are escaped")


# Dirt is authored as 'd' on the ground grid and '%' on the top grid:
# '#' and '%' are both solid mass, letters are materials (D-056).
func test_dirt_characters_load_as_dirt() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "d0", "%0", ".0")

	assert_true(ok, "dirt characters should load")
	assert_eq(tiles.get_ground(-1, 0), TileKind.GROUND.DIRT, "'d' is dirt ground")
	assert_eq(tiles.get_top(-1, 0), TileKind.TOP.MINABLE_DIRT, "'%' is minable dirt")


func test_ore_in_minable_dirt_fails_to_load() -> void:
	var level_bounds = LevelBound.new(1, "Unit Test", 1)
	var tiles: LevelTiles = LevelTiles.new(level_bounds)
	var ok: bool = _stamp(tiles, "d0", "%0", "c0")
	assert_false(ok, "ore may only sit in minable rock, not dirt (D-056)")


# --- _grid_coords_align_and_are_complete ---
# True when the three grids, each measured from its own anchor marker,
# cover exactly the same coordinates. Built from real grid strings so
# the coordinates are what stamp() would compare.

func _aligned(ground: String, top: String, ore: String) -> bool:
	return LevelGridLoader._grid_coords_align_and_are_complete(
		LevelGridLoader._to_anchored_tiles(ground),
		LevelGridLoader._to_anchored_tiles(top),
		LevelGridLoader._to_anchored_tiles(ore))


func test_grids_of_the_same_shape_align() -> void:
	assert_true(_aligned("rrr\nr0r\nrrr", ".#.\n#0#\n.#.", "...\n.0c\n..."),
		"three 3 x 3 grids with the marker in the middle")


func test_alignment_ignores_what_the_characters_are() -> void:
	assert_true(_aligned("dhd\nd0d", "#.#\n%0%", "c.c\n.0."),
		"only coordinates are compared, not contents")


func test_the_same_shape_written_with_different_padding_aligns() -> void:
	# Trailing whitespace is stripped when a grid is read, so a carriage
	# return or a trailing space doesn't add a column.
	assert_true(_aligned("r0\r\nrr", " 0 \n##", ".0\n.."),
		"trailing whitespace is not a column")


func test_a_short_row_in_one_grid_does_not_align() -> void:
	assert_false(_aligned("rrr\nr0r\nrrr", ".#.\n#0#\n.", "...\n.0.\n..."),
		"the top grid's last row is short, so it misses two coordinates")


func test_an_extra_column_in_one_grid_does_not_align() -> void:
	assert_false(_aligned("r0r", "#0#", ".0.."),
		"the ore grid covers one coordinate the others don't")


# The size check alone can't catch this: every grid has three tiles,
# but the top grid's marker is on its left edge, so its tiles are at
# x 0..2 while ground's are at x -1..1.
func test_grids_the_same_size_but_shifted_do_not_align() -> void:
	assert_false(_aligned("r0r", "0##", ".0."),
		"same count, different coordinates")


func test_markers_line_grids_up_even_when_their_strings_differ() -> void:
	# The top grid has a leading empty line, but measured from its own
	# marker it covers the same three tiles as the others.
	assert_true(_aligned("r0r", "\n#0#", ".0."),
		"coordinates are measured from each grid's marker, not its first line")


func test_one_empty_grid_does_not_align() -> void:
	assert_false(_aligned("r0r", "#0#", ""), "an empty ore grid covers nothing")


func test_three_empty_grids_align() -> void:
	assert_true(_aligned("", "", ""), "nothing against nothing")


# --- the objects grid (D-100, D-102, D-104) ---

# Every tile grid covers x -1..1, y -1..1 around the marker, all open
# floor except a hole at (1, 1).
const OPEN_GROUND: String = "rrr\nr0r\nrrh"
const OPEN_TOP: String = "...\n.0.\n..."
const OPEN_ORE: String = "...\n.0.\n..."


func _stamp_with_objects(objects: String, fixtures: LevelFixtures, top: String = OPEN_TOP) -> Array:
	var tiles: LevelTiles = LevelTiles.new(LevelBound.new(1, "Unit Test", 4))
	var prefab: TilePrefab = TilePrefab.from_grids(&"test_objects", OPEN_GROUND, top, OPEN_ORE, objects)
	Objects.reset_ids()
	var ok: bool = LevelGridLoader.stamp(tiles, prefab, Vector2i(2, 0), fixtures)
	return [ok, tiles]


func test_an_l_becomes_a_ladder_fixture_at_its_anchored_tile() -> void:
	var fixtures: LevelFixtures = LevelFixtures.new()
	var result: Array = _stamp_with_objects("0L", fixtures)
	assert_true(result[0], "loads")
	var ladders: Array[Fixture] = fixtures.of_kind(ObjectKind.OBJECT.LADDER)
	assert_eq(ladders.size(), 1, "one ladder")
	if ladders.size() == 1:
		assert_eq(Vector2i(ladders[0].tile.x, ladders[0].tile.y), Vector2i(3, 0),
			"(1, 0) from the marker, stamped at anchor (2, 0)")
		assert_eq(ladders[0].tile.depth, 1, "on the level's own depth")


func test_a_prefab_with_no_objects_grid_stamps_as_before() -> void:
	var fixtures: LevelFixtures = LevelFixtures.new()
	assert_true(_stamp_with_objects("", fixtures)[0], "loads")
	assert_eq(fixtures.all().size(), 0, "and has no fixtures")


func test_an_empty_objects_grid_needs_no_store() -> void:
	assert_true(_stamp_with_objects("", null)[0], "no fixtures, no store needed")


func test_a_small_objects_grid_lines_up_by_its_marker() -> void:
	# Shaped nothing like the 3 x 3 tile grids: one line above the marker.
	var fixtures: LevelFixtures = LevelFixtures.new()
	assert_true(_stamp_with_objects("L\n0", fixtures)[0], "loads")
	assert_true(fixtures.has_kind_at(Vector2i(2, -1), ObjectKind.OBJECT.LADDER),
		"(0, -1) from the marker, at anchor (2, 0)")


func test_fixtures_get_ids_in_row_then_column_order() -> void:
	var fixtures: LevelFixtures = LevelFixtures.new()
	_stamp_with_objects("L.L\n.0.\nL..", fixtures)
	var ids: Array[int] = []
	for tile: Vector2i in [Vector2i(1, -1), Vector2i(3, -1), Vector2i(1, 1)]:
		ids.append(fixtures.at(tile)[0].id)
	assert_eq(ids, [1, 2, 3] as Array[int], "top row left to right, then the next row")


func test_a_fixture_on_a_solid_top_fails_and_writes_nothing() -> void:
	var fixtures: LevelFixtures = LevelFixtures.new()
	var result: Array = _stamp_with_objects("0L", fixtures, "...\n.0#\n...")
	assert_false(result[0], "a ladder inside rock")
	assert_eq(result[1].get_top(1, 0), TileKind.TOP.MINABLE_ROCK, "no tiles written (the default)")
	assert_eq(result[1].get_top(2, 0), TileKind.TOP.MINABLE_ROCK, "not even the marker")
	assert_eq(fixtures.all().size(), 0, "no fixtures")


func test_a_fixture_on_a_hole_fails() -> void:
	assert_false(_stamp_with_objects("0.\n.L", LevelFixtures.new())[0], "(1, 1) is a hole")


func test_a_fixture_on_a_tile_the_tile_grids_dont_describe_fails() -> void:
	assert_false(_stamp_with_objects("0.L", LevelFixtures.new())[0],
		"(2, 0) is outside the tile grids: default rock")


func test_objects_grid_markers_and_characters_are_checked() -> void:
	assert_false(_stamp_with_objects(".L", LevelFixtures.new())[0], "no marker")
	assert_false(_stamp_with_objects("0L0", LevelFixtures.new())[0], "two markers")
	assert_false(_stamp_with_objects("0X", LevelFixtures.new())[0], "an unknown character")
	assert_push_error("Found invalid character: 'X'")


func test_fixtures_without_a_store_fail_rather_than_vanish() -> void:
	var result: Array = _stamp_with_objects("0L", null)
	assert_false(result[0], "refused")
	assert_push_error("has fixtures, but no fixture store was given")
	assert_eq(result[1].get_top(2, 0), TileKind.TOP.MINABLE_ROCK, "and no tiles written")
