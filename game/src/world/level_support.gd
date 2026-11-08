class_name LevelSupport
extends RefCounted

# Whether one level's excavations are held up (D-163, digging-and-
# structure §2): every excavated open tile (D-164) is Stable within R
# tiles (Chebyshev) of a support, Marginal one tile further, and
# Failing beyond that. A support is a solid wall that isn't rubble, a
# prop, or the edge of the level. A failing region (tiles joined
# edge to edge) runs one countdown, shared by all its tiles; when it
# runs out the region is due to collapse.
#
# Derived from the level's tiles and fixtures and never saved, except
# for the countdowns, which are the one piece of this that can't be
# worked out again (to_save, restore). It decides nothing about the
# tiles: it announces that a collapse is due, and the world, the only
# thing that changes tiles at runtime (D-078), carries it out.
#
# Cheap enough to run on every dig (slice 010 trap 1): a change
# recomputes only the tiles within R + 1 of it, with a distance
# transform over the window that can reach them, and never the level.

enum STATE {
	NONE,
	STABLE,
	MARGINAL,
	FAILING,
}

# Judged tiles whose state changed, were judged for the first time or
# stopped being judged (rubble, a refill). Once per change, not per
# tile.
signal states_changed(tiles: Array[Vector2i])
# A region began its countdown: all its tiles, once. A tile joining a
# region already running doesn't start another.
signal region_failing(tiles: Array[Vector2i])
# These tiles' countdown ran out. The world turns them into rubble.
signal collapse_due(tiles: Array[Vector2i])

const STEPS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
# Further than any support can be
const FAR: int = 1 << 20

# R for this level: how far a support holds. Negative: no ceiling here
# (the Surface), so nothing is judged.
var radius: int
var countdown_seconds: float

var _level: Level
var _tiles: LevelTiles
# Judged tile -> its STATE. A tile that isn't judged has no entry.
var _states: Dictionary[Vector2i, int] = {}
# Failing tile -> the moment, on this clock, its region falls. Every
# tile of a region holds the same moment (trap 3).
var _deadlines: Dictionary[Vector2i, float] = {}
# The tiles a prop stands on, kept from the level's fixtures
var _props: Dictionary[Vector2i, bool] = {}
# Seconds this level has run, advanced only by `advance`. Deadlines
# are on it, so ticking costs nothing however big a region is.
var _clock: float = 0.0
var _next_due: float = INF
# While held, changes are gathered into one box and refreshed once on
# release: a collapse changes a thousand tiles and must not refresh a
# thousand times.
var _holds: int = 0
var _dirty: Rect2i = Rect2i()
var _is_dirty: bool = false


func _init(p_level: Level, p_radius: int, p_countdown_seconds: float) -> void:
	_level = p_level
	_tiles = p_level.level_tiles
	radius = p_radius
	countdown_seconds = p_countdown_seconds
	_tiles.tile_changed.connect(_on_tile_changed)
	p_level.fixtures_changed.connect(_on_fixtures_changed)
	p_level.fixtures_moved.connect(_on_fixtures_moved)
	p_level.fixtures_replaced.connect(_on_fixtures_replaced)
	_gather_props()
	rebuild()


# --- the rule ---

# The state of a tile that is `distance` from its nearest support.
static func state_for(distance: int, reach: int) -> STATE:
	if distance <= reach: return STATE.STABLE
	if distance == reach + 1: return STATE.MARGINAL
	return STATE.FAILING


# Judges every excavated tile again from scratch. For a level just
# taken in (a load, or a test that dug before the world listened); a
# change afterward only needs `_refresh`.
func rebuild() -> void:
	_states.clear()
	_deadlines.clear()
	var excavated: Array[Vector2i] = _tiles.excavated_tiles()
	if radius >= 0 and not excavated.is_empty():
		var low: Vector2i = excavated[0]
		var high: Vector2i = excavated[0]
		for tile: Vector2i in excavated:
			low = Vector2i(mini(low.x, tile.x), mini(low.y, tile.y))
			high = Vector2i(maxi(high.x, tile.x), maxi(high.y, tile.y))
		_refresh(Rect2i(low, high - low + Vector2i.ONE))
	_recompute_next_due()


# --- reading ---

func state_at(tile: Vector2i) -> STATE:
	return _states.get(tile, STATE.NONE) as STATE


# Every tile the rule judges, with its state. A copy.
func judged_tiles() -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	found.assign(_states.keys())
	return found


func failing_tiles() -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	found.assign(_deadlines.keys())
	return found


func has_failing() -> bool:
	return not _deadlines.is_empty()


# Seconds left before the tile's region falls, or -1 if it isn't
# failing.
func remaining_at(tile: Vector2i) -> float:
	if not _deadlines.has(tile): return -1.0
	return maxf(_deadlines[tile] - _clock, 0.0)


# How far into its countdown the tile's region is: 0 as it began,
# 1 as it falls. 0 for a tile that isn't failing. A tile that joined a
# region already running starts with the region's progress.
func progress_at(tile: Vector2i) -> float:
	if not _deadlines.has(tile) or countdown_seconds <= 0.0: return 0.0
	return clampf(1.0 - (_deadlines[tile] - _clock) / countdown_seconds, 0.0, 1.0)


