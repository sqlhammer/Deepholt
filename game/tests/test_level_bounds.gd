extends GutTest

# LevelBoundTable / World.is_in_bounds — radii come from
# game/src/world/level_bounds.tres (values sourced from docs/tuning-appendix.md §9).


func test_all_eight_depths_have_bounds() -> void:
	for depth in range(0, 8):
		assert_not_null(World.level_bounds.get_bounds(depth),
			"depth %d should have a LevelBound row" % depth)


func test_get_bounds_returns_null_for_unknown_depth() -> void:
	assert_null(World.level_bounds.get_bounds(99), "an out-of-range depth should return null, not crash")
	assert_push_error("LevelBound for depth 99 was not found.")

	assert_null(World.level_bounds.get_bounds(-1), "a negative depth should return null, not crash")
	assert_push_error("LevelBound for depth -1 was not found.")


func test_coordinate_in_bounds() -> void:
	# distance 100 from origin: inside The Crush's disc (radius 207)
	var pos: WorldPos = WorldPos.new(100, 0, 6)
	assert_true(World.is_in_bounds(pos), "(100, 0) should be in bounds at depth 6")


func test_coordiante_out_of_bounds() -> void:
	# distance 100 from origin: outside level Rootshelf's disc (radius 64)
	var pos: WorldPos = WorldPos.new(100, 0, 1)
	assert_false(World.is_in_bounds(pos), "(100, 0) should be out of bounds at depth 1")


func test_origin_is_in_bounds_everywhere() -> void:
	for depth in range(0, 8):
		var pos: WorldPos = WorldPos.new(0, 0, depth)
		assert_true(World.is_in_bounds(pos), "the origin should be in bounds at depth %d" % depth)






