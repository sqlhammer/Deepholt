class_name ObjectKind
extends RefCounted

# Type ids for objects placed on a level (D-089, D-090). A save will
# store these numbers, so -- like TileKind -- every id is explicit,
# never reordered, and never reused once retired.

const OBJECT: Dictionary = {
	"NULL": 0,
	"LADDER": 1,
	# The world's default spawn point (D-091, D-092). Invisible.
	"WORLD_SPAWN": 2,
}
