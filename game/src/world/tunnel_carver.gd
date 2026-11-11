class_name TunnelCarver
extends RefCounted

# Carves a meandering natural tunnel through a level's rock, from one
# tile to another (D-229): the way from -2's landing to its ramp down,
# and later 017's ruin corridors. Natural, like a cave: the tiles are
# opened without being marked excavated, so the support rule never
# judges them (D-164). Generation only, before anything listens, so
# no tile change is announced.
#
# The walk mostly steps toward the target along the longer axis, now
# and then along the shorter one, and now and then sideways, so it
# wanders without doubling back for long. Its width is redrawn every
# few steps.

# How the walk chooses each step: toward along the longer axis below
# the first share, toward along the shorter below the second, and
# sideways the rest of the time.
const TOWARD_LONG: float = 0.6
const TOWARD_SHORT: float = 0.85
# Steps between redrawing the width
const WIDTH_STRETCH: int = 8
# Tiles the walk keeps inside the level's edge
const EDGE_MARGIN: int = 2


# Opens a tunnel from `from` to `to` on `tiles`, drawing from `rng`.
# Returns every tile it opened, in order. Only minable rock and dirt
# are opened; open floor, ramps and anything outside the level are
# left as they are.
static func carve(tiles: LevelTiles, from: Vector2i, to: Vector2i, rng: RandomNumberGenerator,
		width_min: int, width_max: int) -> Array[Vector2i]:
	var opened: Array[Vector2i] = []
	var at: Vector2i = from
	var width: int = rng.randi_range(width_min, width_max)
	var distance: int = absi(to.x - from.x) + absi(to.y - from.y)
	var limit: int = distance * 4 + 50
	var steps: int = 0
	var inner: int = tiles.level_bound.radius - EDGE_MARGIN
	_open_wide(tiles, at, Vector2i.RIGHT, width, opened)
	while at != to:
		steps += 1
		if steps % WIDTH_STRETCH == 0: width = rng.randi_range(width_min, width_max)
		# Past the limit, the walk goes straight in
		var step: Vector2i = _toward(at, to, true) if steps > limit else _step(at, to, rng)
		var next: Vector2i = at + step
		if next.x * next.x + next.y * next.y > inner * inner:
			step = _toward(at, to, true)
			next = at + step
		at = next
		_open_wide(tiles, at, step, width, opened)
	return opened


# One step of the walk from `at` toward `to`.
static func _step(at: Vector2i, to: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var roll: float = rng.randf()
	if roll < TOWARD_LONG: return _toward(at, to, true)
	if roll < TOWARD_SHORT: return _toward(at, to, false)
	var along: Vector2i = _toward(at, to, true)
	var sideways: Vector2i = Vector2i(along.y, along.x)
	return sideways if rng.randf() < 0.5 else -sideways


# A unit step toward `to` along the longer axis, or the shorter one;
# along the longer when the shorter has no distance left.
static func _toward(at: Vector2i, to: Vector2i, longer: bool) -> Vector2i:
	var delta: Vector2i = to - at
	var x_is_longer: bool = absi(delta.x) >= absi(delta.y)
	var use_x: bool = x_is_longer == longer
	if use_x and delta.x == 0: use_x = false
	if not use_x and delta.y == 0: use_x = true
	if use_x: return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))


# Opens `at`, and for a width of two, the tile beside it across the
# direction of travel.
static func _open_wide(tiles: LevelTiles, at: Vector2i, travel: Vector2i, width: int,
		opened: Array[Vector2i]) -> void:
	_open(tiles, at, opened)
	if width >= 2: _open(tiles, at + Vector2i(travel.y, travel.x).abs(), opened)


static func _open(tiles: LevelTiles, tile: Vector2i, opened: Array[Vector2i]) -> void:
	var top: int = tiles.get_top(tile.x, tile.y)
	if top != TileKind.TOP.MINABLE_ROCK and top != TileKind.TOP.MINABLE_DIRT: return
	if TileKind.is_ramp(tiles.get_ground(tile.x, tile.y)): return
	tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN, true)
	tiles.set_ore(tile.x, tile.y, TileKind.ORE.NONE, true)
	opened.append(tile)
