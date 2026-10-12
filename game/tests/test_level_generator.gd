extends GutTest

# LevelGenerator -- builds each level from its depth's recipe (D-084):
# fixed placements now; rules and validation once procedural
# generation arrives. Levels come back out of the tree.


func _generate(recipe: LevelRecipe) -> Level:
	var level: Level = LevelGenerator.generate_level(recipe)
	autofree(level)
	return level


# A copy of a real depth's recipe with its placements replaced, so a
# test can't change the shared table.
func _recipe_at(depth: int, placements: Array[PrefabPlacement]) -> LevelRecipe:
	var recipe: LevelRecipe = LevelRecipe.new(World.level_recipes.get_bounds(depth))
	recipe.fixed_placements = placements
	return recipe


func _bare_level(depth: int) -> Level:
	var level: Level = Global.level_packed_scene.instantiate()
	autofree(level)
	level.setup(depth)
	return level


func test_one_level_per_recipe_in_order() -> void:
	var levels: Array[Level] = LevelGenerator.generate_levels(World.level_recipes)
	for level in levels: autofree(level)
	assert_eq(levels.size(), World.level_recipes.rows.size(), "one level per recipe")
	for index in levels.size():
		assert_eq(levels[index].depth, index, "level %d is depth %d" % [index, index])


func test_the_surface_recipe_stamps_the_start_prefab() -> void:
	var level: Level = _generate(World.level_recipes.get_recipe(0))
	var expected: LevelTiles = LevelTiles.new(World.level_recipes.get_bounds(0))
	LevelGridLoader.stamp(expected, TilePrefabRegistry.get_prefab(&"surface_start"), Vector2i.ZERO)
	# assert_true, not assert_eq: a failing assert_eq prints every byte.
	assert_true(level.level_tiles.top == expected.top, "the Surface is surface_start at the axis")
	assert_true(level.level_tiles.ground == expected.ground, "ground too")


func test_a_recipe_with_no_placements_is_the_default_fill() -> void:
	var level: Level = _generate(World.level_recipes.get_recipe(3))
	assert_eq(level.level_tiles.get_top(0, 0), TileKind.TOP.MINABLE_ROCK, "solid rock at the axis")


func test_a_placement_lands_on_its_anchor() -> void:
	var placements: Array[PrefabPlacement] = [PrefabPlacement.new(&"surface_start", Vector2i(-40, 30))]
	var level: Level = _generate(_recipe_at(0, placements))
	assert_eq(level.level_tiles.get_top(-40, 30), TileKind.TOP.OPEN, "the prefab's marker is open floor")
	assert_eq(level.level_tiles.get_top(0, 0), TileKind.TOP.MINABLE_ROCK, "and the axis is untouched")


func test_a_recipe_naming_a_missing_prefab_fails_loudly() -> void:
	var placements: Array[PrefabPlacement] = [PrefabPlacement.new(&"no_such_prefab")]
	var ok: bool = LevelGenerator.apply_fixed_placements(_bare_level(0), _recipe_at(0, placements))
	assert_false(ok, "the placement is reported as failed")
	assert_push_error("No tile prefab with id 'no_such_prefab'.")
	assert_push_error("Recipe for depth 0 names missing prefab 'no_such_prefab'.")


func test_a_missing_prefab_does_not_stop_the_rest_of_the_recipe() -> void:
	var placements: Array[PrefabPlacement] = [
		PrefabPlacement.new(&"no_such_prefab"), PrefabPlacement.new(&"surface_start")]
	var level: Level = _generate(_recipe_at(0, placements))
	assert_push_error("No tile prefab with id 'no_such_prefab'.")
	assert_push_error("Recipe for depth 0 names missing prefab 'no_such_prefab'.")
	assert_eq(level.level_tiles.get_ground(1, 0), TileKind.GROUND.DIRT, "surface_start still stamped")


func test_a_prefab_that_fails_to_stamp_fails_loudly() -> void:
	# A prefab with no anchor marker in its ground grid is malformed
	# (D-050). Registered under a test id for the length of the test.
	TilePrefabRegistry._prefabs[&"test_malformed"] = TilePrefab.from_grids(
		&"test_malformed", "r", "0", "0")
	var placements: Array[PrefabPlacement] = [PrefabPlacement.new(&"test_malformed")]
	var ok: bool = LevelGenerator.apply_fixed_placements(_bare_level(0), _recipe_at(0, placements))
	TilePrefabRegistry._prefabs.erase(&"test_malformed")
	assert_false(ok, "a malformed prefab fails the placement")
	assert_push_error("Prefab 'test_malformed' failed to stamp at depth 0.")


# --- randomness (trap 8) ---

func test_the_same_level_seed_gives_the_same_sequence() -> void:
	var rng_a: RandomNumberGenerator = LevelGenerator.rng_for(_bare_level(2))
	var rng_b: RandomNumberGenerator = LevelGenerator.rng_for(_bare_level(2))
	for i in 5:
		assert_eq(rng_a.randi(), rng_b.randi(), "draw %d matches" % i)


func test_each_depth_gets_its_own_sequence() -> void:
	assert_ne(LevelGenerator.rng_for(_bare_level(1)).randi(),
		LevelGenerator.rng_for(_bare_level(2)).randi(),
		"depths don't share a sequence")
