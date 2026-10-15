class_name Ladder
extends RefCounted

# Where interacting takes an actor by ladder (D-089, D-100, D-101). A
# ladder is a fixture on the lower level, under a hole on the level
# above. This answers *where*; the actor makes the move (D-093). Asking
# is a read, so neither gatekeeper is involved.
#
#   down: beside a hole, facing it, with a ladder under it -> onto the
#         ladder's tile below, same (x, y).
#   up:   standing on a ladder -> beside the hole above: the faced side
#         if an actor can stand there, otherwise the first that works
#         in the order north, east, south, west.
#
# If an actor stands on a ladder *and* faces a hole with another ladder
# under it, up is checked first. That isn't a decision yet (D-106): it
# needs two ladders in neighboring shafts, which can't exist until −3
# does.

const ARRIVAL_ORDER: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


# Where interact takes an actor standing on `here` and facing `facing`,
# or null if it doesn't take a ladder.
static func target_for(here: WorldPos, facing: Vector2i) -> WorldPos:
	var level: Level = World.get_level_by_depth(here.depth)
	if level == null: return null
	var tile: Vector2i = Vector2i(here.x, here.y)

	if level.level_fixtures.has_kind_at(tile, ObjectKind.OBJECT.LADDER):
		return _up(here, facing)
	return _down(level, here, facing)


static func _down(level: Level, here: WorldPos, facing: Vector2i) -> WorldPos:
	var faced: Vector2i = Vector2i(here.x, here.y) + facing
	if level.level_tiles.get_ground(faced.x, faced.y) != TileKind.GROUND.HOLE: return null
	var below: Level = World.get_level_by_depth(here.depth + 1)
	if below == null: return null
	if not below.level_fixtures.has_kind_at(faced, ObjectKind.OBJECT.LADDER): return null
	return WorldPos.new(faced.x, faced.y, here.depth + 1)


static func _up(here: WorldPos, facing: Vector2i) -> WorldPos:
	var above: Level = World.get_level_by_depth(here.depth - 1)
	if above == null: return null
	var tiles: LevelTiles = above.level_tiles
	if tiles.get_ground(here.x, here.y) != TileKind.GROUND.HOLE: return null

	var sides: Array[Vector2i] = []
	if facing != Vector2i.ZERO: sides.append(facing)
	for side: Vector2i in ARRIVAL_ORDER:
		if side not in sides: sides.append(side)

	for side: Vector2i in sides:
		var tile: Vector2i = Vector2i(here.x, here.y) + side
		var ground: int = tiles.get_ground(tile.x, tile.y)
		if TileKind.is_passable(tiles.get_top(tile.x, tile.y), ground) and not TileKind.is_ramp(ground):
			return WorldPos.new(tile.x, tile.y, here.depth - 1)
	return null
