extends Resource
class_name PrefabPlacement

# One prefab a recipe always stamps into its level, and where: the
# prefab's '0' marker lands on the anchor (D-060, D-084). Named by id
# so the recipe stays a list of references, not copies of the grids.

@export var prefab_id: StringName
@export var anchor: Vector2i = Vector2i.ZERO
# Non-zero makes this the start placement: the generator puts the
# world's default spawn on a random passable tile within this many
# tiles of the anchor (D-091, D-092). 0 means no spawn here.
@export var spawn_radius: int = 0


func _init(p_prefab_id: StringName = &"", p_anchor: Vector2i = Vector2i.ZERO,
		p_spawn_radius: int = 0) -> void:
	prefab_id = p_prefab_id
	anchor = p_anchor
	spawn_radius = p_spawn_radius
