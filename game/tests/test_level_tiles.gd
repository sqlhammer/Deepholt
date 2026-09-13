extends GutTest

# LevelTiles — flat per-layer byte arrays holding a level's tile truth (D-048), with a third
# array for ore (D-054), sized to the square around a level's radial bounds and indexed by
# (x, y) from the level's origin. Reads outside the array or outside the radial disc return
# reserved sentinels rather than an ordinary kind (D-057, D-059).


func test_write_and_read_ground() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[1])
	tiles.set_ground(1, -1, TileKind.GROUND.ROCK)
	assert_eq(tiles.get_ground(1, -1), TileKind.GROUND.ROCK,
		"ground tile should read back what was written")


func test_write_and_read_top() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[1])
	tiles.set_top(1, -1, TileKind.TOP.MINABLE_ROCK)
	assert_eq(tiles.get_top(1, -1), TileKind.TOP.MINABLE_ROCK,
		"top tile should read back what was written")


func test_write_and_read_ore() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[1])
	tiles.set_ore(1, -1, TileKind.ORE.COPPER)
	assert_eq(tiles.get_ore(1, -1), TileKind.ORE.COPPER,
		"ore tile should read back what was written")


func test_writing_one_layer_does_not_affect_another() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[1])
	tiles.set_top(1, 1, TileKind.TOP.MINABLE_ROCK)
	assert_eq(tiles.get_ore(0, 0), TileKind.ORE.NONE,
		"writing the top layer should not leak into the ore layer at the same coordinate")


func test_read_past_positive_x_edge_is_out_of_array() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[1])
	assert_eq(tiles.get_ground(65, 0), LevelTiles.SENTINEL_OUT_OF_ARRAY,
		"x = radius + 1 is past the array's edge")


func test_read_past_negative_x_edge_is_out_of_array() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[1])
	assert_eq(tiles.get_ground(-65, 0), LevelTiles.SENTINEL_OUT_OF_ARRAY,
		"x = -(radius + 1) is past the array's edge")


func test_read_past_positive_y_edge_is_out_of_array() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[1])
	assert_eq(tiles.get_ground(0, 65), LevelTiles.SENTINEL_OUT_OF_ARRAY,
		"y = radius + 1 is past the array's edge")


func test_read_past_negative_y_edge_is_out_of_array() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[1])
	assert_eq(tiles.get_ground(0, -65), LevelTiles.SENTINEL_OUT_OF_ARRAY,
		"y = -(radius + 1) is past the array's edge")


func test_read_in_square_corner_outside_disc_is_out_of_bounds() -> void:
	# Level -1 has a radius of 64. This covers -64 to 64 but (64,64) is 90.50966
	# which is outside of our circular boundary.
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[1])
	assert_eq(tiles.get_ground(64, 64), LevelTiles.SENTINEL_OUT_OF_BOUNDS,
		"a square corner outside the radius should read as out-of-bounds, not out-of-array")


func test_sentinels_apply_to_every_layer() -> void:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[1])
	assert_eq(tiles.get_top(65, 0), LevelTiles.SENTINEL_OUT_OF_ARRAY,
		"the top layer should also sentinel out-of-array reads")
	assert_eq(tiles.get_ore(65, 0), LevelTiles.SENTINEL_OUT_OF_ARRAY,
		"the ore layer should also sentinel out-of-array reads")
	assert_eq(tiles.get_top(64, 64), LevelTiles.SENTINEL_OUT_OF_BOUNDS,
		"the top layer should also sentinel out-of-bounds reads")
	assert_eq(tiles.get_ore(64, 64), LevelTiles.SENTINEL_OUT_OF_BOUNDS,
		"the ore layer should also sentinel out-of-bounds reads")


func test_out_of_array_and_out_of_bounds_sentinels_are_distinguishable() -> void:
	assert_ne(LevelTiles.SENTINEL_OUT_OF_ARRAY, LevelTiles.SENTINEL_OUT_OF_BOUNDS,
		"the two sentinels must not collide")
