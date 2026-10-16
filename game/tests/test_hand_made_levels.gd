extends GutTest

# Slice 002's hand-made levels, built through their recipes (D-083,
# D-084). What's pinned here is what the slice's by-hand outcomes rely
# on: the levels line up where they connect, and the corridor from the
# ladder reaches each level's edge (NOW.md trap 7).

# Where the ladder will stand on -2, under a hole on -1 (D-089).
const LADDER: Vector2i = Vector2i(14, -2)


func _level(depth: int) -> Level:
	var level: Level = LevelGenerator.generate_level(World.level_recipes.get_recipe(depth))
	autofree(level)
	return level


func _is_open(level: Level, tile: Vector2i) -> bool:
	return level.level_tiles.get_top(tile.x, tile.y) == TileKind.TOP.OPEN


func test_the_new_prefabs_load_by_id() -> void:
	assert_not_null(TilePrefabRegistry.get_prefab(&"rootshelf_home"), "-1's prefab")
	assert_not_null(TilePrefabRegistry.get_prefab(&"greyseam_landing"), "-2's prefab")


# A ramp placed anywhere in the Surface's start room lands on open
# floor on -1.
func test_every_open_tile_of_the_surface_start_room_is_open_on_minus_one() -> void:
	var surface: Level = _level(0)
	var rootshelf: Level = _level(1)
	var checked: int = 0
	for y in range(-3, 3):
		for x in range(-1, 7):
			if not _is_open(surface, Vector2i(x, y)): continue
			checked += 1
			assert_true(_is_open(rootshelf, Vector2i(x, y)),
				"(%d, %d) is open on the Surface and on -1" % [x, y])
	assert_gt(checked, 20, "the start room was actually checked")


func test_minus_one_has_a_hole_at_the_ladder_spot() -> void:
	var tiles: LevelTiles = _level(1).level_tiles
	assert_eq(tiles.get_ground(LADDER.x, LADDER.y), TileKind.GROUND.HOLE, "a hole on -1")
	assert_eq(tiles.get_top(LADDER.x, LADDER.y), TileKind.TOP.OPEN, "under an open top")


func test_minus_two_has_a_ladder_at_the_ladder_spot() -> void:
	var level: Level = _level(2)
	assert_true(_is_open(level, LADDER), "the ladder stands on open floor")
	assert_true(level.level_fixtures.has_kind_at(LADDER, ObjectKind.OBJECT.LADDER), "a ladder on -2")
	assert_eq(level.level_fixtures.of_kind(ObjectKind.OBJECT.LADDER).size(), 1, "just the one")


func test_the_hand_made_levels_have_no_ladder_problems() -> void:
	var levels: Array[Level] = LevelGenerator.generate_levels(World.level_recipes)
	for level in levels: autofree(level)
	assert_eq(LevelGenerator.ladder_problems(levels), [] as Array[String], "the ladder has its hole")


func test_minus_one_corridor_runs_from_the_ladder_room_to_the_edge() -> void:
	var level: Level = _level(1)
	var radius: int = level.level_tiles.level_bound.radius
	for x in range(LADDER.x, radius + 1):
		assert_true(_is_open(level, Vector2i(x, 0)), "(%d, 0) is open on -1" % x)
	# At a cardinal point the edge is also the end of the array, so the
	# read past it is 255, not 254. Both stop an actor (D-070).
	assert_true(TileKind.is_sentinel(level.level_tiles.get_top(radius + 1, 0)),
		"and the next tile is past the edge")


func test_minus_two_corridor_runs_further_to_its_own_edge() -> void:
	var level: Level = _level(2)
	var radius: int = level.level_tiles.level_bound.radius
	assert_gt(radius, _level(1).level_tiles.level_bound.radius, "-2 is wider than -1")
	for x in range(LADDER.x, radius + 1):
		assert_true(_is_open(level, Vector2i(x, 0)), "(%d, 0) is open on -2" % x)
	# At a cardinal point the edge is also the end of the array, so the
	# read past it is 255, not 254. Both stop an actor (D-070).
	assert_true(TileKind.is_sentinel(level.level_tiles.get_top(radius + 1, 0)),
		"and the next tile is past the edge")


func test_minus_two_has_copper_and_minus_one_has_none() -> void:
	var copper: Array[int] = [0, 0, 0]
	for depth in [1, 2]:
		var tiles: LevelTiles = _level(depth).level_tiles
		for value in tiles.ore:
			if value == TileKind.ORE.COPPER: copper[depth] += 1
	assert_eq(copper[1], 0, "Rootshelf has no copper")
	assert_gt(copper[2], 0, "Greyseam does")


# --- every level of the slice can be reached on foot ---

# Breadth-first over tiles, with the movement rules: a tile an actor can
# stand on, and an edge it may cross (ramps' closed sides, D-099). The
# feet box is narrower than a tile, so tile-to-tile is enough here.
func _reachable(level: Level, from: Vector2i, to: Vector2i) -> bool:
	var tiles: LevelTiles = level.level_tiles
	var seen: Dictionary[Vector2i, bool] = {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_front()
		if tile == to: return true
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = tile + step
			if seen.has(next): continue
			if not TileKind.is_passable(tiles.get_top(next.x, next.y), tiles.get_ground(next.x, next.y)): continue
			if not TileCollision.edge_open(tiles, tile, next): continue
			seen[next] = true
			queue.append(next)
	return false


func test_from_the_spawn_you_can_walk_to_the_ramp() -> void:
	var levels: Array[Level] = LevelGenerator.generate_levels(World.level_recipes)
	for level in levels: autofree(level)
	var spawn: Fixture = Spawning.world_spawn(levels)
	assert_true(_reachable(levels[0], Vector2i(spawn.tile.x, spawn.tile.y), Vector2i(6, 0)),
		"the Surface ramp (6, 0) is reachable from the spawn %s" % spawn.tile)


func test_from_the_ramp_on_minus_one_you_can_walk_beside_the_hole() -> void:
	var level: Level = _level(1)
	assert_true(_reachable(level, Vector2i(6, 0), LADDER + Vector2i(0, 1)),
		"from the up end of the ramp to (14, -1), beside the hole")


func test_from_the_ladder_on_minus_two_you_can_walk_to_its_edge() -> void:
	var level: Level = _level(2)
	assert_true(_reachable(level, LADDER, Vector2i(81, 0)), "from the ladder to the end of the corridor")
