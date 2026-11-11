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
# Items dropped down a chute (D-220): `top` is the chute's tile,
# `landed` where they came to rest, levels below.
signal items_chuted(actor: Actor, top: WorldPos, landed: WorldPos, id: StringName, count: int)
# Items put into a winch's crate (D-224), and taken out of it.
signal items_crated(actor: Actor, crate: Fixture, id: StringName, count: int)
signal items_uncrated(actor: Actor, crate: Fixture, id: StringName, count: int)
# A winch's crate reached the top of its hole, or the foot (D-225).
# `actor` is whoever's cranking finished the move.
signal crate_arrived(actor: Actor, winch: Fixture, crate: Fixture, at_top: bool)
signal crank_refused(actor: Actor, reason: CRANK_REFUSAL)
# Making something (D-222): asked by recipe id, answered with what was
# made or why not.
signal craft_requested(actor: Actor, recipe_id: StringName)
signal crafted(actor: Actor, recipe: Recipe)
signal craft_refused(actor: Actor, recipe_id: StringName, reason: CRAFT_REFUSAL)
# Felling a tree (D-181): asked when the work is done, answered with
# the tree gone and its timber given, or a refusal.
signal chop_requested(actor: Actor, tile: WorldPos)
signal tree_felled(actor: Actor, tile: WorldPos)
signal chop_refused(actor: Actor, tile: WorldPos, reason: CHOP_REFUSAL)
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
# A climb began (D-233): it ends `seconds` later at `tile`.
signal climb_started(actor: Actor, tile: WorldPos, seconds: float)

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
	# Crushed rubble (D-218): no tool clears it yet
	CRUSHED,
	# The ore needs a stronger tool than the one in hand (D-217)
	TOOL_TOO_WEAK,
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
	# The hole would join a winch's shaft to one with a ladder or chute,
	# or two shafts that each have a crate (D-236)
	SHAFTS_CANT_JOIN,
}

# Why a tree wasn't felled (D-181).
enum CHOP_REFUSAL {
	NONE,
	NO_TREE,
	NEEDS_AXE,
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
	# A chute or winch goes over an open hole (D-219)
	NEEDS_HOLE,
	# The hole already has a ladder under it or something over it: one
	# hole, one use (D-219)
	HOLE_IN_USE,
	# A winch's crate has no floor to stand on at the foot of its hole
	# (D-224)
	LANDING_BLOCKED,
	# A winch's shaft takes no ladder or chute, and a shaft with either
	# takes no winch (D-235)
	WINCH_SHAFT,
}

# Why making something was refused (D-222).
enum CRAFT_REFUSAL {
	NONE,
	UNKNOWN_RECIPE,
	CANNOT_AFFORD,
	# Made at a station (a workbench, 016) the actor isn't at
	NEEDS_STATION,
}

# Why cranking a winch, or filling its crate, did nothing (D-224,
# D-225).
enum CRANK_REFUSAL {
	NONE,
	# Facing the crate at the foot of its hole: the winch is worked
	# from the top
	FROM_BELOW,
	# Where the crate is going has no room for it: the foot of the hole,
	# or a hole where another crate hangs (D-234)
	LANDING_BLOCKED,
	# Not all of a drop fitted in the crate
	CRATE_FULL,
	# The shaft's crate is at another winch, out of this one's reach
	# (D-235)
	CRATE_ELSEWHERE,
}

# How far, in rings of tiles, chuted items look for somewhere to lie
# before they are left buried on their landing (trap 3).
const LANDING_RINGS: int = 4

var world_seed: int
# How far each winch's crate is on its way, 0 to 1, by the winch's id
# (D-225). Not saved: a crate is at one end or the other, and a load
# finds it where it last arrived (015 trap 4).
var _crank_progress: Dictionary[int, float] = {}
# The winches someone cranked since the last physics tick: one nobody
# is cranking any more goes back to the start (D-231)
var _cranked: Dictionary[int, bool] = {}
# Draws what digging yields (D-158): seeded from the world seed the
# first time it's used, so a world's yields repeat. Not saved; a load
# starts a fresh sequence.
var _yield_rng: RandomNumberGenerator
# The tiles each actor dropped on, by instance id, so they aren't
# picked straight back up: each kept until the actor is out of its
# pickup reach (D-212). Not saved.
var _dropped_at: Dictionary[int, Array] = {}
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
	# Its actors are sorted with the fixtures beside it (D-214): every
	# node down to an actor sorts, so the actors join one sort.
	y_sort_enabled = true
	_levels_node = Node2D.new()
	_levels_node.name = "Levels"
	add_child(_levels_node)
	var actors_node: Node2D = Node2D.new()
	actors_node.name = "Actors"
	actors_node.y_sort_enabled = true
	add_child(actors_node)
	_players_node = Node2D.new()
	_players_node.name = "Players"
	_players_node.y_sort_enabled = true
	actors_node.add_child(_players_node)
	_npcs_node = Node2D.new()
	_npcs_node.name = "NPCs"
	_npcs_node.y_sort_enabled = true
	actors_node.add_child(_npcs_node)

	dig_requested.connect(_on_dig_requested)
	breach_requested.connect(_on_breach_requested)
	drop_requested.connect(_on_drop_requested)
	take_requested.connect(_on_take_requested)
	chop_requested.connect(_on_chop_requested)
	place_requested.connect(_on_place_requested)
	remove_requested.connect(_on_remove_requested)
	move_requested.connect(_on_move_requested)
	craft_requested.connect(_on_craft_requested)


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
	settle_cranks()
	advance_time(delta)


