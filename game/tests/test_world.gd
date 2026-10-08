extends GutTest

# World (autoload): finding a resident level or its tiles by depth,
# and reading a depth back from its display name. Depth display
# round trips are in test_depth_mapping.gd.


func before_each() -> void:
	for depth in [0, 2]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		add_child_autofree(level)


func test_level_tiles_are_found_by_depth() -> void:
	var tiles: LevelTiles = World.get_level_tiles_from_depth(2)
	assert_not_null(tiles, "depth 2 is resident")
	if tiles:
		assert_eq(tiles, World.get_level(2).level_tiles,
			"and they are depth 2's level's tiles")


func test_level_tiles_for_a_missing_depth_are_null() -> void:
	assert_null(World.get_level_tiles_from_depth(5),
		"no level is resident at depth 5")


func test_a_level_is_found_by_depth() -> void:
	var level: Level = World.get_level(2)
	assert_not_null(level, "depth 2 is resident")
	if level:
		assert_eq(level.depth, 2, "and it is depth 2")


func test_a_missing_level_is_null() -> void:
	assert_null(World.get_level(5), "no level is resident at depth 5")


func test_an_unreadable_display_name_is_not_a_depth() -> void:
	assert_eq(World.display_to_depth("Basement"), -99,
		"a name that is neither Surface nor a number gives -99")
	assert_eq(World.display_to_depth(""), -99, "and so does an empty one")
