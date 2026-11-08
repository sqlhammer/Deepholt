class_name Ladder
extends RefCounted

# Where interacting takes an actor by ladder (D-089, D-100, D-101). A
# ladder is a fixture on the lower level, under a hole on the level
# above. This answers *where*; the actor makes the move (D-093).
# Asking is a read, so neither gatekeeper is involved.
#
#   down: beside a hole, facing it, with a ladder under it -> onto the
#         ladder's tile below, same (x, y).
#   up:   standing on a ladder -> beside the hole above: the faced
#         side if an actor can stand there, otherwise the first that
#         works in the order north, east, south, west.
#
# If an actor stands on a ladder *and* faces a hole with another
# ladder under it, it goes down: facing the hole is the choice, and
# turning away from it climbs (D-139).

const ARRIVAL_ORDER: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


# Whether a load lets an actor climb a ladder at all (D-030, D-159):
# past the profile's limit (150%), it can't. Ramps don't ask.
static func can_climb(tuning: TuningProfile, load_ratio: float) -> bool:
	return load_ratio <= tuning.ladder_load_limit


# Where interact takes an actor standing on `here`, on `level`, and
# facing `facing`, or null if it doesn't take a ladder. The levels
# above and below come from the level's world (D-126).
static func target_for(level: Level, here: WorldPos, facing: Vector2i) -> WorldPos:
	if level == null: return null
	if level.world == null:
		push_error("Level %d is in no world, so its ladders lead nowhere." % level.depth)
		return null
	var down: WorldPos = _down(level, here, facing)
	if down != null: return down
	if level.level_fixtures.has_kind_at(Vector2i(here.x, here.y), ObjectKind.OBJECT.LADDER):
		return _up(level.world, here, facing)
	return null


static func _down(level: Level, here: WorldPos, facing: Vector2i) -> WorldPos:
	var faced: Vector2i = Vector2i(here.x, here.y) + facing
	if level.level_tiles.get_ground(faced.x, faced.y) != TileKind.GROUND.HOLE: return null
	var below: Level = level.world.level_at(here.depth + 1)
	if below == null: return null
	if not below.level_fixtures.has_kind_at(faced, ObjectKind.OBJECT.LADDER): return null
	return WorldPos.new(faced.x, faced.y, here.depth + 1)


static func _up(world: World, here: WorldPos, facing: Vector2i) -> WorldPos:
	var above: Level = world.level_at(here.depth - 1)
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
