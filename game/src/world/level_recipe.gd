extends Resource
class_name LevelRecipe

# Everything about one depth, in one place (D-084, D-085): its shape
# now, and how it is filled once the level generator exists. The
# shape is a LevelBound of its own so tile storage, and later a
# save, can know a level's shape without knowing its recipe.

@export var bound: LevelBound


func _init(p_bound: LevelBound = null) -> void:
	bound = p_bound