# --- time ---

# Runs every countdown on by `delta` seconds. A region whose time is
# up is announced as due; the world carries the collapse out, and the
# resulting change takes its tiles off the clock.
func advance(delta: float) -> void:
	_clock += delta
	if _clock < _next_due: return
	var due: Array[Vector2i] = []
	for tile: Vector2i in _deadlines:
		if _deadlines[tile] <= _clock: due.append(tile)
	if due.is_empty():
		_recompute_next_due()
		return
	collapse_due.emit(due)


# Gathers changes until the matching release, then judges them once.
func hold() -> void:
	_holds += 1


func release() -> void:
	_holds = maxi(_holds - 1, 0)
	if _holds > 0 or not _is_dirty: return
	var box: Rect2i = _dirty
	_is_dirty = false
	_refresh(box)


# --- saving (D-163: the countdown is saved) ---

# One entry per region: the seconds it has left and its tiles as a
# flat list of x, y pairs, plain types only (D-109).
func to_save() -> Array:
	var by_deadline: Dictionary[float, Array] = {}
	for tile: Vector2i in _deadlines:
		var deadline: float = _deadlines[tile]
		if not by_deadline.has(deadline): by_deadline[deadline] = []
		by_deadline[deadline].append(tile.x)
		by_deadline[deadline].append(tile.y)
	var data: Array = []
	for deadline: float in by_deadline:
		data.append({"remaining": maxf(deadline - _clock, 0.0), "tiles": by_deadline[deadline]})
	return data


# Puts a saved countdown back on the tiles that are failing now. A tile
# the rule no longer calls failing (the profile changed, say) keeps
# nothing; one failing with no saved time keeps the fresh countdown it
# was given. Malformed entries are skipped with a warning.
func restore(saved: Variant) -> void:
	if not saved is Array: return
	var restored: Array[Vector2i] = []
	for entry: Variant in saved:
		if not entry is Dictionary or not (entry.get("remaining") is float or entry.get("remaining") is int) \
				or not entry.get("tiles") is Array or entry.tiles.size() % 2 != 0:
			push_warning("A countdown on depth %d isn't a region; skipped: %s" % [_level.depth, entry])
			continue
		var remaining: float = float(entry.remaining)
		for index: int in range(0, entry.tiles.size(), 2):
			if not entry.tiles[index] is int or not entry.tiles[index + 1] is int: continue
			var tile: Vector2i = Vector2i(entry.tiles[index], entry.tiles[index + 1])
			if state_at(tile) != STATE.FAILING: continue
			_deadlines[tile] = _clock + remaining
			restored.append(tile)
	# A region keeps the soonest of its tiles' times
	_assign_deadlines(restored)
	_recompute_next_due()


# --- listening ---

func _on_tile_changed(x: int, y: int, layer: LevelTiles.LAYER, _source: LevelTiles) -> void:
	if layer != LevelTiles.LAYER.TOP: return
	_changed(Rect2i(x, y, 1, 1))


func _on_fixtures_changed(fixture: Fixture, added: bool) -> void:
	if not ObjectKind.holds_ceiling(fixture.kind): return
	var tile: Vector2i = Vector2i(fixture.tile.x, fixture.tile.y)
	if added: _props[tile] = true
	else: _props.erase(tile)
	_changed(Rect2i(tile, Vector2i.ONE))


func _on_fixtures_moved(fixture: Fixture, from: WorldPos) -> void:
	if not ObjectKind.holds_ceiling(fixture.kind): return
	var old_tile: Vector2i = Vector2i(from.x, from.y)
	var new_tile: Vector2i = Vector2i(fixture.tile.x, fixture.tile.y)
	_props.erase(old_tile)
	_props[new_tile] = true
	_changed(Rect2i(old_tile, Vector2i.ONE))
	_changed(Rect2i(new_tile, Vector2i.ONE))


func _on_fixtures_replaced() -> void:
	_gather_props()
	rebuild()


func _gather_props() -> void:
	_props.clear()
	for fixture: Fixture in _level.level_fixtures.all():
		if ObjectKind.holds_ceiling(fixture.kind):
			_props[Vector2i(fixture.tile.x, fixture.tile.y)] = true


func _changed(box: Rect2i) -> void:
	if _holds > 0:
		_dirty = _dirty.merge(box) if _is_dirty else box
		_is_dirty = true
		return
	_refresh(box)


# --- judging ---

