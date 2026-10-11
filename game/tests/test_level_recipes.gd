extends GutTest

# LevelRecipeTable / World.is_in_bounds — one recipe per depth, each
# holding that level's bounds (D-085, D-086). Radii come from
# game/src/world/level_recipes.tres (values sourced from
# docs/tuning-appendix.md §9).


func test_all_eight_depths_have_bounds() -> void:
	for depth in range(0, 8):
		assert_not_null(World.level_recipes.get_bounds(depth),
			"depth %d should have a LevelBound row" % depth)


func test_get_bounds_returns_null_for_unknown_depth() -> void:
	assert_null(World.level_recipes.get_bounds(99), "an out-of-range depth should return null, not crash")
	assert_push_error("LevelRecipe for depth 99 was not found.")

	assert_null(World.level_recipes.get_bounds(-1), "a negative depth should return null, not crash")
	assert_push_error("LevelRecipe for depth -1 was not found.")


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


# Rows are found by depth, but spawning walks them in order and
# Level.clamp_depth uses their count, so row N must be depth N (D-086).
func test_each_rows_depth_matches_its_position() -> void:
	var rows: Array[LevelRecipe] = World.level_recipes.rows
	for index in rows.size():
		assert_not_null(rows[index], "row %d holds a recipe" % index)
		if rows[index] == null: continue
		assert_not_null(rows[index].bound, "row %d's recipe has bounds" % index)
		if rows[index].bound == null: continue
		assert_eq(rows[index].bound.depth, index, "row %d is depth %d" % [index, index])


func test_there_is_one_recipe_per_depth() -> void:
	assert_eq(World.level_recipes.rows.size(), 8, "Surface through -7")


# The radii moved here from level_bounds.tres unchanged.
func test_radii_carried_over_from_the_bounds_table() -> void:
	var expected: Array[int] = [90, 64, 81, 102, 129, 163, 207, 207]
	for depth in expected.size():
		assert_eq(World.level_recipes.get_bounds(depth).radius, expected[depth],
			"depth %d radius" % depth)


func test_get_recipe_finds_the_recipe_holding_those_bounds() -> void:
	var recipe: LevelRecipe = World.level_recipes.get_recipe(2)
	assert_not_null(recipe, "depth 2 has a recipe")
	assert_same(recipe.bound, World.level_recipes.get_bounds(2),
		"get_bounds is the recipe's own bound")
	assert_eq(recipe.bound.name, "Greyseam", "and it is Greyseam")
