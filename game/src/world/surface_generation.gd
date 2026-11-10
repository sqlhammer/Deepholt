class_name SurfaceGeneration
extends RefCounted

# The Surface's own generation (D-180): an open meadow of grass and
# dirt under open sky, a mass of rock around the ramp down and one
# quarter of rock, a winding dirt road from the meadow through a cut
# in the rock to the ramp, the world spawn at the road's far end, and
# trees on the grass (D-181). Every number is the profile's (D-135).
#
# Two passes around the recipe's fixed placement: `before` lays the
# meadow and the rock, so the start room is stamped into it; `after`
# cuts the road, scatters dirt, places the spawn and plants the trees.
# Each draws from the level's one generator in a fixed order, so the
# same seed builds the same Surface (D-084). A change to one step
# shifts every later step's draws: tests pin rules, not tiles.

# The quarter of the level the rock fills, and the one the road starts
# in (the opposite one), as signs of x and y.
const QUARTERS: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]


# What the passes found, for `after` and for tests.
class Layout:
	var rock_quarter: int = 0
	var road: Array[Vector2i] = []
	var spawn: Vector2i
	var ramp: Vector2i


# The meadow and the rock: every tile open grass, then solid rock in
# the chosen quarter and in a disc around the origin, where the start
# room and its ramp are stamped next (the ramp is a few tiles off the
# origin, inside the disc).
static func before(level: Level, rng: RandomNumberGenerator, tuning: TuningProfile) -> Layout:
	var layout: Layout = Layout.new()
	layout.rock_quarter = rng.randi_range(0, QUARTERS.size() - 1)
	var tiles: LevelTiles = level.level_tiles
	var radius: int = tiles.level_bound.radius
	var width: int = 2 * radius + 1
	var quarter: Vector2i = QUARTERS[layout.rock_quarter]
	var rock_radius_squared: int = tuning.surface_rock_radius * tuning.surface_rock_radius
	# Built as whole layers and loaded at once: a setter per tile, with
	# its signal, made this most of a new world's time
	var ground: PackedByteArray = tiles.ground
	var top: PackedByteArray = tiles.top
	var ore: PackedByteArray = tiles.ore
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + y * y > radius * radius: continue
			var index: int = (y + radius) * width + (x + radius)
			var rock: bool = x * x + y * y <= rock_radius_squared \
				or _in_quarter(Vector2i(x, y), quarter)
			ground[index] = TileKind.GROUND.ROCK if rock else TileKind.GROUND.GRASS
			top[index] = TileKind.TOP.MINABLE_ROCK if rock else TileKind.TOP.OPEN
			ore[index] = TileKind.ORE.NONE
	tiles.bulk_load_tile_arrays({"ground": ground, "top": top, "ore": ore})
	return layout


# The road, the dirt, the spawn and the trees, once the start room is
# stamped. Returns the layout, with the road and spawn filled in.
static func after(level: Level, layout: Layout, rng: RandomNumberGenerator,
		tuning: TuningProfile, fixture_ids: IdAllocator) -> Layout:
	layout.ramp = _ramp_down(level.level_tiles)
	layout.road = _road(level.level_tiles, layout, rng, tuning)
	_dirt_patches(level.level_tiles, rng, tuning)
	layout.spawn = layout.road[0]
	level.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.WORLD_SPAWN,
		WorldPos.new(layout.spawn.x, layout.spawn.y, level.depth), fixture_ids.allocate()))
	_trees(level, layout, rng, tuning, fixture_ids)
	return layout


# The quarter a tile is in; the axes belong to the positive side.
static func quarter_of(tile: Vector2i) -> Vector2i:
	return Vector2i(1 if tile.x >= 0 else -1, 1 if tile.y >= 0 else -1)


static func _in_quarter(tile: Vector2i, quarter: Vector2i) -> bool:
	return quarter_of(tile) == quarter


# The ramp down the start room holds: the road's end.
static func _ramp_down(tiles: LevelTiles) -> Vector2i:
	var ground: PackedByteArray = tiles.ground
	var radius: int = tiles.level_bound.radius
	var width: int = 2 * radius + 1
	for kind: int in TileKind.RAMPS:
		if not TileKind.RAMPS[kind].down: continue
		var index: int = ground.find(kind)
		if index != -1: return Vector2i(index % width - radius, index / width - radius)
	push_error("The Surface has no ramp down for its road to lead to.")
	return Vector2i.ZERO


# --- the road (trap 2: it must reach the ramp, open all the way) ---

