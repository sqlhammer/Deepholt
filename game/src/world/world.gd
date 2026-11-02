class_name World
extends Node2D

# One whole world (D-118): its levels by depth, its actors, its seed
# and its id counters, as one node. It is handed by reference to what
# needs it, and reached through a level (`level.world`, D-126);
# nothing finds it by searching the tree. Built outside the tree by
# the generator or a load (D-127), and put at the origin inside the
# game viewport, so the transforms between a level and an actor stay
# the identity (D-128).
#
# It is also both gatekeepers (D-125): the only thing that changes
# tiles at runtime (D-078) and the only thing that places or removes
# fixtures once the world exists (D-090). Anything wanting a change
# emits a request on the world it was handed, and hears the outcome
# from the same world. Generation and a load fill levels' stores
# directly, before anything listens.
#
# `actor` may be null in every signal: no actor is behind a generated
# or collapsed fixture.

signal dig_requested(actor: Actor, tile: WorldPos)
signal tile_dug(actor: Actor, tile: WorldPos)
signal dig_refused(actor: Actor, tile: WorldPos, reason: DIG_REFUSAL)

signal place_requested(actor: Actor, kind: int, tile: WorldPos)
signal remove_requested(actor: Actor, fixture_id: int)
signal move_requested(actor: Actor, fixture_id: int, to: WorldPos)
signal fixture_placed(actor: Actor, fixture: Fixture)
signal fixture_removed(actor: Actor, fixture: Fixture)
# The same fixture, same id, on another tile (D-138)
signal fixture_moved(actor: Actor, fixture: Fixture, from: WorldPos)
signal request_refused(actor: Actor, verb: FIXTURE_VERB, tile: WorldPos, reason: FIXTURE_REFUSAL)

# Why a dig was refused.
enum DIG_REFUSAL {
	NONE,
	LEVEL_NOT_EXISTS,
	TILE_NOT_EXISTS,
	TILE_NOT_DIGGABLE,
}

enum FIXTURE_VERB {
	PLACE,
	REMOVE,
	MOVE,
}

# Why a fixture request was refused, or why a placement breaks a rule
# (FixturePlacement).
enum FIXTURE_REFUSAL {
	NONE,
	LEVEL_NOT_EXISTS,
	TILE_NOT_EXISTS,
	TILE_NOT_PASSABLE,
	NO_HOLE_ABOVE,
	TILE_OCCUPIED,
	FIXTURE_NOT_EXISTS,
}

var world_seed: int
# World-wide, so an id alone finds a fixture or an actor (D-104,
# D-114). Each world numbers its own: generating or loading another
# never resets these (D-118).
var fixture_ids: IdAllocator = IdAllocator.new()
var actor_ids: IdAllocator = IdAllocator.new()
# The numbers this world runs under (D-135). Each world holds its own,
# so two worlds can run under different profiles.
var tuning: TuningProfile

var _levels: Dictionary[int, Level] = {}
var _levels_node: Node2D
var _players_node: Node2D
var _npcs_node: Node2D


# The children are built here, not in a scene, so a world made with
# World.new() is whole before it is ever in the tree. With no profile
# given, it runs under the default.
func _init(p_tuning: TuningProfile = null) -> void:
	tuning = p_tuning if p_tuning != null else TuningProfile.default_profile()
	name = "World"
	_levels_node = Node2D.new()
	_levels_node.name = "Levels"
	add_child(_levels_node)
	var actors_node: Node2D = Node2D.new()
	actors_node.name = "Actors"
	actors_node.y_sort_enabled = true
	add_child(actors_node)
	_players_node = Node2D.new()
	_players_node.name = "Players"
	actors_node.add_child(_players_node)
	_npcs_node = Node2D.new()
	_npcs_node.name = "NPCs"
	actors_node.add_child(_npcs_node)

	dig_requested.connect(_on_dig_requested)
	place_requested.connect(_on_place_requested)
	remove_requested.connect(_on_remove_requested)
	move_requested.connect(_on_move_requested)


# Takes a level in, and tells it which world it belongs to (D-126).
# One level per depth; a second at a depth already held is refused.
func add_level(level: Level) -> bool:
	if _levels.has(level.depth):
		push_error("This world already has a level at depth %d." % level.depth)
		return false
	level.world = self
	_levels[level.depth] = level
	_levels_node.add_child(level)
	return true


# The level at a depth, or null if this world has none there.
func level_at(depth: int) -> Level:
	return _levels.get(depth)


# Every level, shallowest first.
func levels() -> Array[Level]:
	var depths: Array[int] = []
	depths.assign(_levels.keys())
	depths.sort()
	var found: Array[Level] = []
	for depth: int in depths:
		found.append(_levels[depth])
	return found


# Takes an actor in, as a player or an NPC by its kind. The actor
# must already stand on one of this world's levels.
func add_actor(actor: Actor) -> void:
	assert(actor.current_level != null and actor.current_level.world == self,
		"An actor joins the world whose level it stands on.")
	if actor.actor_kind == ActorKind.ACTOR.PLAYER:
		_players_node.add_child(actor)
	else:
		_npcs_node.add_child(actor)


# Every actor in the world, players first, each in the order added.
# Read from the nodes, so a freed actor is simply gone.
func actors() -> Array[Actor]:
	var found: Array[Actor] = players()
	found.append_array(_actors_under(_npcs_node))
	return found


