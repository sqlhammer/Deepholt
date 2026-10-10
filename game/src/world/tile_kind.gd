class_name TileKind
extends RefCounted

# The ground, top and ore kind ids for slice 001 (D-051, D-052, D-056), 
# gathered into one table per layer so callers -- and tests -- can enumerate
# a layer's valid ids rather than hardcoding them. 

# Values here are the bytes LevelTiles stores; 254 and 255 are reserved
# sentinels (D-059) and must never appear in any of these tables.

const SENTINEL_OUT_OF_ARRAY: int = 255
const SENTINEL_OUT_OF_BOUNDS: int = 254

const GROUND: Dictionary = {
	"NULL": 0,
	"ROCK": 1,
	"DIRT": 2,
	"GRASS": 3,
	"WATER": 4,
	"HOLE": 5,
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

const MINABLE_DENSITY: Dictionary = {
	"MINABLE_ROCK": { "id": TOP.MINABLE_ROCK, "density": 5.0 },
	"MINABLE_DIRT": { "id": TOP.MINABLE_DIRT, "density": 2.0 },
}


static func is_diggable(kind: int) -> bool:
	for key in TileKind.MINABLE_DENSITY:
		if kind == TileKind.MINABLE_DENSITY[key].id:
			return true
	return false


static func get_tile_density(kind: int) -> float:
	for key in TileKind.MINABLE_DENSITY:
		if kind == TileKind.MINABLE_DENSITY[key].id:
			return TileKind.MINABLE_DENSITY[key].density
	return -1.0 # invalid density


static func is_sentinel(kind: int) -> bool:
	return kind == SENTINEL_OUT_OF_ARRAY or kind == SENTINEL_OUT_OF_BOUNDS













