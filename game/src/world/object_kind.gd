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
}


# The kinds that keep anyone from walking onto their tile (D-165).
const BLOCKS_WALKING: Array[int] = [OBJECT.TIMBER_PROP]

# The kinds that hold a ceiling up (D-163): their tile counts as a
# support for the support rule. A timber prop's R bonus is +0; the
# stronger columns come with their own kinds.
const HOLDS_CEILING: Array[int] = [OBJECT.TIMBER_PROP]


static func blocks_walking(kind: int) -> bool:
	return kind in BLOCKS_WALKING


static func holds_ceiling(kind: int) -> bool:
	return kind in HOLDS_CEILING