func players() -> Array[Actor]:
	return _actors_under(_players_node)


func _actors_under(parent: Node) -> Array[Actor]:
	var found: Array[Actor] = []
	for child: Node in parent.get_children():
		if child is Actor and not child.is_queued_for_deletion():
			found.append(child)
	return found


# Whether a tile is inside its level's radial bound. The level's own
# bound, not the recipe's: a saved bound wins (D-112).
func is_in_bounds(pos: WorldPos) -> bool:
	var level: Level = level_at(pos.depth)
	if level == null: return false
	var distance: float = Vector2.ZERO.distance_to(Vector2(pos.x, pos.y))
	return distance <= level.level_tiles.level_bound.radius


# --- tiles (D-078) ---

func _on_dig_requested(actor: Actor, tile: WorldPos) -> void:
	# The request is a claim from the past: check the tile as it is now
	var reason: DIG_REFUSAL = _dig_problem(tile)
	if reason != DIG_REFUSAL.NONE:
		dig_refused.emit(actor, tile, reason)
		return
	_dig_tile(actor, tile)


func _dig_problem(tile: WorldPos) -> DIG_REFUSAL:
	var level: Level = level_at(tile.depth)
	if level == null:
		return DIG_REFUSAL.LEVEL_NOT_EXISTS
	var kind: int = level.level_tiles.get_top(tile.x, tile.y)
	if TileKind.is_sentinel(kind):
		return DIG_REFUSAL.TILE_NOT_EXISTS
	if not TileKind.is_diggable(kind):
		return DIG_REFUSAL.TILE_NOT_DIGGABLE
	return DIG_REFUSAL.NONE


# Every request ends in exactly one answer, so a level gone between
# the check and the change is a refusal, not silence.
func _dig_tile(actor: Actor, tile: WorldPos) -> void:
	var level: Level = level_at(tile.depth)
	if level == null:
		push_error("Tile at %s is missing. Cannot complete the dig." % tile)
		dig_refused.emit(actor, tile, DIG_REFUSAL.LEVEL_NOT_EXISTS)
		return
	level.level_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)
	level.level_tiles.set_ore(tile.x, tile.y, TileKind.ORE.NONE)
	tile_dug.emit(actor, tile)


# --- fixtures (D-090, D-100, D-103) ---

func _on_place_requested(actor: Actor, kind: int, tile: WorldPos) -> void:
	var level: Level = level_at(tile.depth)
	if level == null:
		request_refused.emit(actor, FIXTURE_VERB.PLACE, tile, FIXTURE_REFUSAL.LEVEL_NOT_EXISTS)
		return

	var above: Level = level_at(tile.depth - 1)
	var tiles_above: LevelTiles = above.level_tiles if above != null else null
	var reason: FIXTURE_REFUSAL = FixturePlacement.problem(
		kind, Vector2i(tile.x, tile.y), level.level_tiles, level.level_fixtures, tiles_above)
	if reason != FIXTURE_REFUSAL.NONE:
		request_refused.emit(actor, FIXTURE_VERB.PLACE, tile, reason)
		return

	var fixture: Fixture = Fixture.new(kind, tile, fixture_ids.allocate())
	level.level_fixtures.add(fixture)
	fixture_placed.emit(actor, fixture)


func _on_remove_requested(actor: Actor, fixture_id: int) -> void:
	for level: Level in levels():
		var fixture: Fixture = level.level_fixtures.remove(fixture_id)
		if fixture != null:
			fixture_removed.emit(actor, fixture)
			return
	request_refused.emit(actor, FIXTURE_VERB.REMOVE, null, FIXTURE_REFUSAL.FIXTURE_NOT_EXISTS)


# Checked by the placement rules at `to`, as a placement would be,
# with the fixture itself not counting against its own new tile
# (D-138). Within a level the store re-files it; between depths it
# leaves one store and joins the other.
func _on_move_requested(actor: Actor, fixture_id: int, to: WorldPos) -> void:
	var source: Level = _level_holding(fixture_id)
	if source == null:
		request_refused.emit(actor, FIXTURE_VERB.MOVE, to, FIXTURE_REFUSAL.FIXTURE_NOT_EXISTS)
		return
	var target: Level = level_at(to.depth)
	if target == null:
		request_refused.emit(actor, FIXTURE_VERB.MOVE, to, FIXTURE_REFUSAL.LEVEL_NOT_EXISTS)
		return

	var fixture: Fixture = source.level_fixtures.find(fixture_id)
	var above: Level = level_at(to.depth - 1)
	var tiles_above: LevelTiles = above.level_tiles if above != null else null
	var reason: FIXTURE_REFUSAL = FixturePlacement.problem(fixture.kind,
		Vector2i(to.x, to.y), target.level_tiles, target.level_fixtures, tiles_above, fixture)
	if reason != FIXTURE_REFUSAL.NONE:
		request_refused.emit(actor, FIXTURE_VERB.MOVE, to, reason)
		return

	var from: WorldPos = fixture.tile
	if source == target:
		source.level_fixtures.move(fixture_id, to)
	else:
		source.level_fixtures.remove(fixture_id)
		target.level_fixtures.receive(fixture, to)
	fixture_moved.emit(actor, fixture, from)


func _level_holding(fixture_id: int) -> Level:
	for level: Level in levels():
		if level.level_fixtures.find(fixture_id) != null: return level
	return null
