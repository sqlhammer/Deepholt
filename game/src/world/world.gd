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

# A level joined this world: at creation, from a load, or generated
# as an actor arrived above it (D-143). Anything that draws the level
# below the shown one listens, since it can arrive after the shown one
# is drawn.
signal level_added(level: Level)

signal dig_requested(actor: Actor, tile: WorldPos)
signal tile_dug(actor: Actor, tile: WorldPos)
signal dig_refused(actor: Actor, tile: WorldPos, reason: DIG_REFUSAL)

# A floor breached (D-152): `tile` is the floor on its own level,
# which becomes a hole; the tile below it is cleared as the landing.
signal breach_requested(actor: Actor, tile: WorldPos, tool_power: float)
signal tile_breached(actor: Actor, tile: WorldPos)
signal breach_refused(actor: Actor, tile: WorldPos, reason: BREACH_REFUSAL)

# Items leaving and joining packs through the ground (D-160, D-161).
# `tile` is where the items lie.
signal drop_requested(actor: Actor, id: StringName, count: int)
signal take_requested(actor: Actor)
signal items_dropped(actor: Actor, tile: WorldPos, id: StringName, count: int)
signal items_picked_up(actor: Actor, tile: WorldPos, id: StringName, count: int)
# The take key's answer (D-167): everything it took, item id -> count,
# empty when nothing was in reach. Auto-pickup doesn't announce this.
signal took(actor: Actor, items: Dictionary)

# A failing region began its countdown (D-163, D-166). `depth` is its
# level; `tiles` are the region's.
signal ceiling_failing(depth: int, tiles: Array[Vector2i])
# A countdown ran out: these tiles are rubble now.
signal collapsed(depth: int, tiles: Array[Vector2i])
# An actor caught under a collapse was moved to the nearest open tile
# (D-163).
signal actor_moved_clear(actor: Actor, from: WorldPos, to: WorldPos)

# An actor too heavy to climb the ladder it tried (D-159). `tile` is
# where the ladder would have taken it.
signal climb_refused(actor: Actor, tile: WorldPos)

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

# Why a breach was refused (D-152). Each names the end that failed:
# the floor, or the landing below it.
enum BREACH_REFUSAL {
	NONE,
	LEVEL_NOT_EXISTS,
	TILE_NOT_EXISTS,
	NOT_PLAIN_FLOOR,
	FIXTURE_ON_TILE,
	ACTOR_ON_TILE,
	NO_LEVEL_BELOW,
	LANDING_NOT_EXISTS,
	LANDING_BLOCKED,
	TOOL_TOO_WEAK,
	# The actor isn't holding a pick (D-174). Asked first: the tool in
	# hand is the answer whatever floor is faced.
	NEEDS_PICK,
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
	# The requesting actor's pack can't pay the cost (D-159)
	CANNOT_AFFORD,
	# A fixture that blocks its tile (D-165) can't go where an actor
	# stands: it would wall the actor in
	ACTOR_ON_TILE,
}

var world_seed: int
# Draws what digging yields (D-158): seeded from the world seed the
# first time it's used, so a world's yields repeat. Not saved; a load
# starts a fresh sequence.
var _yield_rng: RandomNumberGenerator
# Where each actor last dropped something, by instance id, so it isn't
# picked straight back up: kept until the actor steps off that tile
# (slice 009 trap 3).
var _dropped_at: Dictionary[int, WorldPos] = {}
# World-wide, so an id alone finds a fixture or an actor (D-104,
# D-114). Each world numbers its own: generating or loading another
# never resets these (D-118).
var fixture_ids: IdAllocator = IdAllocator.new()
var actor_ids: IdAllocator = IdAllocator.new()
# The numbers this world runs under (D-135). Each world holds its own,
# so two worlds can run under different profiles.
var tuning: TuningProfile
# How long the last level generated on arrival took, in ms; -1 until
# one has been (D-143). F3 shows it.
var last_generation_msec: float = -1.0

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
	breach_requested.connect(_on_breach_requested)
	drop_requested.connect(_on_drop_requested)
	take_requested.connect(_on_take_requested)
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
	_hold_up(level)
	level_added.emit(level)
	return true


