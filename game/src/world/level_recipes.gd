class_name LevelRecipes
extends RefCounted

# The recipe table: one recipe per depth, each holding that level's
# bounds (D-085). Fixed design data, read only to generate, so it
# stays global while the world's state doesn't (D-118, D-124). A
# level's bound, once built, comes from the level itself (D-112).

const TABLE: LevelRecipeTable = preload("res://src/world/level_recipes.tres")