# Every winch nobody cranked since the last call loses its progress
# (D-231). The world's tick runs before its actors', so it sees the
# cranking of the tick before. A test calls this directly.
func settle_cranks() -> void:
	for id: int in _crank_progress.keys():
		if not _cranked.has(id): _crank_progress.erase(id)
	_cranked.clear()


# Runs the countdowns on every level a player is on by `delta`
# seconds. A level nobody is on stands still, so nothing falls out of
# sight; the rate machine that lets a place run while you are away
# comes later. A test drives time by calling this.
func advance_time(delta: float) -> void:
	for level: Level in _levels_with_players():
		if level.support != null: level.support.advance(delta)
		_burn_torches(level, delta)


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
		if target == null or not actor.move_to(target, &"collapse"):
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

# Moves up to `count` of an item from the actor's pack onto its tile,
# or, facing a chute, down the chute (D-220).
func _on_drop_requested(actor: Actor, id: StringName, count: int) -> void:
	if actor == null or actor.current_level == null or actor.current_level.world != self: return
	var n: int = mini(count, actor.pack.count_of(id))
	if n <= 0: return
	var here: WorldPos = actor.current_WorldPos
	var crate: Fixture = crate_faced(actor)
	if crate != null:
		_fill_crate(actor, crate, id, n)
		return
	var chute: Fixture = chute_faced(actor)
	if chute != null and level_at(here.depth + 1) != null:
		actor.pack.remove(id, n)
		_send_down(actor, chute.tile, id, n)
		return
	# The light in hand, dropped while it burns, stays lit on the
	# ground: a breadcrumb (D-221). The rest of a stack drops unlit.
	if actor.hotbar.lit and id == actor.hotbar.light:
		_drop_lit(actor, here)
		n -= 1
		if n <= 0: return
	actor.pack.remove(id, n)
	actor.current_level.level_drops.add(Vector2i(here.x, here.y), id, n)
	var dropped: Array = _dropped_at.get_or_add(actor.get_instance_id(), [])
	if not dropped.any(func(at: WorldPos) -> bool: return at.equals(here)):
		dropped.append(here)
	items_dropped.emit(actor, here, id, n)


# A burning torch on the actor's tile, with the time its light had
# left (D-221).
func _drop_lit(actor: Actor, here: WorldPos) -> void:
	var torch: Fixture = Fixture.new(ObjectKind.OBJECT.TORCH, here, fixture_ids.allocate())
	torch.time_left = actor.hotbar.hand_over_light(tuning.torch_burn_seconds)
	actor.current_level.level_fixtures.add(torch)
	fixture_placed.emit(actor, torch)


# Burns every dropped torch on `level` by `delta` seconds; one that
# burns out is gone (D-221).
func _burn_torches(level: Level, delta: float) -> void:
	for torch: Fixture in level.level_fixtures.of_kind(ObjectKind.OBJECT.TORCH):
		torch.time_left -= delta
		if torch.time_left > 0.0: continue
		level.level_fixtures.remove(torch.id)
		fixture_removed.emit(null, torch)


# --- chutes (D-219, D-220) ---

# The chute on the tile the actor faces, or null: a drop made facing
# one goes down it.
func chute_faced(actor: Actor) -> Fixture:
	var level: Level = actor.current_level
	var here: WorldPos = actor.current_WorldPos
	if level == null or here == null: return null
	var faced: Vector2i = Vector2i(here.x, here.y) + actor.facing
	return _fixture_of_kind(level, faced, ObjectKind.OBJECT.CHUTE)


func _fixture_of_kind(level: Level, tile: Vector2i, kind: int) -> Fixture:
	for fixture: Fixture in level.level_fixtures.at(tile):
		if fixture.kind == kind: return fixture
	return null


