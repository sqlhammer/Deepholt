extends GutTest

# TileSpace -- the tile <-> pixel convention shared by simulation and
# presentation (D-067). Moved here from test_level_renderer.gd along
# with tile_center itself.


func test_a_tile_is_sixteen_pixels() -> void:
	assert_eq(TileSpace.TILE_PIXELS, 16,
		"tile art and every conversion assume 16 px tiles")


func test_tile_centers_sit_half_a_tile_into_each_tile() -> void:
	assert_eq(TileSpace.tile_center(Vector2i(0, 0)), Vector2(8, 8),
		"tile (0, 0)'s top-left corner is the level's origin")
	assert_eq(TileSpace.tile_center(Vector2i(2, 1)), Vector2(40, 24),
		"each tile is 16 px further along")
	assert_eq(TileSpace.tile_center(Vector2i(-1, -1)), Vector2(-8, -8),
		"negative tiles sit up and to the left of the origin, not on it")
