class_name RecipeRegistry
extends RefCounted

# Every recipe on disk, by its stable id (D-222), loaded once from
# content/recipes/, as ItemRegistry loads items. Fixed design data,
# not world state, so static (D-118).

const RECIPE_DIRECTORY: String = "res://content/recipes/"

static var _recipes: Dictionary[StringName, Recipe] = {}
static var _loaded: bool = false


static func find(id: StringName) -> Recipe:
	_load()
	return _recipes.get(id)


# The recipes made at `station`, in id order so the list is stable.
# Sorted as text: a StringName's own order isn't alphabetical.
static func at_station(station: StringName) -> Array[Recipe]:
	_load()
	var ids: Array[StringName] = []
	ids.assign(_recipes.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var found: Array[Recipe] = []
	for id: StringName in ids:
		if _recipes[id].station == station: found.append(_recipes[id])
	return found


static func _load() -> void:
	if _loaded: return
	_loaded = true
	for file_name in DirAccess.get_files_at(RECIPE_DIRECTORY):
		# an exported build hands back the .remap name, not the .tres
		var resource_name: String = file_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"): continue
		var recipe: Recipe = ResourceLoader.load(RECIPE_DIRECTORY + resource_name) as Recipe
		if recipe == null or recipe.id == &"":
			push_error("'%s' is not a recipe with an id." % resource_name)
			continue
		if _recipes.has(recipe.id):
			push_error("Duplicate recipe id '%s' in '%s'." % [recipe.id, resource_name])
			continue
		_recipes[recipe.id] = recipe