# Items into the chute at `top`: they fall to the level below at the
# same (x, y), on through every chute they land in (D-219), and lie
# where they stop, spilled to the nearest open tile when that one
# can't hold them (trap 3).
func _send_down(actor: Actor, top: WorldPos, id: StringName, count: int) -> void:
	var level: Level = level_at(top.depth + 1)
	var tile: Vector2i = Vector2i(top.x, top.y)
	while level_at(level.depth + 1) != null \
			and _fixture_of_kind(level, tile, ObjectKind.OBJECT.CHUTE) != null:
		level = level_at(level.depth + 1)
	var landing: Vector2i = landing_near(level, tile)
	level.level_drops.add(landing, id, count)
	items_chuted.emit(actor, top, WorldPos.new(landing.x, landing.y, level.depth), id, count)


# Where something falling onto `tile` of `level` comes to rest: the
# tile itself when it's open floor with no fixture on it, else the
# nearest such tile, ring by ring. With none near, the tile itself:
# buried, never lost.
func landing_near(level: Level, tile: Vector2i) -> Vector2i:
	for ring in range(0, LANDING_RINGS + 1):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring: continue
				var at: Vector2i = tile + Vector2i(dx, dy)
				if _holds_drops(level, at): return at
	return tile


func _holds_drops(level: Level, tile: Vector2i) -> bool:
	var tiles: LevelTiles = level.level_tiles
	if not TileKind.is_passable(tiles.get_top(tile.x, tile.y), tiles.get_ground(tile.x, tile.y)):
		return false
	return level.level_fixtures.at(tile).is_empty()


# --- making things (D-222) ---

# Why `actor` can't make the recipe with this id now, or NONE. A read,
# so the CRAFT tab shows what can be made before anyone asks.
func craft_problem(actor: Actor, recipe_id: StringName) -> CRAFT_REFUSAL:
	var recipe: Recipe = RecipeRegistry.find(recipe_id)
	if recipe == null: return CRAFT_REFUSAL.UNKNOWN_RECIPE
	if recipe.station != Recipe.HAND: return CRAFT_REFUSAL.NEEDS_STATION
	for id: StringName in recipe.inputs:
		if not actor.pack.has(id, recipe.inputs[id]): return CRAFT_REFUSAL.CANNOT_AFFORD
	return CRAFT_REFUSAL.NONE


# Takes the inputs from the actor's pack and puts the outputs in it,
# whatever the load: what's made is in hand, as a take is.
func _on_craft_requested(actor: Actor, recipe_id: StringName) -> void:
	if actor == null or actor.current_level == null or actor.current_level.world != self: return
	var reason: CRAFT_REFUSAL = craft_problem(actor, recipe_id)
	if reason != CRAFT_REFUSAL.NONE:
		craft_refused.emit(actor, recipe_id, reason)
		return
	var recipe: Recipe = RecipeRegistry.find(recipe_id)
	for id: StringName in recipe.inputs:
		actor.pack.remove(id, recipe.inputs[id])
	for id: StringName in recipe.outputs:
		actor.pack.add(id, recipe.outputs[id])
	crafted.emit(actor, recipe)


# --- the winch and its crate (D-224, D-225) ---

# The winch on the tile the actor faces, on the actor's own level: the
# top of its hole, where it is cranked. Null when there is none.
func winch_faced(actor: Actor) -> Fixture:
	var faced: Vector2i = _faced_tile(actor)
	if faced == NO_TILE: return null
	return _fixture_of_kind(actor.current_level, faced, ObjectKind.OBJECT.WINCH)


# The crate on the tile the actor faces, on the actor's own level: at
# the foot of its hole, or hanging in it at the top. Null when there is
# none, or it is buried.
func crate_faced(actor: Actor) -> Fixture:
	var faced: Vector2i = _faced_tile(actor)
	if faced == NO_TILE: return null
	var level: Level = actor.current_level
	var crate: Fixture = _fixture_of_kind(level, faced, ObjectKind.OBJECT.CRATE)
	if crate == null or level.level_tiles.get_top(faced.x, faced.y) != TileKind.TOP.OPEN: return null
	return crate


const NO_TILE: Vector2i = Vector2i(-99999, -99999)


func _faced_tile(actor: Actor) -> Vector2i:
	var here: WorldPos = actor.current_WorldPos
	if actor.current_level == null or here == null: return NO_TILE
	return Vector2i(here.x, here.y) + actor.facing


# A winch's crate: hanging in its hole, or at the end of its rope
# (D-235). Null when the shaft's crate is at neither.
func crate_of(winch: Fixture) -> Fixture:
	var tile: Vector2i = Vector2i(winch.tile.x, winch.tile.y)
	for depth: int in [winch.tile.depth, rope_end(winch.tile)]:
		var level: Level = level_at(depth)
		if level == null: continue
		var crate: Fixture = _fixture_of_kind(level, tile, ObjectKind.OBJECT.CRATE)
		if crate != null: return crate
	return null


