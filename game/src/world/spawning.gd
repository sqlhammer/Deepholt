class_name Spawning
extends RefCounted

# Where an actor appears (D-091, D-105). An actor spawns at its own
# spawn point if it has one (beds, later), otherwise at the world's
# default spawn; and if someone is already standing there, on the
# nearest free tile around it. Deterministic: no random jitter.
#
# Takes the levels and the actors as parameters rather than finding
# them, so nothing here resolves to "the" player (D-045).

# How far out the search for a free tile goes before giving up.
const MAX_RING: int = 16


# The world's default spawn: the one WORLD_SPAWN fixture on any level.
# None, or more than one, is reported and gives null.
static func world_spawn(levels: Array[Level]) -> Fixture:
	var found: Array[Fixture] = []
	for level: Level in levels:
		found.append_array(level.level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN))
	if found.size() != 1:
		push_error("Expected one world spawn, found %d." % found.size())
		return null
	return found[0]


# The tile an actor should appear on. `own_spawn` is the actor's own
# spawn point, or null to use the world's default. Null if there is
# nowhere to spawn.
static func spawn_tile_for(own_spawn: WorldPos, levels: Array[Level], actors: Array[Actor]) -> WorldPos:
	var start: WorldPos = own_spawn
	if start == null:
		var spawn: Fixture = world_spawn(levels)
		if spawn == null: return null
		start = spawn.tile
	for level: Level in levels:
		if level.depth == start.depth:
			return free_tile_near(start, level.level_tiles, actors)
	push_error("No level at depth %d to spawn on." % start.depth)
	return null


# The nearest tile to `start`, ring by ring, that an actor could stand
# on, isn't a ramp, and has no actor's feet in it. Only actors on the
# same depth count: someone at the same (x, y) on another level isn't
# in the way. Within a ring, tiles are tried row by row, then column.
static func free_tile_near(start: WorldPos, tiles: LevelTiles, actors: Array[Actor]) -> WorldPos:
	for ring in range(0, MAX_RING + 1):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring: continue
				var tile: Vector2i = Vector2i(start.x + dx, start.y + dy)
				if _is_free(tile, start.depth, tiles, actors):
					return WorldPos.new(tile.x, tile.y, start.depth)
	push_error("No free tile within %d of %s." % [MAX_RING, start])
	return null


static func _is_free(tile: Vector2i, depth: int, tiles: LevelTiles, actors: Array[Actor]) -> bool:
	var ground: int = tiles.get_ground(tile.x, tile.y)
	if not TileKind.is_passable(tiles.get_top(tile.x, tile.y), ground): return false
	if TileKind.is_ramp(ground): return false
	var tile_rect: Rect2 = Rect2(Vector2(tile * TileSpace.TILE_PIXELS),
		Vector2(TileSpace.TILE_PIXELS, TileSpace.TILE_PIXELS))
	for actor: Actor in actors:
		if actor.depth == depth and actor.get_world_box().intersects(tile_rect):
			return false
	return true
