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
		ObjectKind.OBJECT.BRAZIER, ObjectKind.OBJECT.TIMBER_PROP, ObjectKind.OBJECT.TREE,
		ObjectKind.OBJECT.CRATE],
	ObjectKind.OBJECT.WORLD_SPAWN: [ObjectKind.OBJECT.WORLD_SPAWN, ObjectKind.OBJECT.LADDER,
		ObjectKind.OBJECT.BRAZIER, ObjectKind.OBJECT.TIMBER_PROP, ObjectKind.OBJECT.TREE,
		ObjectKind.OBJECT.CRATE],
	# A brazier fills its tile: nothing else stands there (D-144)
	ObjectKind.OBJECT.BRAZIER: [ObjectKind.OBJECT.BRAZIER, ObjectKind.OBJECT.LADDER,
		ObjectKind.OBJECT.WORLD_SPAWN, ObjectKind.OBJECT.TIMBER_PROP, ObjectKind.OBJECT.TREE,
		ObjectKind.OBJECT.CRATE],
	# A prop fills its tile too (D-165)
	ObjectKind.OBJECT.TIMBER_PROP: [ObjectKind.OBJECT.TIMBER_PROP, ObjectKind.OBJECT.LADDER,
		ObjectKind.OBJECT.WORLD_SPAWN, ObjectKind.OBJECT.BRAZIER, ObjectKind.OBJECT.TREE,
		ObjectKind.OBJECT.CRATE],
	# And a tree (D-181)
	ObjectKind.OBJECT.TREE: [ObjectKind.OBJECT.TREE, ObjectKind.OBJECT.LADDER,
		ObjectKind.OBJECT.WORLD_SPAWN, ObjectKind.OBJECT.BRAZIER, ObjectKind.OBJECT.TIMBER_PROP,
		ObjectKind.OBJECT.CRATE],
	# One thing over a hole (D-219)
	ObjectKind.OBJECT.CHUTE: ObjectKind.OVER_HOLE,
	ObjectKind.OBJECT.WINCH: ObjectKind.OVER_HOLE,
	# A crate fills its tile, at the foot of its hole (D-224)
	ObjectKind.OBJECT.CRATE: [ObjectKind.OBJECT.CRATE, ObjectKind.OBJECT.LADDER,
		ObjectKind.OBJECT.WORLD_SPAWN, ObjectKind.OBJECT.BRAZIER, ObjectKind.OBJECT.TIMBER_PROP,
		ObjectKind.OBJECT.TREE],
}


# Why a fixture of `kind` can't go on `tile` of a level, or NONE.
# `tiles_above` is the level one depth up, or null if there is none.
# `ignoring` is a fixture already in the store that doesn't count
# against the tile: the one being checked, when a load re-checks what
# it put in (D-113). `fixtures_above` and `fixtures_below` are the
# fixtures one level up and down, or null: a hole holds a ladder under
# it or one thing over it, never both (D-219), and without them that
# rule isn't checked.
static func problem(kind: int, tile: Vector2i, tiles: LevelTiles,
		fixtures: LevelFixtures, tiles_above: LevelTiles,
		ignoring: Fixture = null, fixtures_above: LevelFixtures = null,
		fixtures_below: LevelFixtures = null) -> World.FIXTURE_REFUSAL:
	var top: int = tiles.get_top(tile.x, tile.y)
	var ground: int = tiles.get_ground(tile.x, tile.y)
	if TileKind.is_sentinel(top) or TileKind.is_sentinel(ground):
		return World.FIXTURE_REFUSAL.TILE_NOT_EXISTS
	if ObjectKind.is_over_hole(kind):
		# Over an open hole, on the hole's own level (D-219)
		if ground != TileKind.GROUND.HOLE or top != TileKind.TOP.OPEN:
			return World.FIXTURE_REFUSAL.NEEDS_HOLE
	elif kind == ObjectKind.OBJECT.CRATE and ground == TileKind.GROUND.HOLE:
		# A crate hangs in a hole only under its winch (D-224)
		if not _holds_any(fixtures, tile, [ObjectKind.OBJECT.WINCH]):
			return World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE
	elif not TileKind.is_passable(top, ground):
		return World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE
	# Nothing that blocks walking stands on a ramp: it would wall the
	# way off
	if ObjectKind.blocks_walking(kind) and TileKind.is_ramp(ground):
		return World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE
	for existing: Fixture in fixtures.at(tile):
		if existing == ignoring: continue
		if existing.kind in CONFLICTS.get(kind, []):
			return World.FIXTURE_REFUSAL.TILE_OCCUPIED
	if ObjectKind.is_over_hole(kind) and _holds_any(fixtures_below, tile, [ObjectKind.OBJECT.LADDER]):
		return World.FIXTURE_REFUSAL.HOLE_IN_USE
	if kind == ObjectKind.OBJECT.LADDER:
		if tiles_above == null or tiles_above.get_ground(tile.x, tile.y) != TileKind.GROUND.HOLE:
			return World.FIXTURE_REFUSAL.NO_HOLE_ABOVE
		if _holds_any(fixtures_above, tile, ObjectKind.OVER_HOLE):
			return World.FIXTURE_REFUSAL.HOLE_IN_USE
	return World.FIXTURE_REFUSAL.NONE


# Whether `fixtures` (if any) has one of `kinds` on `tile`.
static func _holds_any(fixtures: LevelFixtures, tile: Vector2i, kinds: Array[int]) -> bool:
	if fixtures == null: return false
	for fixture: Fixture in fixtures.at(tile):
		if fixture.kind in kinds: return true
	return false


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
		var below: Level = by_depth.get(level.depth + 1)
		var tiles_above: LevelTiles = above.level_tiles if above != null else null
		var fixtures_above: LevelFixtures = above.level_fixtures if above != null else null
		var fixtures_below: LevelFixtures = below.level_fixtures if below != null else null
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
				level.level_fixtures, tiles_above, fixture, fixtures_above, fixtures_below)
			if reason != World.FIXTURE_REFUSAL.NONE:
				found.append("%s breaks a placement rule: %s." % [
					where, World.FIXTURE_REFUSAL.find_key(reason)])
	return found