# --- shafts (D-235) ---
# A shaft is the holes at one x, y on levels one under the next, and
# the floor under the lowest of them: its foot.

# The depths of the shaft through `depth` at `at`, top to foot. A floor
# with no hole over it is a shaft of one.
func shaft_depths(at: Vector2i, depth: int) -> Array[int]:
	var top: int = depth
	while _is_hole(at, top - 1): top -= 1
	var foot: int = depth
	while _is_hole(at, foot) and level_at(foot + 1) != null: foot += 1
	var depths: Array[int] = []
	for d: int in range(top, foot + 1):
		depths.append(d)
	return depths


func _is_hole(at: Vector2i, depth: int) -> bool:
	var level: Level = level_at(depth)
	return level != null and level.level_tiles.get_ground(at.x, at.y) == TileKind.GROUND.HOLE


# Where a crate let go at `depth` comes to rest: hanging in the first
# winch's hole it meets, or on the shaft's foot. -1 past the last level.
func drop_point(at: Vector2i, depth: int) -> int:
	var d: int = depth
	while true:
		var level: Level = level_at(d)
		if level == null: return -1
		if _fixture_of_kind(level, at, ObjectKind.OBJECT.WINCH) != null: return d
		if level.level_tiles.get_ground(at.x, at.y) != TileKind.GROUND.HOLE: return d
		d += 1
	return -1


# How far down the winch at the top of `top`'s hole reaches: the hole
# of the next winch down the shaft, or the foot.
func rope_end(top: WorldPos) -> int:
	return drop_point(Vector2i(top.x, top.y), top.depth + 1)


# The fixtures of `kinds` anywhere in the shaft through `depth`.
func shaft_fixtures(at: Vector2i, depth: int, kinds: Array[int]) -> Array[Fixture]:
	var found: Array[Fixture] = []
	for d: int in shaft_depths(at, depth):
		for fixture: Fixture in level_at(d).level_fixtures.at(at):
			if fixture.kind in kinds: found.append(fixture)
	return found


# The shaft's one crate, or null.
func shaft_crate(at: Vector2i, depth: int) -> Fixture:
	var crates: Array[Fixture] = shaft_fixtures(at, depth, [ObjectKind.OBJECT.CRATE])
	return crates[0] if not crates.is_empty() else null


# Why a ladder, chute or winch can't go in the shaft through `tile`,
# or NONE: a shaft is a winch's, or a ladder's and chutes', never both.
func shaft_problem(kind: int, tile: WorldPos) -> FIXTURE_REFUSAL:
	var at: Vector2i = Vector2i(tile.x, tile.y)
	var against: Array[int] = []
	match kind:
		ObjectKind.OBJECT.WINCH: against = [ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.CHUTE]
		ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.CHUTE: against = [ObjectKind.OBJECT.WINCH]
		_: return FIXTURE_REFUSAL.NONE
	if level_at(tile.depth) == null: return FIXTURE_REFUSAL.NONE
	if not shaft_fixtures(at, tile.depth, against).is_empty(): return FIXTURE_REFUSAL.WINCH_SHAFT
	return FIXTURE_REFUSAL.NONE


# How far a winch's crate is on its way, 0 to 1 (D-225).
func crank_progress(winch: Fixture) -> float:
	return _crank_progress.get(winch.id, 0.0)


# What fits of the drop goes into the crate; the rest stays in the
# pack, and the refusal says the crate is full.
func _fill_crate(actor: Actor, crate: Fixture, id: StringName, count: int) -> void:
	var fits: int = Winch.room_for(tuning, crate, id, count)
	if fits > 0:
		actor.pack.remove(id, fits)
		crate.contents.add(id, fits)
		items_crated.emit(actor, crate, id, fits)
	if fits < count: crank_refused.emit(actor, CRANK_REFUSAL.CRATE_FULL)


# Everything in the crate into the actor's pack, whatever the load,
# as the take key takes from the ground (D-160). Returns what moved.
func _empty_crate(actor: Actor, crate: Fixture) -> Dictionary[StringName, int]:
	var moved: Dictionary[StringName, int] = {}
	for key: String in crate.contents.to_save():
		var id: StringName = StringName(key)
		var n: int = crate.contents.count_of(id)
		crate.contents.remove(id, n)
		actor.pack.add(id, n)
		moved[id] = n
		items_uncrated.emit(actor, crate, id, n)
	return moved