# Starts judging a level's excavations (D-163) under this world's
# numbers, and carries out the collapses it announces. Its depth's R is
# the profile's; a depth the profile doesn't cover has no ceiling.
func _hold_up(level: Level) -> void:
	var table: Array[int] = tuning.support_radius_by_depth
	var reach: int = table[level.depth] if level.depth < table.size() else 0
	# Zero is no ceiling: the Surface is open sky
	level.support = LevelSupport.new(level, reach if reach > 0 else -1,
		tuning.collapse_countdown_seconds)
	level.support.region_failing.connect(_on_region_failing.bind(level))
	level.support.collapse_due.connect(_collapse.bind(level))


# --- time ---

# Countdowns run in a running world: one built outside the tree, by a
# load, is still until it is swapped in, so nothing can fall while it
# is built (slice 010 trap 5).
func _physics_process(delta: float) -> void:
	advance_time(delta)


# Runs the countdowns on every level a player is on by `delta`
# seconds. A level nobody is on stands still, so nothing falls out of
# sight; the rate machine that lets a place run while you are away
# comes later. A test drives time by calling this.
func advance_time(delta: float) -> void:
	for level: Level in _levels_with_players():
		if level.support != null: level.support.advance(delta)


func _levels_with_players() -> Array[Level]:
	var found: Array[Level] = []
	for actor: Actor in players():
		if actor.current_level != null and actor.current_level not in found:
			found.append(actor.current_level)
	return found


func _on_region_failing(tiles: Array[Vector2i], level: Level) -> void:
	ceiling_failing.emit(level.depth, tiles)


# The tiles fill with rubble (D-166) and whoever is under them is
# moved clear (D-163). Fixtures and drops stay where they are: buried,
# not destroyed. The change is gathered, so the rule judges it once.
func _collapse(tiles: Array[Vector2i], level: Level) -> void:
	level.support.hold()
	for tile: Vector2i in tiles:
		level.level_tiles.set_top(tile.x, tile.y, TileKind.TOP.RUBBLE)
	level.support.release()
	_move_caught_clear(level)
	collapsed.emit(level.depth, tiles)


# Any actor on the level whose feet no longer fit where it stands goes
# to the nearest tile it can stand on.
func _move_caught_clear(level: Level) -> void:
	for actor: Actor in actors():
		if actor.current_level != level: continue
		if TileCollision.fits(level.level_tiles, actor.get_world_box()): continue
		var from: WorldPos = actor.current_WorldPos
		var others: Array[Actor] = actors()
		others.erase(actor)
		var target: WorldPos = Spawning.free_tile_near(from, level.level_tiles, others)
		if target == null or not actor.move_to(target):
			push_error("%s is buried at %s with nowhere to go." % [actor.actor_name, from])
			continue
		actor_moved_clear.emit(actor, from, target)


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
	# Where an actor starts isn't an arrival: setup announced it before
	# now. A load relies on that, so nothing generates while it builds
	# (D-143). It is sensed, though, so a new game's first tiles are
	# remembered before the first step.
	actor.actor_worldpos_changed.connect(_on_actor_moved)
	_remember_around(actor)


# Every tile step: a player's senses mark memory, and any actor
# arriving at a depth grows the world below it.
func _on_actor_moved(actor: Actor, old_pos: WorldPos, new_pos: WorldPos) -> void:
	_remember_around(actor)
	_auto_pickup(actor)
	if old_pos != null and old_pos.depth == new_pos.depth: return
	generate_below(new_pos.depth)


# --- drops (D-160, D-161) ---

