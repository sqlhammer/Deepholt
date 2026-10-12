extends Resource
class_name LevelRecipe

# Everything about one depth, in one place (D-084, D-085): its shape,
# and how the level generator fills it. The shape is a LevelBound of
# its own so tile storage, and later a save, can know a level's shape
# without knowing its recipe.

@export var bound: LevelBound

# Prefabs this level always has, stamped in order before anything
# placed by rules (D-084).
@export var fixed_placements: Array[PrefabPlacement] = []


func _init(p_bound: LevelBound = null) -> void:
	bound = p_bound
