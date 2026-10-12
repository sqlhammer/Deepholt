class_name LevelGenerator
extends RefCounted

# Builds the levels from their recipes (D-084): fixed placements first,
# then -- once they exist -- rules, then validation. Returns levels not
# yet in the tree; the caller decides where they live.
#
# Anything random in generation draws from the level's own generator,
# never the global randi(), and never depends on node or dictionary
# iteration order, so the same world seed always builds the same world
# (NOW.md trap 8). Fixed placements use no randomness.


static func generate_levels(recipes: LevelRecipeTable) -> Array[Level]:
	var levels: Array[Level] = []
	for recipe: LevelRecipe in recipes.rows:
		levels.append(generate_level(recipe))
	return levels


static func generate_level(recipe: LevelRecipe) -> Level:
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(recipe.bound.depth)
	apply_fixed_placements(level, recipe)
	return level


# Stamps each of the recipe's fixed prefabs. A recipe naming a prefab
# that doesn't exist, or one that fails to stamp, is an authoring
# error: it is reported, and the rest of the recipe still applies.
# Returns false if any placement failed.
static func apply_fixed_placements(level: Level, recipe: LevelRecipe) -> bool:
	var all_placed: bool = true
	for placement: PrefabPlacement in recipe.fixed_placements:
		var prefab: TilePrefab = TilePrefabRegistry.get_prefab(placement.prefab_id)
		if prefab == null:
			push_error("Recipe for depth %d names missing prefab '%s'." % [
				recipe.bound.depth, placement.prefab_id])
			all_placed = false
			continue
		if not LevelGridLoader.stamp(level.level_tiles, prefab, placement.anchor):
			push_error("Prefab '%s' failed to stamp at depth %d." % [
				placement.prefab_id, recipe.bound.depth])
			all_placed = false
	return all_placed


# The only source of randomness for generating this level: seeded from
# the level's own seed, so each depth gets its own repeatable sequence.
static func rng_for(level: Level) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = level.level_seed
	return rng
