# Moves up to `count` of an item from the actor's pack onto its tile.
func _on_drop_requested(actor: Actor, id: StringName, count: int) -> void:
	if actor == null or actor.current_level == null or actor.current_level.world != self: return
	var n: int = mini(count, actor.pack.count_of(id))
	if n <= 0: return
	var here: WorldPos = actor.current_WorldPos
	actor.pack.remove(id, n)
	actor.current_level.level_drops.add(Vector2i(here.x, here.y), id, n)
	_dropped_at[actor.get_instance_id()] = here
	items_dropped.emit(actor, here, id, n)


# A player takes what lies within reach as it moves, up to the fill
# limit. Never an NPC (D-160), and never what it just put down, until
# it steps off that tile.
func _auto_pickup(actor: Actor) -> void:
	if actor.actor_kind != ActorKind.ACTOR.PLAYER: return
	var dropped: WorldPos = _dropped_at.get(actor.get_instance_id())
	if dropped != null and not dropped.equals(actor.current_WorldPos):
		_dropped_at.erase(actor.get_instance_id())
		dropped = null
	_pick_up(actor, tuning.auto_fill_limit, dropped)


# The take key: everything within reach, whatever the load (D-160).
func _on_take_requested(actor: Actor) -> void:
	if actor == null or actor.current_level == null or actor.current_level.world != self: return
	took.emit(actor, _pick_up(actor, INF, null))


# Everything lying within an actor's reach, item id -> count: what the
# take key would take (D-160), and what the inventory's preview shows
# (D-172). A read, sharing the take's tiles so the two can't disagree.
func drops_in_reach(actor: Actor) -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	for tile: Vector2i in _reach_tiles(actor, null):
		var lying: Dictionary = actor.current_level.level_drops.at(tile)
		for id: StringName in lying:
			found[id] = found.get(id, 0) + lying[id]
	return found


# The tiles an actor picks up from: its own and those around it, out
# to the profile's reach, open and so not buried (D-166), less `skip`.
func _reach_tiles(actor: Actor, skip: WorldPos) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var level: Level = actor.current_level
	var here: WorldPos = actor.current_WorldPos
	if level == null or here == null or level.level_drops.is_empty(): return tiles
	var reach: int = tuning.pickup_reach
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var tile: Vector2i = Vector2i(here.x + dx, here.y + dy)
			if skip != null and tile == Vector2i(skip.x, skip.y): continue
			if level.level_tiles.get_top(tile.x, tile.y) != TileKind.TOP.OPEN: continue
			tiles.append(tile)
	return tiles


# Moves what fits under `limit` from the tiles in reach into the
# pack. Returns what it took, item id -> count.
func _pick_up(actor: Actor, limit: float, skip: WorldPos) -> Dictionary[StringName, int]:
	var taken: Dictionary[StringName, int] = {}
	var level: Level = actor.current_level
	for tile: Vector2i in _reach_tiles(actor, skip):
		var lying: Dictionary = level.level_drops.at(tile)
		for id: StringName in lying:
			var n: int = lying[id] if is_inf(limit) else \
				Carrying.fits(tuning, actor.pack, id, lying[id], limit)
			if n <= 0: continue
			level.level_drops.take(tile, id, n)
			actor.pack.add(id, n)
			taken[id] = taken.get(id, 0) + n
			items_picked_up.emit(actor, WorldPos.new(tile.x, tile.y, level.depth), id, n)
	return taken


# --- memory (D-145) ---

# What a player senses from where it stands is remembered on its
# level, in this world. Players only: an NPC wandering the mountain
# doesn't map it for you. Set directly, not requested: memory is
# perception, not terrain, and nothing can refuse it.
func _remember_around(actor: Actor) -> void:
	if actor.actor_kind != ActorKind.ACTOR.PLAYER: return
	var level: Level = actor.current_level
	if level == null or level.world != self: return
	var here: WorldPos = actor.current_WorldPos
	if here == null: return
	level.level_tiles.remember(
		Senses.flood(level.level_tiles, Vector2i(here.x, here.y), tuning.sense_radius))


