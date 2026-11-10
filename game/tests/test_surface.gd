extends GutTest

# The Surface (D-180, D-181): an open meadow, a rock mass around the
# ramp and a rock quarter, a road from the meadow through a cut to the
# ramp with the spawn at its far end, and trees on the grass. Rules,
# not layouts: a change to one step shifts the draws of every later
# step (slice 012 trap 1).

var _tuning: TuningProfile


func before_each() -> void:
	_tuning = TuningProfile.default_profile()


func _surface(world_seed: int) -> Level:
	return autofree(LevelGenerator.generate_level(LevelRecipes.TABLE.get_recipe(0), world_seed,
		IdAllocator.new()))


# A fresh generation's layout, for the road and the quarter.
func _layout(world_seed: int) -> SurfaceGeneration.Layout:
	var recipe: LevelRecipe = LevelRecipes.TABLE.get_recipe(0)
	var level: Level = autofree(Global.level_packed_scene.instantiate())
	level.setup(0, world_seed, recipe.bound)
	var rng: RandomNumberGenerator = LevelGenerator.rng_for(level)
	var layout: SurfaceGeneration.Layout = SurfaceGeneration.before(level, rng, _tuning)
	LevelGenerator.apply_fixed_placements(level, recipe, IdAllocator.new())
	return SurfaceGeneration.after(level, layout, rng, _tuning, IdAllocator.new())


func _spawn(level: Level) -> Vector2i:
	var spawn: Fixture = level.level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN)[0]
	return Vector2i(spawn.tile.x, spawn.tile.y)


func _ramp(level: Level) -> Vector2i:
	return SurfaceGeneration._ramp_down(level.level_tiles)


# Every tile a walker reaches from `from`, through passable tiles not
# blocked by a fixture: ramps included.
func _reachable(level: Level, from: Vector2i) -> Dictionary[Vector2i, bool]:
	var tiles: LevelTiles = level.level_tiles
	var seen: Dictionary[Vector2i, bool] = {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = here + step
			if seen.has(next): continue
			if not TileKind.is_passable(tiles.get_top(next.x, next.y), tiles.get_ground(next.x, next.y)):
				continue
			if tiles.is_blocked(next.x, next.y): continue
			seen[next] = true
			queue.append(next)
	return seen


# --- the meadow and the rock ---

func test_the_meadow_is_open_grass_and_dirt_and_the_rock_is_solid() -> void:
	var level: Level = _surface(0)
	var tiles: LevelTiles = level.level_tiles
	var radius: int = tiles.level_bound.radius
	var counts: Dictionary = {}
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var ground: int = tiles.get_ground(x, y)
			if TileKind.is_sentinel(ground): continue
			var key: String = "%s/%s" % [ground, tiles.get_top(x, y)]
			counts[key] = counts.get(key, 0) + 1
	var grass: int = counts.get("%s/%s" % [TileKind.GROUND.GRASS, TileKind.TOP.OPEN], 0)
	assert_eq(counts.get("%s/%s" % [TileKind.GROUND.GRASS, TileKind.TOP.MINABLE_ROCK], 0), 0,
		"no grass under rock: grass is always open")
	var rock: int = counts.get("%s/%s" % [TileKind.GROUND.ROCK, TileKind.TOP.MINABLE_ROCK], 0)
	assert_gt(grass, 10000, "a meadow: %d grass" % grass)
	assert_gt(rock, 5000, "and rock: %d" % rock)


func test_rock_surrounds_the_ramp_and_fills_one_quarter() -> void:
	var layout: SurfaceGeneration.Layout = _layout(0)
	var level: Level = _surface(0)
	var tiles: LevelTiles = level.level_tiles
	var quarter: Vector2i = SurfaceGeneration.QUARTERS[layout.rock_quarter]
	var road: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in layout.road:
		for offset: Vector2i in SurfaceGeneration._width(_tuning.surface_road_width):
			road[tile + offset] = true
	# A ring 15 tiles out from the start room at the axis, where the
	# ramp is, and a point deep in the quarter
	var rock: int = 0
	var ring: int = 0
	for i in range(36):
		var tile: Vector2i = Vector2i(Vector2.from_angle(TAU * i / 36.0) * 15.0)
		if road.has(tile): continue
		ring += 1
		if tiles.get_top(tile.x, tile.y) == TileKind.TOP.MINABLE_ROCK: rock += 1
	assert_eq(rock, ring, "solid rock 15 tiles round the start room, except the cut")
	var deep: Vector2i = quarter * 60
	assert_eq(tiles.get_top(deep.x, deep.y), TileKind.TOP.MINABLE_ROCK, "the rock quarter")
	var opposite: Vector2i = -quarter * 60
	assert_eq(tiles.get_top(opposite.x, opposite.y) == TileKind.TOP.OPEN
		or level.level_tiles.is_blocked(opposite.x, opposite.y), true, "the meadow opposite it")


# --- the road (trap 2) ---

func test_the_road_reaches_the_ramp_open_all_the_way_from_the_spawn() -> void:
	for world_seed: int in [0, 1, 2, 3, 4]:
		var level: Level = _surface(world_seed)
		var reach: Dictionary[Vector2i, bool] = _reachable(level, _spawn(level))
		assert_true(reach.has(_ramp(level)), "seed %d: the spawn walks to the ramp" % world_seed)


func test_the_road_is_dirt_two_wide_and_the_spawn_is_its_far_end() -> void:
	var layout: SurfaceGeneration.Layout = _layout(0)
	var level: Level = _surface(0)
	var tiles: LevelTiles = level.level_tiles
	assert_eq(_spawn(level), layout.road[0], "the spawn starts the road")
	assert_almost_eq(Vector2(layout.road[0] - layout.ramp).length(), _tuning.surface_road_length,
		2.0, "about the profile's length out")
	var wrong: Array[Vector2i] = []
	for tile: Vector2i in layout.road:
		for offset: Vector2i in SurfaceGeneration._width(2):
			var at: Vector2i = tile + offset
			if TileKind.is_ramp(tiles.get_ground(at.x, at.y)): continue
			if tiles.get_ground(at.x, at.y) != TileKind.GROUND.DIRT \
					or tiles.get_top(at.x, at.y) != TileKind.TOP.OPEN:
				wrong.append(at)
	assert_eq(wrong, [] as Array[Vector2i], "every road tile is open dirt")
	assert_eq(level.level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN).size(), 1, "one spawn")


