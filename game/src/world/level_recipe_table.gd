extends Resource
class_name LevelRecipeTable

# One recipe per depth, Surface first (D-086). Rows are found by their
# depth, but code that walks the rows in order (spawning levels,
# clamping a depth) relies on row N being depth N, and a test holds
# the table to that.

@export var rows: Array[LevelRecipe] = []


func get_recipe(depth: int) -> LevelRecipe:
	for row: LevelRecipe in rows:
		if row != null and row.bound != null and row.bound.depth == depth:
			return row

	push_error("LevelRecipe for depth %d was not found." % depth)
	return null


# The shape of the level at a depth, or null if there is none.
func get_bounds(depth: int) -> LevelBound:
	var recipe: LevelRecipe = get_recipe(depth)
	if recipe == null: return null
	return recipe.bound