# Interact first held down (D-225): at the foot of a winch's hole,
# facing its crate, it is refused with the reason. Cranking itself is
# `crank`, every tick it stays held.
func begin_crank(actor: Actor) -> void:
	var winch: Fixture = winch_faced(actor)
	if winch != null:
		# The shaft's crate is at another winch (D-235)
		var at: Vector2i = Vector2i(winch.tile.x, winch.tile.y)
		if crate_of(winch) == null and shaft_crate(at, winch.tile.depth) != null:
			crank_refused.emit(actor, CRANK_REFUSAL.CRATE_ELSEWHERE)
		return
	var crate: Fixture = crate_faced(actor)
	if crate == null: return
	var tile: Vector2i = Vector2i(crate.tile.x, crate.tile.y)
	if not shaft_fixtures(tile, crate.tile.depth, [ObjectKind.OBJECT.WINCH]).is_empty():
		crank_refused.emit(actor, CRANK_REFUSAL.FROM_BELOW)


# One tick of `actor` cranking the winch it faces (D-225): the crate
# moves on toward the other end of its hole at this player's rate, so
# two cranking together move it twice as fast. On arrival it is moved
# between levels whole, contents and all. Lowering waits, full, when
# the foot has no room, and the refusal says so once.
func crank(actor: Actor, delta: float) -> void:
	var winch: Fixture = winch_faced(actor)
	if winch == null: return
	var crate: Fixture = crate_of(winch)
	if crate == null: return
	var lifting: bool = crate.tile.depth != winch.tile.depth
	_cranked[winch.id] = true
	var was: float = crank_progress(winch)
	# Each level of rope takes the winch's time (D-235)
	var levels: int = maxi(rope_end(winch.tile) - winch.tile.depth, 1)
	var progress: float = minf(was + delta / (Winch.seconds(tuning, lifting) * levels), 1.0)
	_crank_progress[winch.id] = progress
	if progress < 1.0: return
	var top: WorldPos = winch.tile
	if lifting:
		# Into a hole where no crate hangs already (D-234)
		var level: Level = level_at(top.depth)
		var other: Fixture = _fixture_of_kind(level, Vector2i(top.x, top.y), ObjectKind.OBJECT.CRATE)
		if other != null and other != crate:
			if was < 1.0: crank_refused.emit(actor, CRANK_REFUSAL.LANDING_BLOCKED)
			return
		_move_crate(actor, winch, crate, WorldPos.new(top.x, top.y, top.depth))
		return
	var end: int = rope_end(top)
	if _crate_landing_problem(Vector2i(top.x, top.y), end, crate) != FIXTURE_REFUSAL.NONE:
		if was < 1.0: crank_refused.emit(actor, CRANK_REFUSAL.LANDING_BLOCKED)
		return
	_move_crate(actor, winch, crate, WorldPos.new(top.x, top.y, end))


# The crate, contents and all, from one end of its hole to the other.
func _move_crate(actor: Actor, winch: Fixture, crate: Fixture, to: WorldPos) -> void:
	var from: WorldPos = crate.tile
	level_at(from.depth).level_fixtures.remove(crate.id)
	level_at(to.depth).level_fixtures.receive(crate, to)
	_crank_progress.erase(winch.id)
	fixture_moved.emit(actor, crate, from)
	crate_arrived.emit(actor, winch, crate, to.depth == winch.tile.depth)


# A player takes what lies within reach as it moves, up to the fill
# limit. Never an NPC (D-160), and never what it put down itself
# until it has been out of that tile's reach (D-212).
func _auto_pickup(actor: Actor) -> void:
	if actor.actor_kind != ActorKind.ACTOR.PLAYER: return
	_pick_up(actor, tuning.auto_fill_limit, _still_dropped(actor))


# The tiles `actor` dropped on that are still in its reach; the rest
# are forgotten, so walking back to them later picks them up.
func _still_dropped(actor: Actor) -> Array[Vector2i]:
	var kept: Array[Vector2i] = []
	var id: int = actor.get_instance_id()
	if not _dropped_at.has(id): return kept
	var here: WorldPos = actor.current_WorldPos
	var near: Array = _dropped_at[id].filter(func(at: WorldPos) -> bool:
		return here != null and at.depth == here.depth 			and maxi(absi(at.x - here.x), absi(at.y - here.y)) <= tuning.pickup_reach)
	if near.is_empty():
		_dropped_at.erase(id)
		return kept
	_dropped_at[id] = near
	for at: WorldPos in near:
		kept.append(Vector2i(at.x, at.y))
	return kept


# The take key: everything within reach, whatever the load (D-160).
func _on_take_requested(actor: Actor) -> void:
	if actor == null or actor.current_level == null or actor.current_level.world != self: return
	# Facing a crate that holds something, the take empties it (D-224)
	var crate: Fixture = crate_faced(actor)
	if crate != null and not crate.contents.is_empty():
		took.emit(actor, _empty_crate(actor, crate))
		return
	took.emit(actor, _pick_up(actor, INF, []))


