class_name TileKind
extends RefCounted

# The ground, top and ore kind ids for slice 001 (D-051, D-052, D-056), 
# gathered into one table per layer so callers -- and tests -- can enumerate
# a layer's valid ids rather than hardcoding them. 

# Values here are the bytes LevelTiles stores; 254 and 255 are reserved
# sentinels (D-059) and must never appear in any of these tables.

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
