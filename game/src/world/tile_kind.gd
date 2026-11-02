class_name TileKind
extends RefCounted

# The ground, top and ore kind ids for slice 001 (D-051, D-052,
# D-056), gathered into one table per layer so callers -- and tests --
# can enumerate a layer's valid ids rather than hardcoding them.

# Values here are the bytes LevelTiles stores; 254 and 255 are
# reserved sentinels (D-059) and must never appear in any of these
# tables.

# Enums and Dictionaries must always have explicit values, never be
# reordered, and protected against saved games that use TileKind from
# mutating due to software updates.

const SENTINEL_OUT_OF_ARRAY: int = 255
const SENTINEL_OUT_OF_BOUNDS: int = 254

const GROUND: Dictionary = {
	"NULL": 0,
	"ROCK": 1,
	"DIRT": 2,
	"GRASS": 3,
	"WATER": 4,
	"HOLE": 5,
	# Ramps (D-095, D-096): a pair per direction, interleaved so each
	# pair's two ends are adjacent. The direction is downhill -- the
	# way you move to go down (D-097).
	"RAMP_DOWN_N": 6,
	"RAMP_UP_N": 7,
	"RAMP_DOWN_E": 8,
	"RAMP_UP_E": 9,
	"RAMP_DOWN_S": 10,
	"RAMP_UP_S": 11,
	"RAMP_DOWN_W": 12,
	"RAMP_UP_W": 13,
}

# Every ramp kind: its downhill direction, and whether it is the end
# you take down (on the upper level) or up (on the lower). The one
# owner of what a ramp is; Ramp and the generator's checks read it.
const RAMPS: Dictionary = {
	GROUND.RAMP_DOWN_N: { "downhill": Vector2i(0, -1), "down": true },
	GROUND.RAMP_UP_N: { "downhill": Vector2i(0, -1), "down": false },
	GROUND.RAMP_DOWN_E: { "downhill": Vector2i(1, 0), "down": true },
	GROUND.RAMP_UP_E: { "downhill": Vector2i(1, 0), "down": false },
	GROUND.RAMP_DOWN_S: { "downhill": Vector2i(0, 1), "down": true },
	GROUND.RAMP_UP_S: { "downhill": Vector2i(0, 1), "down": false },
	GROUND.RAMP_DOWN_W: { "downhill": Vector2i(-1, 0), "down": true },
	GROUND.RAMP_UP_W: { "downhill": Vector2i(-1, 0), "down": false },
}

const TOP: Dictionary = {
	"NULL": 0,
	"OPEN": 1,
	"MINABLE_ROCK": 2,
	"MINABLE_DIRT": 3,
	"IMPENETRABLE_ROCK": 4,
}

const ORE: Dictionary = {
	"NULL": 0,
	"NONE": 1,
	"COPPER": 2,
}

# The top kinds that can be dug: the one owner of "diggable". How hard
# each is belongs to the kind (D-081), and the number is the tuning
# profile's (D-135), so every kind here needs a hardness in every
# profile.
const DIGGABLE: Array[int] = [TOP.MINABLE_ROCK, TOP.MINABLE_DIRT]


static func is_diggable(kind: int) -> bool:
	return kind in DIGGABLE


static func is_ramp(ground_kind: int) -> bool:
	return RAMPS.has(ground_kind)


# The other end of a ramp kind: the up end for a down end, and back.
# -1 for a kind that isn't a ramp.
static func ramp_pair(ground_kind: int) -> int:
	if not is_ramp(ground_kind): return -1
	for kind: int in RAMPS:
		if kind == ground_kind: continue
		if RAMPS[kind].downhill == RAMPS[ground_kind].downhill:
			return kind
	return -1


# The one side of a ramp end you can cross (D-099), as a step from the
# ramp tile to its open neighbor: a down end opens uphill, where you
# walk in to go down; an up end opens downhill, where you walk in to
# go up. Zero for a kind that isn't a ramp.
static func ramp_open_side(ground_kind: int) -> Vector2i:
	if not is_ramp(ground_kind): return Vector2i.ZERO
	var ramp: Dictionary = RAMPS[ground_kind]
	return -ramp.downhill if ramp.down else ramp.downhill


static func is_sentinel(kind: int) -> bool:
	return kind == SENTINEL_OUT_OF_ARRAY or kind == SENTINEL_OUT_OF_BOUNDS


static func is_passable(top_kind: int, ground_kind: int) -> bool:
	if is_sentinel(top_kind) or is_sentinel(ground_kind):
		return false
	
	match top_kind: # allowlist
		TileKind.TOP.OPEN: pass
		_: return false
	match ground_kind: # blocklist
		TileKind.GROUND.HOLE: return false
		_: pass
	
	return true



