# Everything lying within an actor's reach, item id -> count: what the
# take key would take (D-160), and what the inventory's preview shows
# (D-172). A read, sharing the take's tiles so the two can't disagree.
func drops_in_reach(actor: Actor) -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	for tile: Vector2i in _reach_tiles(actor, []):
		var lying: Dictionary = actor.current_level.level_drops.at(tile)
		for id: StringName in lying:
			found[id] = found.get(id, 0) + lying[id]
	return found


# The tiles an actor picks up from: its own and those around it, out
# to the profile's reach, open and so not buried (D-166), less `skip`.
func _reach_tiles(actor: Actor, skip: Array[Vector2i]) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var level: Level = actor.current_level
	var here: WorldPos = actor.current_WorldPos
	if level == null or here == null or level.level_drops.is_empty(): return tiles
	var reach: int = tuning.pickup_reach
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var tile: Vector2i = Vector2i(here.x + dx, here.y + dy)
			if skip.has(tile): continue
			if level.level_tiles.get_top(tile.x, tile.y) != TileKind.TOP.OPEN: continue
			tiles.append(tile)
	return tiles


# Moves what fits under `limit` from the tiles in reach into the
# pack. Returns what it took, item id -> count.
func _pick_up(actor: Actor, limit: float, skip: Array[Vector2i]) -> Dictionary[StringName, int]:
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
	var reason: DIG_REFUSAL = dig_problem(tile, actor)
	if reason != DIG_REFUSAL.NONE:
		dig_refused.emit(actor, tile, reason)
		return
	_dig_tile(actor, tile)


# Why digging `tile` would be refused, or NONE. A read, so the dig
# capability asks before the work and a refusal is heard at once. The
# tool is the actor's in hand; with no actor, no tool is asked about.
func dig_problem(tile: WorldPos, actor: Actor = null) -> DIG_REFUSAL:
	var level: Level = level_at(tile.depth)
	if level == null:
		return DIG_REFUSAL.LEVEL_NOT_EXISTS
	var kind: int = level.level_tiles.get_top(tile.x, tile.y)
	if TileKind.is_sentinel(kind):
		return DIG_REFUSAL.TILE_NOT_EXISTS
	if kind == TileKind.TOP.CRUSHED:
		return DIG_REFUSAL.CRUSHED
	if not TileKind.is_diggable(kind):
		return DIG_REFUSAL.TILE_NOT_DIGGABLE
	if actor != null and not Digging.digs_ore(tuning, actor.tool(),
			level.level_tiles.get_ore(tile.x, tile.y)):
		return DIG_REFUSAL.TOOL_TOO_WEAK
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
		_give(actor, level, tile, found)
	# Marked before it opens, so the support rule hears of an excavated
	# tile (D-164)
	level.level_tiles.mark_excavated(tile.x, tile.y)
	level.level_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)
	level.level_tiles.set_ore(tile.x, tile.y, TileKind.ORE.NONE)
	tile_dug.emit(actor, tile)


# A yield into the actor's pack up to the fill limit; the rest drops
# where it came from (D-160).
func _give(actor: Actor, level: Level, tile: WorldPos, found: Dictionary[StringName, int]) -> void:
	for id: StringName in found:
		var fits: int = Carrying.fits(tuning, actor.pack, id, found[id], tuning.auto_fill_limit)
		actor.pack.add(id, fits)
		if found[id] > fits:
			level.level_drops.add(Vector2i(tile.x, tile.y), id, found[id] - fits)
			items_dropped.emit(actor, tile, id, found[id] - fits)


# --- felling trees (D-181) ---

# The tree standing on `tile`, or null.
func tree_at(tile: WorldPos) -> Fixture:
	var level: Level = level_at(tile.depth)
	if level == null: return null
	for fixture: Fixture in level.level_fixtures.at(Vector2i(tile.x, tile.y)):
		if fixture.kind == ObjectKind.OBJECT.TREE: return fixture
	return null


# Why felling the tree on `tile` would be refused, or NONE. A read:
# the capability asks before the work, so the wrong tool hears at once.
func chop_problem(tile: WorldPos, actor: Actor) -> CHOP_REFUSAL:
	if tree_at(tile) == null: return CHOP_REFUSAL.NO_TREE
	if actor != null and not Digging.chops(actor.tool()): return CHOP_REFUSAL.NEEDS_AXE
	return CHOP_REFUSAL.NONE


