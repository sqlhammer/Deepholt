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
	# A chute (D-219, D-220): over a hole, on the hole's own level;
	# items dropped into it land on the level below.
	"CHUTE": 6,
	# A hand winch (D-224, D-225): over a hole, on the hole's own
	# level; cranked from there, it lifts and lowers its crate.
	"WINCH": 7,
	# A winch's crate (D-224): made with it, at the foot of its hole on
	# the level below, or hanging in the hole at the top. It holds
	# items, and is never in a pack.
	"CRATE": 8,
}


# What each kind is called on screen: build mode's cursor and the
# inventory's build section. Presentation text, kept beside the ids so
# a new kind gets its name where it gets its number.
const NAMES: Dictionary = {
	OBJECT.LADDER: "Ladder",
	OBJECT.BRAZIER: "Brazier",
	OBJECT.TIMBER_PROP: "Timber prop",
	OBJECT.TREE: "Tree",
	OBJECT.CHUTE: "Chute",
	OBJECT.WINCH: "Winch",
	OBJECT.CRATE: "Crate",
}

# The kinds that stand over a hole, on the hole's own level (D-219). A
# hole holds one of these, or a ladder under it, never both.
const OVER_HOLE: Array[int] = [OBJECT.CHUTE, OBJECT.WINCH]

# The kinds that keep anyone from walking onto their tile (D-165).
const BLOCKS_WALKING: Array[int] = [OBJECT.TIMBER_PROP, OBJECT.TREE, OBJECT.CRATE]

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


static func is_over_hole(kind: int) -> bool:
	return kind in OVER_HOLE
