extends GutTest

# LevelRecipeTable / World.is_in_bounds — one recipe per depth, each
# holding that level's bounds (D-085, D-086). Radii come from
# game/src/world/level_recipes.tres (values sourced from
# docs/tuning-appendix.md §9).


func test_all_eight_depths_have_bounds() -> void:
	for depth in range(0, 8):
		assert_not_null(LevelRecipes.TABLE.get_bounds(depth),
			"depth %d should have a LevelBound row" % depth)


func test_get_bounds_returns_null_for_unknown_depth() -> void:
	assert_null(LevelRecipes.TABLE.get_bounds(99), "an out-of-range depth should return null, not crash")
	assert_push_error("LevelRecipe for depth 99 was not found.")

	assert_null(LevelRecipes.TABLE.get_bounds(-1), "a negative depth should return null, not crash")
	assert_push_error("LevelRecipe for depth -1 was not found.")


const Worlds = preload("res://tests/worlds.gd")

var _world: World


func before_each() -> void:
	_world = autofree(Worlds.with_levels(range(0, 8)))


func test_coordinate_in_bounds() -> void:
	# distance 100 from origin: inside The Crush's disc (radius 207)
	var pos: WorldPos = WorldPos.new(100, 0, 6)
	assert_true(_world.is_in_bounds(pos), "(100, 0) should be in bounds at depth 6")


func test_coordiante_out_of_bounds() -> void:
	# distance 100 from origin: outside level Rootshelf's disc (radius 64)
	var pos: WorldPos = WorldPos.new(100, 0, 1)
	assert_false(_world.is_in_bounds(pos), "(100, 0) should be out of bounds at depth 1")


func test_origin_is_in_bounds_everywhere() -> void:
	for depth in range(0, 8):
		var pos: WorldPos = WorldPos.new(0, 0, depth)
		assert_true(_world.is_in_bounds(pos), "the origin should be in bounds at depth %d" % depth)


# A level's own bound is the one read, not the recipe's: a saved bound
# wins (D-112).
func test_in_bounds_reads_the_levels_own_bound() -> void:
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(1, 0, LevelBound.new(1, "Tuned", 120))
	var world: World = autofree(World.new())
	world.add_level(level)
	assert_true(world.is_in_bounds(WorldPos.new(100, 0, 1)),
		"(100, 0) is inside the level's radius of 120, though the recipe's is 64")


func test_a_depth_with_no_level_is_out_of_bounds() -> void:
	var world: World = autofree(Worlds.with_levels([0]))
	assert_false(world.is_in_bounds(WorldPos.new(0, 0, 3)), "no level at depth 3")


# Rows are found by depth, but spawning walks them in order and
# Level.clamp_depth uses their count, so row N must be depth N (D-086).
func test_each_rows_depth_matches_its_position() -> void:
	var rows: Array[LevelRecipe] = LevelRecipes.TABLE.rows
	for index in rows.size():
		assert_not_null(rows[index], "row %d holds a recipe" % index)
		if rows[index] == null: continue
		assert_not_null(rows[index].bound, "row %d's recipe has bounds" % index)
		if rows[index].bound == null: continue
		assert_eq(rows[index].bound.depth, index, "row %d is depth %d" % [index, index])


func test_there_is_one_recipe_per_depth() -> void:
	assert_eq(LevelRecipes.TABLE.rows.size(), 8, "Surface through -7")


# The radii moved here from level_bounds.tres unchanged.
func test_radii_carried_over_from_the_bounds_table() -> void:
	var expected: Array[int] = [90, 64, 81, 102, 129, 163, 207, 207]
	for depth in expected.size():
		assert_eq(LevelRecipes.TABLE.get_bounds(depth).radius, expected[depth],
			"depth %d radius" % depth)


func test_get_recipe_finds_the_recipe_holding_those_bounds() -> void:
	var recipe: LevelRecipe = LevelRecipes.TABLE.get_recipe(2)
	assert_not_null(recipe, "depth 2 has a recipe")
	assert_same(recipe.bound, LevelRecipes.TABLE.get_bounds(2),
		"get_bounds is the recipe's own bound")
	assert_eq(recipe.bound.name, "Greyseam", "and it is Greyseam")