# --- generation on first descent (D-143) ---


# Generates the level below `depth` if it doesn't exist yet and the
# recipe table has a row for it. Returns the new level, or null if
# none was needed.
func generate_below(depth: int) -> Level:
	var below: int = depth + 1
	if level_at(below) != null or not LevelRecipes.TABLE.has_recipe(below): return null
	var started: int = Time.get_ticks_usec()
	var level: Level = LevelGenerator.generate_into(self, below)
	last_generation_msec = (Time.get_ticks_usec() - started) / 1000.0
	if level == null: return null
	# The pairs that span the new level and the one above are checked
	# now that both exist (trap 1). A problem there is a recipe bug.
	var above: Level = level_at(depth)
	if above != null:
		for problem: String in LevelGenerator.problems_between(above, level):
			push_error(problem)
	return level


# The pass a load makes once its world is swapped in (D-143): the
# level below each actor, if the save didn't hold it.
func generate_below_actors() -> void:
	for actor: Actor in actors():
		generate_below(actor.depth)


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
	# The yield, read before the tile changes, goes into the digger's
	# own pack, uncapped (D-158). No actor, no yield.
	if actor != null:
		var tiles: LevelTiles = level.level_tiles
		var found: Dictionary[StringName, int] = Digging.yield_of(tuning,
			tiles.get_top(tile.x, tile.y), tiles.get_ore(tile.x, tile.y), _yields())
		# Into the pack up to the fill limit; the rest drops where it was
		# dug (D-160)
		for id: StringName in found:
			var fits: int = Carrying.fits(tuning, actor.pack, id, found[id], tuning.auto_fill_limit)
			actor.pack.add(id, fits)
			if found[id] > fits:
				level.level_drops.add(Vector2i(tile.x, tile.y), id, found[id] - fits)
				items_dropped.emit(actor, tile, id, found[id] - fits)
	# Marked before it opens, so the support rule hears of an excavated
	# tile (D-164)
	level.level_tiles.mark_excavated(tile.x, tile.y)
	level.level_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)
	level.level_tiles.set_ore(tile.x, tile.y, TileKind.ORE.NONE)
	tile_dug.emit(actor, tile)


func _yields() -> RandomNumberGenerator:
	if _yield_rng == null:
		_yield_rng = RandomNumberGenerator.new()
		_yield_rng.seed = hash([world_seed, "yields"])
	return _yield_rng


# --- breaching (D-151, D-152) ---

# Checked whole, then applied whole: the floor becomes a hole and the
# landing below becomes open floor, or nothing changes.
func _on_breach_requested(actor: Actor, tile: WorldPos, tool_power: float) -> void:
	var reason: BREACH_REFUSAL = breach_problem(tile, tool_power, actor)
	if reason != BREACH_REFUSAL.NONE:
		breach_refused.emit(actor, tile, reason)
		return
	var upper: LevelTiles = level_at(tile.depth).level_tiles
	var lower: LevelTiles = level_at(tile.depth + 1).level_tiles
	upper.set_ground(tile.x, tile.y, TileKind.GROUND.HOLE)
	# The landing is rock a player opened (D-164); the hole's own
	# tile was open floor already
	lower.mark_excavated(tile.x, tile.y)
	lower.set_top(tile.x, tile.y, TileKind.TOP.OPEN)
	lower.set_ore(tile.x, tile.y, TileKind.ORE.NONE)
	tile_breached.emit(actor, tile)