# The tree is removed like any fixture, and its timber given like a
# dig's yield.
func _on_chop_requested(actor: Actor, tile: WorldPos) -> void:
	var reason: CHOP_REFUSAL = chop_problem(tile, actor)
	if reason != CHOP_REFUSAL.NONE:
		chop_refused.emit(actor, tile, reason)
		return
	var level: Level = level_at(tile.depth)
	var tree: Fixture = level.level_fixtures.remove(tree_at(tile).id)
	fixture_removed.emit(actor, tree)
	if actor != null and tuning.tree_timber > 0:
		var timber: Dictionary[StringName, int] = {&"timber": tuning.tree_timber}
		_give(actor, level, tile, timber)
	tree_felled.emit(actor, tile)


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
	# A crate that stood there falls down the shaft (D-236)
	var at: Vector2i = Vector2i(tile.x, tile.y)
	var level: Level = level_at(tile.depth)
	var crate: Fixture = _fixture_of_kind(level, at, ObjectKind.OBJECT.CRATE)
	if crate == null: return
	var to: WorldPos = WorldPos.new(tile.x, tile.y, drop_point(at, tile.depth + 1))
	level.level_fixtures.remove(crate.id)
	level_at(to.depth).level_fixtures.receive(crate, to)
	fixture_moved.emit(actor, crate, tile)


# Why the shaft above `depth`'s floor at `at` and the one below it
# can't become one, or NONE (D-236): a winch's shaft takes no ladder or
# chute, and a shaft holds one crate.
func _join_problem(at: Vector2i, depth: int) -> BREACH_REFUSAL:
	var kinds: Array[int] = [ObjectKind.OBJECT.WINCH, ObjectKind.OBJECT.CHUTE,
		ObjectKind.OBJECT.CRATE, ObjectKind.OBJECT.LADDER]
	var up: Array[Fixture] = shaft_fixtures(at, depth, kinds)
	var down: Array[Fixture] = shaft_fixtures(at, depth + 1, kinds)
	var kinds_up: Array = up.map(func(f: Fixture) -> int: return f.kind)
	var kinds_down: Array = down.map(func(f: Fixture) -> int: return f.kind)
	var crate: int = ObjectKind.OBJECT.CRATE
	if crate in kinds_up and crate in kinds_down: return BREACH_REFUSAL.SHAFTS_CANT_JOIN
	var winch: int = ObjectKind.OBJECT.WINCH
	for pair: Array in [[kinds_up, kinds_down], [kinds_down, kinds_up]]:
		if winch in pair[0] and (ObjectKind.OBJECT.CHUTE in pair[1] or ObjectKind.OBJECT.LADDER in pair[1]):
			return BREACH_REFUSAL.SHAFTS_CANT_JOIN
	return BREACH_REFUSAL.NONE


# Why `crate`, let go at `depth`, has nowhere to come to rest, or NONE.
func _fall_problem(at: Vector2i, depth: int, crate: Fixture) -> FIXTURE_REFUSAL:
	return _crate_landing_problem(at, drop_point(at, depth), crate)


