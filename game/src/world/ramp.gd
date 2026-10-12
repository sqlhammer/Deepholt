class_name Ramp
extends RefCounted

# When stepping onto a tile takes an actor to another level (D-095,
# D-097, D-098). A ramp is a pair of ground kinds at the same (x, y):
# the down end on the upper level, the up end on the level below.
# Its direction is downhill -- the way you move to go down.


# Where an actor goes after stepping onto `tile` having actually moved
# `motion` this tick, or null if the step doesn't take a ramp. Only
# the dominant axis of the motion counts, so a diagonal brushing a
# ramp's corner passes over it as floor. The actor checks the landing
# itself (D-093).
static func target_for(tiles: LevelTiles, tile: WorldPos, motion: Vector2) -> WorldPos:
	var ground: int = tiles.get_ground(tile.x, tile.y)
	if not TileKind.is_ramp(ground): return null

	var moving: Vector2i = dominant_direction(motion)
	if moving == Vector2i.ZERO: return null

	var ramp: Dictionary = TileKind.RAMPS[ground]
	if ramp.down and moving == ramp.downhill:
		return WorldPos.new(tile.x, tile.y, tile.depth + 1)
	if not ramp.down and moving == -ramp.downhill:
		return WorldPos.new(tile.x, tile.y, tile.depth - 1)
	return null


# The single axis a motion mostly moves along, as a unit step. An
# exact diagonal has no dominant axis.
static func dominant_direction(motion: Vector2) -> Vector2i:
	if absf(motion.x) > absf(motion.y):
		return Vector2i(int(signf(motion.x)), 0)
	if absf(motion.y) > absf(motion.x):
		return Vector2i(0, int(signf(motion.y)))
	return Vector2i.ZERO