# Why a breach of `tile` with a tool of `tool_power` would be
# refused, or NONE. A read: the breach capability asks it before
# spending five seconds, and build mode's preview can too. With an
# actor, its selected tool must be a pick (D-174).
func breach_problem(tile: WorldPos, tool_power: float, actor: Actor = null) -> BREACH_REFUSAL:
	if actor != null and not Digging.breaches(actor.tool()): return BREACH_REFUSAL.NEEDS_PICK
	var level: Level = level_at(tile.depth)
	if level == null: return BREACH_REFUSAL.LEVEL_NOT_EXISTS
	var tiles: LevelTiles = level.level_tiles
	var top: int = tiles.get_top(tile.x, tile.y)
	var ground: int = tiles.get_ground(tile.x, tile.y)
	if TileKind.is_sentinel(top) or TileKind.is_sentinel(ground):
		return BREACH_REFUSAL.TILE_NOT_EXISTS
	if top != TileKind.TOP.OPEN or not _is_plain_floor(ground):
		return BREACH_REFUSAL.NOT_PLAIN_FLOOR
	if not level.level_fixtures.at(Vector2i(tile.x, tile.y)).is_empty():
		return BREACH_REFUSAL.FIXTURE_ON_TILE
	if _actor_on(tile): return BREACH_REFUSAL.ACTOR_ON_TILE

	var below: Level = level_at(tile.depth + 1)
	if below == null: return BREACH_REFUSAL.NO_LEVEL_BELOW
	var landing: int = below.level_tiles.get_ground(tile.x, tile.y)
	if TileKind.is_sentinel(landing) or TileKind.is_sentinel(below.level_tiles.get_top(tile.x, tile.y)):
		return BREACH_REFUSAL.LANDING_NOT_EXISTS
	if not _is_plain_floor(landing) or not below.level_fixtures.at(Vector2i(tile.x, tile.y)).is_empty():
		return BREACH_REFUSAL.LANDING_BLOCKED

	if not Digging.can_breach(tuning, Digging.floor_hardness(tuning, tile.depth), tool_power):
		return BREACH_REFUSAL.TOOL_TOO_WEAK
	return BREACH_REFUSAL.NONE


# Floor you can stand on that isn't a ramp or a hole: what a breach
# makes a hole of, and what a landing may be.
static func _is_plain_floor(ground: int) -> bool:
	if TileKind.is_ramp(ground): return false
	return ground in [TileKind.GROUND.ROCK, TileKind.GROUND.DIRT, TileKind.GROUND.GRASS]


func _actor_on(tile: WorldPos) -> bool:
	for actor: Actor in actors():
		if actor.current_WorldPos != null and actor.current_WorldPos.equals(tile): return true
	return false


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
	if blocks_actor(level, kind, tile):
		request_refused.emit(actor, FIXTURE_VERB.PLACE, tile, FIXTURE_REFUSAL.ACTOR_ON_TILE)
		return
	# Paid from the requesting actor's own pack; free with no actor
	# (D-159)
	if not Building.can_afford(tuning, actor, kind):
		request_refused.emit(actor, FIXTURE_VERB.PLACE, tile, FIXTURE_REFUSAL.CANNOT_AFFORD)
		return

	Building.pay(tuning, actor, kind)
	var fixture: Fixture = Fixture.new(kind, tile, fixture_ids.allocate())
	level.level_fixtures.add(fixture)
	fixture_placed.emit(actor, fixture)


# Whether a fixture of `kind` on `tile` would wall in an actor standing
# there: it blocks walking (D-165) and an actor's feet touch the tile.
# A read, so build mode's preview asks what the gatekeeper does.
func blocks_actor(level: Level, kind: int, tile: WorldPos) -> bool:
	if not ObjectKind.blocks_walking(kind): return false
	var size: float = TileSpace.TILE_PIXELS
	var tile_rect: Rect2 = Rect2(Vector2(tile.x, tile.y) * size, Vector2(size, size))
	for actor: Actor in actors():
		if actor.current_level == level and actor.get_world_box().intersects(tile_rect):
			return true
	return false


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

	if blocks_actor(target, fixture.kind, to):
		request_refused.emit(actor, FIXTURE_VERB.MOVE, to, FIXTURE_REFUSAL.ACTOR_ON_TILE)
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
