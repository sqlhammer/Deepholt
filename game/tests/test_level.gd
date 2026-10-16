extends GutTest

# Level -- one depth's node: its tile data and its fixtures, empty until
# the generator fills them. Where a player spawns is no longer a level
# property (D-091, D-092): it's a WORLD_SPAWN fixture.


func _level(depth: int) -> Level:
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(depth)
	add_child_autofree(level)
	return level


func test_setup_sets_the_depth_and_name() -> void:
	var level: Level = _level(2)
	assert_eq(level.depth, 2, "depth 2")
	assert_eq(level.name, "Level2", "named for its depth")


func test_a_depth_past_the_recipes_is_clamped() -> void:
	assert_eq(_level(99).depth, World.level_recipes.rows.size() - 1, "clamped to the deepest")
	assert_eq(_level(-5).depth, 0, "clamped to the Surface")


func test_tile_data_has_the_recipes_shape() -> void:
	var level: Level = _level(1)
	assert_eq(level.level_tiles.level_bound, World.level_recipes.get_bounds(1), "-1's bounds")


func test_a_new_level_is_solid_rock_with_no_fixtures() -> void:
	var level: Level = _level(1)
	assert_eq(level.level_tiles.get_top(0, 0), TileKind.TOP.MINABLE_ROCK, "nothing stamped yet")
	assert_eq(level.level_fixtures.all().size(), 0, "and no fixtures")


func test_each_depth_gets_its_own_seed_and_the_same_one_every_time() -> void:
	assert_eq(_level(1).level_seed, _level(1).level_seed, "same depth, same seed")
	assert_ne(_level(1).level_seed, _level(2).level_seed, "different depths differ")
