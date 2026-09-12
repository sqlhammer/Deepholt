extends GutTest


func test_display_of_surface() -> void:
	assert_eq(World.depth_to_display(0), "Surface", "depth 0 must display as Surface")


func test_display_of_a_level() -> void:
	assert_eq(World.depth_to_display(3), "-3", "depth 3 must display as -3")


func test_round_trip_for_all_eight_depths() -> void:
	for depth in range(0, 8):
		var display: String = World.depth_to_display(depth)
		var round_tripped: int = World.display_to_depth(display)
		assert_eq(round_tripped, depth,
			"display(internal(%d)) should equal %d" % [depth, depth])