# Judges the tiles a change inside `changed` can have moved (trap 2):
# those within R + 1 of it, since a support further than R + 1 from a
# tile can't change what state it is in. The supports that matter to
# them lie within R + 1 more.
func _refresh(changed: Rect2i) -> void:
	if radius < 0: return
	var affected: Rect2i = changed.grow(radius + 1)
	var judged: Array[Vector2i] = []
	var stale: Array[Vector2i] = []
	for y in range(affected.position.y, affected.end.y):
		for x in range(affected.position.x, affected.end.x):
			var tile: Vector2i = Vector2i(x, y)
			if _tiles.is_excavated(x, y) and _tiles.get_top(x, y) == TileKind.TOP.OPEN:
				judged.append(tile)
			elif _states.has(tile):
				stale.append(tile)
	if judged.is_empty() and stale.is_empty(): return

	var changed_tiles: Array[Vector2i] = []
	for tile: Vector2i in stale:
		_states.erase(tile)
		_deadlines.erase(tile)
		changed_tiles.append(tile)

	var newly_failing: Array[Vector2i] = []
	if not judged.is_empty():
		var window: Rect2i = affected.grow(radius + 1)
		var distances: PackedInt32Array = _distances(window)
		var width: int = window.size.x
		for tile: Vector2i in judged:
			var distance: int = distances[(tile.y - window.position.y) * width \
				+ (tile.x - window.position.x)]
			var wanted: int = state_for(distance, radius)
			if _states.get(tile, STATE.NONE) == wanted: continue
			_states[tile] = wanted
			changed_tiles.append(tile)
			if wanted == STATE.FAILING:
				newly_failing.append(tile)
			else:
				_deadlines.erase(tile)

	var began: Array = _assign_deadlines(newly_failing)
	_recompute_next_due()
	if changed_tiles.is_empty(): return
	states_changed.emit(changed_tiles)
	for region: Array in began:
		var tiles: Array[Vector2i] = []
		tiles.assign(region)
		region_failing.emit(tiles)


# Gives each region touching one of `starts` its deadline (trap 3): the
# soonest any of its tiles already holds, so a tile that joins keeps
# the region's time and two regions a new tile bridges become one on
# the sooner. A region with no time at all begins a countdown. Returns
# the regions that did, each as an array of tiles.
func _assign_deadlines(starts: Array[Vector2i]) -> Array:
	var began: Array = []
	var seen: Dictionary[Vector2i, bool] = {}
	for start: Vector2i in starts:
		if seen.has(start): continue
		seen[start] = true
		var region: Array[Vector2i] = [start]
		var next: int = 0
		var soonest: float = INF
		while next < region.size():
			var tile: Vector2i = region[next]
			next += 1
			if _deadlines.has(tile): soonest = minf(soonest, _deadlines[tile])
			for step: Vector2i in STEPS:
				var neighbor: Vector2i = tile + step
				if seen.has(neighbor) or _states.get(neighbor, STATE.NONE) != STATE.FAILING: continue
				seen[neighbor] = true
				region.append(neighbor)
		var fresh: bool = is_inf(soonest)
		var deadline: float = _clock + countdown_seconds if fresh else soonest
		for tile: Vector2i in region:
			_deadlines[tile] = deadline
		if fresh: began.append(region)
	return began


func _recompute_next_due() -> void:
	_next_due = INF
	for deadline: float in _deadlines.values():
		_next_due = minf(_next_due, deadline)


# Each window tile's Chebyshev distance to the nearest support, row by
# row. Two passes over the window, each looking at four neighbors, give
# the exact distance; no tile is compared with every support. A tile
# outside the level counts as a support: the mountain's edge holds.
func _distances(window: Rect2i) -> PackedInt32Array:
	var width: int = window.size.x
	var height: int = window.size.y
	var distances: PackedInt32Array = PackedInt32Array()
	distances.resize(width * height)
	var top: PackedByteArray = _tiles.top
	var bound_radius: int = _tiles.level_bound.radius
	var array_width: int = 2 * bound_radius + 1
	var limit: int = bound_radius * bound_radius
	var has_props: bool = not _props.is_empty()
	var index: int = 0
	for y in range(window.position.y, window.end.y):
		for x in range(window.position.x, window.end.x):
			var solid: bool = false
			if absi(x) > bound_radius or absi(y) > bound_radius or x * x + y * y > limit:
				solid = true
			else:
				var kind: int = top[(y + bound_radius) * array_width + x + bound_radius]
				solid = kind in TileKind.SUPPORTING
				if not solid and has_props: solid = _props.has(Vector2i(x, y))
			distances[index] = 0 if solid else FAR
			index += 1

	# Forward: from the west, north-west, north and north-east
	for row in range(height):
		for column in range(width):
			index = row * width + column
			var best: int = distances[index]
			if best == 0: continue
			if column > 0: best = mini(best, distances[index - 1] + 1)
			if row > 0:
				best = mini(best, distances[index - width] + 1)
				if column > 0: best = mini(best, distances[index - width - 1] + 1)
				if column < width - 1: best = mini(best, distances[index - width + 1] + 1)
			distances[index] = best
	# Backward: from the east, south-east, south and south-west
	for row in range(height - 1, -1, -1):
		for column in range(width - 1, -1, -1):
			index = row * width + column
			var best: int = distances[index]
			if best == 0: continue
			if column < width - 1: best = mini(best, distances[index + 1] + 1)
			if row < height - 1:
				best = mini(best, distances[index + width] + 1)
				if column < width - 1: best = mini(best, distances[index + width + 1] + 1)
				if column > 0: best = mini(best, distances[index + width - 1] + 1)
			distances[index] = best
	return distances
