extends Node

# The Objects autoload: the only thing that places or removes fixtures
# once the world exists (D-090, D-100, D-103). Anything wanting a change
# sends a request; Objects re-checks the rules, changes the level's
# LevelFixtures (which announces fixture_changed to presentation), and
# then announces the outcome. Like World for tiles (D-078).
#
# Generation places fixtures straight into a level's store, before the
# level is in the tree (D-091): it uses placement_problem() for the
# rules and next_id() for ids, but not the request signals.
#
# `actor` may be null: no actor is behind a generated or collapsed
# fixture.

signal place_requested(actor: Actor, kind: int, tile: WorldPos)
signal remove_requested(actor: Actor, fixture_id: int)
signal fixture_placed(actor: Actor, fixture: Fixture)
signal fixture_removed(actor: Actor, fixture: Fixture)
signal request_refused(actor: Actor, verb: VERB, tile: WorldPos, reason: REFUSAL_REASON)

enum VERB {
	PLACE,
	REMOVE,
}

enum REFUSAL_REASON {
	NONE,
	LEVEL_NOT_EXISTS,
	TILE_NOT_EXISTS,
	TILE_NOT_PASSABLE,
	NO_HOLE_ABOVE,
	TILE_OCCUPIED,
	FIXTURE_NOT_EXISTS,
}

# Which kinds can't share a tile with which (D-103). A kind missing from
# the table conflicts with nothing.
const CONFLICTS: Dictionary = {
	ObjectKind.OBJECT.LADDER: [ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.WORLD_SPAWN],
	ObjectKind.OBJECT.WORLD_SPAWN: [ObjectKind.OBJECT.WORLD_SPAWN, ObjectKind.OBJECT.LADDER],
}

const FIRST_ID: int = 1

# World-wide, so an id alone finds a fixture. Reset when a new world is
# generated (D-104), so the same seed gives the same ids. Saved with
# the world once saves exist (slice 004).
var _next_fixture_id: int = FIRST_ID


func _ready() -> void:
	place_requested.connect(_on_place_requested)
	remove_requested.connect(_on_remove_requested)


func next_id() -> int:
	var id: int = _next_fixture_id
	_next_fixture_id += 1
	return id


func reset_ids() -> void:
	_next_fixture_id = FIRST_ID


# Why a fixture of `kind` can't go on `tile` of a level, or NONE. Takes
# the level's stores rather than finding them, so generation can ask it
# about levels that aren't in the tree yet. `tiles_above` is the level
# one depth up, or null if there is none. `ignoring` is a fixture
# already in the store that doesn't count against the tile: the one
# being checked, when a load re-checks what it put in (D-113).
static func placement_problem(kind: int, tile: Vector2i, tiles: LevelTiles,
		fixtures: LevelFixtures, tiles_above: LevelTiles,
		ignoring: Fixture = null) -> REFUSAL_REASON:
	var top: int = tiles.get_top(tile.x, tile.y)
	var ground: int = tiles.get_ground(tile.x, tile.y)
	if TileKind.is_sentinel(top) or TileKind.is_sentinel(ground):
		return REFUSAL_REASON.TILE_NOT_EXISTS
	if not TileKind.is_passable(top, ground):
		return REFUSAL_REASON.TILE_NOT_PASSABLE
	for existing: Fixture in fixtures.at(tile):
		if existing == ignoring: continue
		if existing.kind in CONFLICTS.get(kind, []):
			return REFUSAL_REASON.TILE_OCCUPIED
	if kind == ObjectKind.OBJECT.LADDER:
		if tiles_above == null or tiles_above.get_ground(tile.x, tile.y) != TileKind.GROUND.HOLE:
			return REFUSAL_REASON.NO_HOLE_ABOVE
	return REFUSAL_REASON.NONE


# Every fixture already on `levels` that the placement rules wouldn't
# allow there now, as one line each, plus any kind id this build
# doesn't know and any id two fixtures share. A report, for a load
# (D-113): nothing is removed. Takes the levels, so it works on a
# world that isn't in the tree.
func placement_problems(levels: Array[Level]) -> Array[String]:
	var by_depth: Dictionary[int, Level] = {}
	for level: Level in levels:
		by_depth[level.depth] = level

	var problems: Array[String] = []
	var seen_ids: Dictionary[int, Fixture] = {}
	for level: Level in levels:
		var above: Level = by_depth.get(level.depth - 1)
		var tiles_above: LevelTiles = above.level_tiles if above != null else null
		for fixture: Fixture in level.level_fixtures.all():
			var where: String = "Fixture %s" % fixture
			if fixture.kind == ObjectKind.OBJECT.NULL \
					or fixture.kind not in ObjectKind.OBJECT.values():
				problems.append("%s has a kind this build doesn't know." % where)
			if seen_ids.has(fixture.id):
				problems.append("%s shares its id with %s." % [where, seen_ids[fixture.id]])
			seen_ids[fixture.id] = fixture
			var reason: REFUSAL_REASON = placement_problem(fixture.kind,
				Vector2i(fixture.tile.x, fixture.tile.y), level.level_tiles,
				level.level_fixtures, tiles_above, fixture)
			if reason != REFUSAL_REASON.NONE:
				problems.append("%s breaks a placement rule: %s." % [
					where, REFUSAL_REASON.find_key(reason)])
	return problems


func _on_place_requested(actor: Actor, kind: int, tile: WorldPos) -> void:
	var level: Level = World.get_level_by_depth(tile.depth)
	if level == null:
		request_refused.emit(actor, VERB.PLACE, tile, REFUSAL_REASON.LEVEL_NOT_EXISTS)
		return

	var above: Level = World.get_level_by_depth(tile.depth - 1)
	var tiles_above: LevelTiles = above.level_tiles if above != null else null
	var reason: REFUSAL_REASON = placement_problem(
		kind, Vector2i(tile.x, tile.y), level.level_tiles, level.level_fixtures, tiles_above)
	if reason != REFUSAL_REASON.NONE:
		request_refused.emit(actor, VERB.PLACE, tile, reason)
		return

	var fixture: Fixture = Fixture.new(kind, tile, next_id())
	level.level_fixtures.add(fixture)
	fixture_placed.emit(actor, fixture)


func _on_remove_requested(actor: Actor, fixture_id: int) -> void:
	for level: Level in get_tree().get_nodes_in_group("levels"):
		var fixture: Fixture = level.level_fixtures.remove(fixture_id)
		if fixture != null:
			fixture_removed.emit(actor, fixture)
			return
	request_refused.emit(actor, VERB.REMOVE, null, REFUSAL_REASON.FIXTURE_NOT_EXISTS)