# Why `crate` can't come to rest at `depth` of the shaft at `at`, or
# NONE: hanging in a winch's hole where no other crate hangs, or on the
# foot, floor holding nothing, with nobody standing there.
func _crate_landing_problem(at: Vector2i, depth: int, crate: Fixture = null) -> FIXTURE_REFUSAL:
	var level: Level = level_at(depth)
	if level == null: return FIXTURE_REFUSAL.LEVEL_NOT_EXISTS
	if _fixture_of_kind(level, at, ObjectKind.OBJECT.WINCH) != null:
		var other: Fixture = _fixture_of_kind(level, at, ObjectKind.OBJECT.CRATE)
		if other != null and other != crate: return FIXTURE_REFUSAL.LANDING_BLOCKED
		return FIXTURE_REFUSAL.NONE
	var reason: FIXTURE_REFUSAL = Winch.landing_problem(level, at)
	if reason != FIXTURE_REFUSAL.NONE: return reason
	if blocks_actor(level, ObjectKind.OBJECT.CRATE, WorldPos.new(at.x, at.y, depth)):
		return FIXTURE_REFUSAL.LANDING_BLOCKED
	return FIXTURE_REFUSAL.NONE


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
	var at: Vector2i = Vector2i(tile.x, tile.y)
	# A crate standing on the foot of its shaft falls through (D-236)
	for fixture: Fixture in level.level_fixtures.at(at):
		if fixture.kind != ObjectKind.OBJECT.CRATE: return BREACH_REFUSAL.FIXTURE_ON_TILE
	if _actor_on(tile): return BREACH_REFUSAL.ACTOR_ON_TILE

	var below: Level = level_at(tile.depth + 1)
	if below == null: return BREACH_REFUSAL.NO_LEVEL_BELOW
	var landing: int = below.level_tiles.get_ground(tile.x, tile.y)
	var landing_top: int = below.level_tiles.get_top(tile.x, tile.y)
	if TileKind.is_sentinel(landing) or TileKind.is_sentinel(landing_top):
		return BREACH_REFUSAL.LANDING_NOT_EXISTS
	if landing == TileKind.GROUND.HOLE:
		# Over a hole the shaft below grows up (D-236): one with nothing
		# in it but a winch and its crate
		if landing_top != TileKind.TOP.OPEN: return BREACH_REFUSAL.LANDING_BLOCKED
		for fixture: Fixture in below.level_fixtures.at(at):
			if fixture.kind not in [ObjectKind.OBJECT.WINCH, ObjectKind.OBJECT.CRATE]:
				return BREACH_REFUSAL.LANDING_BLOCKED
		var reason: BREACH_REFUSAL = _join_problem(at, tile.depth)
		if reason != BREACH_REFUSAL.NONE: return reason
	elif not _is_plain_floor(landing) or not below.level_fixtures.at(at).is_empty():
		return BREACH_REFUSAL.LANDING_BLOCKED
	# The fallen crate needs room where it comes to rest
	# (on a plain landing, the floor the breach opens: nobody on it)
	var crate: Fixture = _fixture_of_kind(level, at, ObjectKind.OBJECT.CRATE)
	if crate != null:
		var on: WorldPos = WorldPos.new(tile.x, tile.y, tile.depth + 1)
		if landing == TileKind.GROUND.HOLE:
			if _fall_problem(at, tile.depth + 1, crate) != FIXTURE_REFUSAL.NONE:
				return BREACH_REFUSAL.LANDING_BLOCKED
		elif blocks_actor(below, ObjectKind.OBJECT.CRATE, on):
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

	var reason: FIXTURE_REFUSAL = _placement_problem(kind, tile, level)
	if reason != FIXTURE_REFUSAL.NONE:
		request_refused.emit(actor, FIXTURE_VERB.PLACE, tile, reason)
		return
	if blocks_actor(level, kind, tile):
		request_refused.emit(actor, FIXTURE_VERB.PLACE, tile, FIXTURE_REFUSAL.ACTOR_ON_TILE)
		return
	reason = shaft_problem(kind, tile)
	if reason != FIXTURE_REFUSAL.NONE:
		request_refused.emit(actor, FIXTURE_VERB.PLACE, tile, reason)
		return
	if kind == ObjectKind.OBJECT.WINCH:
		reason = winch_landing_problem(tile)
		if reason != FIXTURE_REFUSAL.NONE:
			request_refused.emit(actor, FIXTURE_VERB.PLACE, tile, reason)
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
	if kind == ObjectKind.OBJECT.WINCH: _make_crate(actor, tile)


# Why a winch over `tile`'s hole has nowhere for its crate, or NONE
# (D-224, D-235). A shaft that has a crate already shares it; one
# without needs room at the end of the new winch's rope: floor holding
# nothing at the foot, with nobody standing there. Asked by the
# gatekeeper and build mode's preview.
func winch_landing_problem(tile: WorldPos) -> FIXTURE_REFUSAL:
	var at: Vector2i = Vector2i(tile.x, tile.y)
	if level_at(tile.depth) != null and shaft_crate(at, tile.depth) != null:
		return FIXTURE_REFUSAL.NONE
	return _crate_landing_problem(at, rope_end(tile))


# A new winch's crate, empty, at the end of its rope (D-224). A shaft
# has one crate, so where it has one already none is made (D-235).
func _make_crate(actor: Actor, top: WorldPos) -> void:
	var at: Vector2i = Vector2i(top.x, top.y)
	if shaft_crate(at, top.depth) != null: return
	var crate: Fixture = Fixture.new(ObjectKind.OBJECT.CRATE,
		WorldPos.new(top.x, top.y, rope_end(top)), fixture_ids.allocate())
	crate.contents = Pack.new()
	level_at(crate.tile.depth).level_fixtures.add(crate)
	fixture_placed.emit(actor, crate)


# The placement rules for `kind` on `tile` of `level`, with the levels
# above and below it as this world holds them, so the one-use-per-hole
# rule (D-219) is checked both ways.
func _placement_problem(kind: int, tile: WorldPos, level: Level,
		ignoring: Fixture = null) -> FIXTURE_REFUSAL:
	var above: Level = level_at(tile.depth - 1)
	var below: Level = level_at(tile.depth + 1)
	return FixturePlacement.problem(kind, Vector2i(tile.x, tile.y), level.level_tiles,
		level.level_fixtures, above.level_tiles if above != null else null, ignoring,
		above.level_fixtures if above != null else null,
		below.level_fixtures if below != null else null)


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
	var reason: FIXTURE_REFUSAL = _placement_problem(fixture.kind, to, target, fixture)
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
