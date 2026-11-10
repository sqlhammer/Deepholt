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
	# A fixed light (D-144, D-149).
	"BRAZIER": 3,
	# A timber prop (D-165): a support, and it blocks its tile.
	"TIMBER_PROP": 4,
	# A tree on the Surface (D-181): felled with an axe for timber.
	"TREE": 5,
}


# What each kind is called on screen: build mode's cursor and the
# inventory's build section. Presentation text, kept beside the ids so
# a new kind gets its name where it gets its number.
const NAMES: Dictionary = {
	OBJECT.LADDER: "Ladder",
	OBJECT.BRAZIER: "Brazier",
	OBJECT.TIMBER_PROP: "Timber prop",
	OBJECT.TREE: "Tree",
}

# The kinds that keep anyone from walking onto their tile (D-165).
const BLOCKS_WALKING: Array[int] = [OBJECT.TIMBER_PROP, OBJECT.TREE]

# The kinds that hold a ceiling up (D-163): their tile counts as a
# support for the support rule. A timber prop's R bonus is +0; the
# stronger columns come with their own kinds.
const HOLDS_CEILING: Array[int] = [OBJECT.TIMBER_PROP]


static func display_name(kind: int) -> String:
	return NAMES.get(kind, "")


static func blocks_walking(kind: int) -> bool:
	return kind in BLOCKS_WALKING


static func holds_ceiling(kind: int) -> bool:
	return kind in HOLDS_CEILING
