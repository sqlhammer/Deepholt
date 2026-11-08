class_name FixturePlacement
extends RefCounted

# The fixture placement rules (D-089, D-103), apart from the
# gatekeeper that enforces them (D-125). Stateless: each takes the
# stores it checks rather than finding them, so generation and a load
# can ask about levels that aren't in the tree, or in a world, yet.

# Which kinds can't share a tile with which (D-103). A kind missing
# from the table conflicts with nothing.
const CONFLICTS: Dictionary = {
	ObjectKind.OBJECT.LADDER: [ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.WORLD_SPAWN,
		ObjectKind.OBJECT.BRAZIER, ObjectKind.OBJECT.TIMBER_PROP],
	ObjectKind.OBJECT.WORLD_SPAWN: [ObjectKind.OBJECT.WORLD_SPAWN, ObjectKind.OBJECT.LADDER,
		ObjectKind.OBJECT.BRAZIER, ObjectKind.OBJECT.TIMBER_PROP],
	# A brazier fills its tile: nothing else stands there (D-144)
	ObjectKind.OBJECT.BRAZIER: [ObjectKind.OBJECT.BRAZIER, ObjectKind.OBJECT.LADDER,
		ObjectKind.OBJECT.WORLD_SPAWN, ObjectKind.OBJECT.TIMBER_PROP],
	# A prop fills its tile too (D-165)
	ObjectKind.OBJECT.TIMBER_PROP: [ObjectKind.OBJECT.TIMBER_PROP, ObjectKind.OBJECT.LADDER,
		ObjectKind.OBJECT.WORLD_SPAWN, ObjectKind.OBJECT.BRAZIER],
}


# Why a fixture of `kind` can't go on `tile` of a level, or NONE.
# `tiles_above` is the level one depth up, or null if there is none.
# `ignoring` is a fixture already in the store that doesn't count
# against the tile: the one being checked, when a load re-checks what
# it put in (D-113).
static func problem(kind: int, tile: Vector2i, tiles: LevelTiles,
		fixtures: LevelFixtures, tiles_above: LevelTiles,
		ignoring: Fixture = null) -> World.FIXTURE_REFUSAL:
	var top: int = tiles.get_top(tile.x, tile.y)
	var ground: int = tiles.get_ground(tile.x, tile.y)
	if TileKind.is_sentinel(top) or TileKind.is_sentinel(ground):
		return World.FIXTURE_REFUSAL.TILE_NOT_EXISTS
	if not TileKind.is_passable(top, ground):
		return World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE
	# A prop is not set on a ramp: it would wall the way off
	if kind == ObjectKind.OBJECT.TIMBER_PROP and TileKind.is_ramp(ground):
		return World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE
	for existing: Fixture in fixtures.at(tile):
		if existing == ignoring: continue
		if existing.kind in CONFLICTS.get(kind, []):
			return World.FIXTURE_REFUSAL.TILE_OCCUPIED
	if kind == ObjectKind.OBJECT.LADDER:
		if tiles_above == null or tiles_above.get_ground(tile.x, tile.y) != TileKind.GROUND.HOLE:
			return World.FIXTURE_REFUSAL.NO_HOLE_ABOVE
	return World.FIXTURE_REFUSAL.NONE


# Every fixture already on `levels` that the rules wouldn't allow
# there now, as one line each, plus any kind id this build doesn't
# know and any id two fixtures share. A report, for a load (D-113):
# nothing is removed.
static func problems(levels: Array[Level]) -> Array[String]:
	var by_depth: Dictionary[int, Level] = {}
	for level: Level in levels:
		by_depth[level.depth] = level

	var found: Array[String] = []
	var seen_ids: Dictionary[int, Fixture] = {}
	for level: Level in levels:
		var above: Level = by_depth.get(level.depth - 1)
		var tiles_above: LevelTiles = above.level_tiles if above != null else null
		for fixture: Fixture in level.level_fixtures.all():
			var where: String = "Fixture %s" % fixture
			if fixture.kind == ObjectKind.OBJECT.NULL \
					or fixture.kind not in ObjectKind.OBJECT.values():
				found.append("%s has a kind this build doesn't know." % where)
			if seen_ids.has(fixture.id):
				found.append("%s shares its id with %s." % [where, seen_ids[fixture.id]])
			seen_ids[fixture.id] = fixture
			var reason: World.FIXTURE_REFUSAL = problem(fixture.kind,
				Vector2i(fixture.tile.x, fixture.tile.y), level.level_tiles,
				level.level_fixtures, tiles_above, fixture)
			if reason != World.FIXTURE_REFUSAL.NONE:
				found.append("%s breaks a placement rule: %s." % [
					where, World.FIXTURE_REFUSAL.find_key(reason)])
	return found