func test_the_road_winds() -> void:
	var layout: SurfaceGeneration.Layout = _layout(0)
	var straight: float = Vector2(layout.road[0] - layout.road[-1]).length()
	assert_gt(float(layout.road.size()), straight * 1.1, "longer than a straight line: it bends")


# --- dirt and trees (D-181, trap 3) ---

func test_some_of_the_meadow_is_dirt() -> void:
	var level: Level = _surface(0)
	var dirt: int = SurfaceGeneration._open_with_ground(level.level_tiles, TileKind.GROUND.DIRT).size()
	var grass: int = SurfaceGeneration._open_with_ground(level.level_tiles, TileKind.GROUND.GRASS).size()
	var share: float = float(dirt) / float(dirt + grass)
	assert_between(share, 0.08, 0.16, "about a tenth dirt, the road included: %.3f" % share)


func test_trees_stand_on_grass_off_the_road_and_in_number() -> void:
	var layout: SurfaceGeneration.Layout = _layout(0)
	var level: Level = _surface(0)
	var tiles: LevelTiles = level.level_tiles
	var trees: Array[Fixture] = level.level_fixtures.of_kind(ObjectKind.OBJECT.TREE)
	var grass: int = SurfaceGeneration._open_with_ground(tiles, TileKind.GROUND.GRASS).size()
	assert_between(trees.size(), int(grass * 0.03), int(grass * 0.05),
		"about 4%% of the grass: %d of %d" % [trees.size(), grass])
	var road: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in layout.road: road[tile] = true
	var off_grass: Array[Vector2i] = []
	var by_road: Array[Vector2i] = []
	for tree: Fixture in trees:
		var at: Vector2i = Vector2i(tree.tile.x, tree.tile.y)
		if tiles.get_ground(at.x, at.y) != TileKind.GROUND.GRASS \
				or tiles.get_top(at.x, at.y) != TileKind.TOP.OPEN:
			off_grass.append(at)
		for dy in range(-2, 2):
			for dx in range(-2, 2):
				if road.has(at + Vector2i(dx, dy)) and not by_road.has(at): by_road.append(at)
	assert_eq(off_grass, [] as Array[Vector2i], "every tree on open grass")
	assert_eq(by_road, [] as Array[Vector2i], "every tree clear of the road")
	assert_eq(FixturePlacement.problems([level] as Array[Level]), [] as Array[String],
		"every tree passes the gatekeeper's rules")


# --- the seed (D-180) ---

func test_the_same_seed_builds_the_same_surface_and_another_a_different_one() -> void:
	var a: Level = _surface(7)
	var b: Level = _surface(7)
	var c: Level = _surface(8)
	assert_true(a.level_tiles.ground == b.level_tiles.ground, "same seed, same ground")
	assert_eq(_spawn(a), _spawn(b), "same spawn")
	assert_eq(a.level_fixtures.of_kind(ObjectKind.OBJECT.TREE).size(),
		b.level_fixtures.of_kind(ObjectKind.OBJECT.TREE).size(), "same trees")
	assert_false(a.level_tiles.ground == c.level_tiles.ground, "another seed, another Surface")


func test_a_new_world_starts_on_the_road() -> void:
	var world: World = autofree(LevelGenerator.generate_world(0))
	var spawn: Fixture = Spawning.world_spawn(world.levels())
	assert_not_null(spawn, "one spawn")
	if spawn: assert_eq(spawn.tile.depth, 0, "on the Surface")