# From a point out on the meadow in the quarter opposite the rock, a
# walk of straight legs, each bending toward the ramp by a random
# angle, until it's close; then straight in to the tile you step onto
# the ramp from. Each leg is cut two wide: dirt ground, open top. The
# ramp and anything stamped as a ramp or hole is left as it is.
static func _road(tiles: LevelTiles, layout: Layout, rng: RandomNumberGenerator,
		tuning: TuningProfile) -> Array[Vector2i]:
	var downhill: Vector2i = TileKind.RAMPS[tiles.get_ground(layout.ramp.x, layout.ramp.y)].downhill
	var approach: Vector2 = Vector2(layout.ramp - downhill)
	var quarter: Vector2i = QUARTERS[(layout.rock_quarter + 2) % QUARTERS.size()]
	var angle: float = Vector2(quarter).angle() + rng.randf_range(-0.35, 0.35)
	var start: Vector2 = approach + Vector2.from_angle(angle) * tuning.surface_road_length
	var points: Array[Vector2] = [start.round()]
	var here: Vector2 = start
	var guard: int = 0
	while here.distance_to(approach) > tuning.surface_road_bend_max and guard < 64:
		guard += 1
		var toward: float = (approach - here).angle() + rng.randf_range(-0.8, 0.8)
		var leg: float = rng.randf_range(tuning.surface_road_bend_min, tuning.surface_road_bend_max)
		here += Vector2.from_angle(toward) * leg
		points.append(here.round())
	points.append(approach)
	var road: Array[Vector2i] = []
	for i in range(points.size() - 1):
		for tile: Vector2i in _line(Vector2i(points[i]), Vector2i(points[i + 1])):
			if road.is_empty() or road[-1] != tile: road.append(tile)
	for tile: Vector2i in road:
		for offset: Vector2i in _width(tuning.surface_road_width):
			_cut(tiles, tile + offset)
	# Onto the ramp from its approach: the tile before it in, open
	_cut(tiles, Vector2i(approach))
	return road


static func _width(width: int) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for dy in range(width):
		for dx in range(width):
			offsets.append(Vector2i(dx, dy))
	return offsets


static func _cut(tiles: LevelTiles, tile: Vector2i) -> void:
	var ground: int = tiles.get_ground(tile.x, tile.y)
	if TileKind.is_sentinel(ground) or TileKind.is_ramp(ground) or ground == TileKind.GROUND.HOLE:
		return
	# Quietly: nothing listens to a level still being generated
	tiles.set_ground(tile.x, tile.y, TileKind.GROUND.DIRT, true)
	tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN, true)
	tiles.set_ore(tile.x, tile.y, TileKind.ORE.NONE, true)


# The tiles of a straight line, 4-connected so a two-wide cut of it
# has no diagonal pinch a walker can't pass.
static func _line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = [from]
	var here: Vector2i = from
	while here != to:
		var left: Vector2i = to - here
		# Step along the axis with further to go
		if absi(left.x) >= absi(left.y): here.x += signi(left.x)
		else: here.y += signi(left.y)
		tiles.append(here)
	return tiles


# --- dirt and trees ---

# Patches of dirt ground on the open grass until the profile's share
# of the meadow is dirt: small round blobs at random spots.
static func _dirt_patches(tiles: LevelTiles, rng: RandomNumberGenerator,
		tuning: TuningProfile) -> void:
	var grass: Array[Vector2i] = _open_with_ground(tiles, TileKind.GROUND.GRASS)
	var target: int = roundi(grass.size() * tuning.surface_dirt_share)
	var made: int = 0
	var guard: int = 0
	while made < target and not grass.is_empty() and guard < 10000:
		guard += 1
		var center: Vector2i = grass[rng.randi_range(0, grass.size() - 1)]
		var size: int = rng.randi_range(1, 3)
		for dy in range(-size, size + 1):
			for dx in range(-size, size + 1):
				if dx * dx + dy * dy > size * size: continue
				var tile: Vector2i = center + Vector2i(dx, dy)
				if tiles.get_ground(tile.x, tile.y) != TileKind.GROUND.GRASS: continue
				if tiles.get_top(tile.x, tile.y) != TileKind.TOP.OPEN: continue
				tiles.set_ground(tile.x, tile.y, TileKind.GROUND.DIRT, true)
				made += 1


# A tree on each open grass tile by the profile's chance, kept clear of
# the road and the spawn, and only where the gatekeeper's rules allow
# (trap 3). Tiles are taken row by row, so the same seed plants the
# same trees.
static func _trees(level: Level, layout: Layout, rng: RandomNumberGenerator,
		tuning: TuningProfile, fixture_ids: IdAllocator) -> void:
	var tiles: LevelTiles = level.level_tiles
	var clear: Dictionary[Vector2i, bool] = {}
	var reach: int = tuning.surface_tree_clearance
	# Each road tile is the corner of a cut `width` wide
	var span: int = reach + tuning.surface_road_width
	for tile: Vector2i in layout.road + ([layout.spawn] as Array[Vector2i]):
		for dy in range(-reach, span):
			for dx in range(-reach, span):
				clear[tile + Vector2i(dx, dy)] = true
	for tile: Vector2i in _open_with_ground(tiles, TileKind.GROUND.GRASS):
		if rng.randf() >= tuning.surface_tree_share: continue
		if clear.has(tile): continue
		if FixturePlacement.problem(ObjectKind.OBJECT.TREE, tile, tiles, level.level_fixtures,
				null) != World.FIXTURE_REFUSAL.NONE: continue
		level.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.TREE,
			WorldPos.new(tile.x, tile.y, level.depth), fixture_ids.allocate()))


# Open tiles with a ground kind, row by row.
static func _open_with_ground(tiles: LevelTiles, kind: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var ground: PackedByteArray = tiles.ground
	var top: PackedByteArray = tiles.top
	var radius: int = tiles.level_bound.radius
	var width: int = 2 * radius + 1
	# The array's own find, then the top: row by row, as the index runs
	var index: int = ground.find(kind)
	while index != -1:
		if top[index] == TileKind.TOP.OPEN:
			found.append(Vector2i(index % width - radius, index / width - radius))
		index = ground.find(kind, index + 1)
	return found
