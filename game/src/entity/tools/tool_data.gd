class_name ToolData
extends Resource

# What a tool does when it digs (D-081, D-168): its class and its
# power. A tool's weight, name in a pack and stack are its Item's
# (D-169), which points here, so power has one owner (slice 011
# trap 2). Bare hands is a ToolData with no Item: what an empty
# hotbar slot holds (D-171).

# A tool's class (content-schema §3). Saved nowhere: a tool is saved
# as its item's id, so these may be renumbered until something saves
# them.
enum CLASS {
	NULL,
	BARE_HANDS,
	PICK,
	SHOVEL,
	AXE,
}

@export var tool_name: String = ""
@export var verb: String = ""
@export var tier: int = 0
@export var tool_class: CLASS = CLASS.NULL
# Work per second against a tile's hardness (tuning appendix §4):
# dig seconds = hardness / (power x the class's multiplier for the
# kind).
@export var power: float = 0.0
