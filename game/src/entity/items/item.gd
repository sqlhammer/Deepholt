class_name Item
extends Resource

# One kind of thing a pack can hold (content-schema §3, D-157). The id
# is stable and snake_case, never reused or renamed: saves store it.
# trade_value / weight_kg is what will sort a pack by value density
# (ui-ux §5), so both are mandatory on every item.

@export var id: StringName
@export var display_key: String = ""
@export var weight_kg: float = 0.0
@export var stack_max: int = 0
@export var trade_value: float = 0.0
@export var tags: Array[StringName] = []
