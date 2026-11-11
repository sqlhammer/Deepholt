class_name Recipe
extends Resource

# One thing that can be made (D-222): what it takes and what it makes,
# item id -> count each way, and where it's made. "hand" is anywhere,
# from the inventory's CRAFT tab; a station (a workbench, 016) is
# where a recipe needs one. The id is stable and snake_case, like an
# item's.

const HAND: StringName = &"hand"

@export var id: StringName
@export var display_key: String = ""
# A line for the detail pane, under the name
@export var description: String = ""
@export var inputs: Dictionary[StringName, int] = {}
@export var outputs: Dictionary[StringName, int] = {}
@export var station: StringName = HAND
