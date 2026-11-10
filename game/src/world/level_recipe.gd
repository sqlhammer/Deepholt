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
# A level's own generation, run around its fixed placements: "surface"
# for the Surface's meadow, rock, road and trees (D-180); "" for none.
@export var generator: StringName = &""
# The cave prefabs this level draws its natural caves from (D-184);
# none for a level without caves. How many, and how far apart, are the
# profile's.
@export var cave_prefabs: Array[StringName] = []


func _init(p_bound: LevelBound = null) -> void:
	bound = p_bound
