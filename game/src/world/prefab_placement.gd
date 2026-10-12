extends Resource
class_name PrefabPlacement

# One prefab a recipe always stamps into its level, and where: the
# prefab's '0' marker lands on the anchor (D-060, D-084). Named by id
# so the recipe stays a list of references, not copies of the grids.

@export var prefab_id: StringName
@export var anchor: Vector2i = Vector2i.ZERO


func _init(p_prefab_id: StringName = &"", p_anchor: Vector2i = Vector2i.ZERO) -> void:
	prefab_id = p_prefab_id
	anchor = p_anchor
