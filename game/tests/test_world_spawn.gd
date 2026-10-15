extends GutTest

# The world's default spawn (D-091, D-092, D-105): a WORLD_SPAWN fixture
# the generator places at random within the start placement's radius,
# on floor an actor could stand on, never on a ramp. Same seed, same
# tile.


func _surface_spawns() -> Array[Fixture]:
	var level: Level = LevelGenerator.generate_level(World.level_recipes.get_recipe(0))
	autofree(level)
	return level.level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN)


# A level that is open floor only on `open`, with nothing placed.
func _open_level(open: Array[Vector2i]) -> Level:
	var level: Level = Global.level_packed_scene.instantiate()
	autofree(level)
	level.setup(1)
	for tile in open:
		level.level_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)
	return level


# The same, with a start placement of `radius` at the origin, and its
# spawn placed.
func _spawn_on(open: Array[Vector2i], radius: int, seed_level_seed: int = 1234) -> Level:
	var level: Level = _open_level(open)
	var recipe: LevelRecipe = LevelRecipe.new(World.level_recipes.get_bounds(1))
	recipe.fixed_placements = [PrefabPlacement.new(&"", Vector2i.ZERO, radius)] as Array[PrefabPlacement]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_level_seed
	LevelGenerator.place_world_spawns(level, recipe, rng)
	return level


func test_the_surface_has_exactly_one_world_spawn() -> void:
	assert_eq(_surface_spawns().size(), 1, "one world spawn on the Surface")


func test_the_same_seed_gives_the_same_spawn() -> void:
	var a: Fixture = _surface_spawns()[0]
	var b: Fixture = _surface_spawns()[0]
	assert_true(a.tile.equals(b.tile), "same tile both times: %s, %s" % [a.tile, b.tile])


func test_the_surface_spawn_is_in_the_start_room_on_open_floor() -> void:
	var level: Level = LevelGenerator.generate_level(World.level_recipes.get_recipe(0))
	autofree(level)
	var spawn: Fixture = level.level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN)[0]
	var tiles: LevelTiles = level.level_tiles
	assert_true(TileKind.is_passable(tiles.get_top(spawn.tile.x, spawn.tile.y),
		tiles.get_ground(spawn.tile.x, spawn.tile.y)), "an actor could stand there")
	assert_false(TileKind.is_ramp(tiles.get_ground(spawn.tile.x, spawn.tile.y)), "not the ramp")
	assert_lte(spawn.tile.x * spawn.tile.x + spawn.tile.y * spawn.tile.y, 64, "within 8 of the anchor")


func test_only_passable_non_ramp_tiles_are_candidates() -> void:
	var open: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var level: Level = _open_level(open)
	level.level_tiles.set_ground(1, 0, TileKind.GROUND.HOLE)
	level.level_tiles.set_ground(2, 0, TileKind.GROUND.RAMP_DOWN_E)
	var candidates: Array[Vector2i] = LevelGenerator.spawn_candidates(level, Vector2i.ZERO, 8)
	assert_eq(candidates, [Vector2i(3, 0)] as Array[Vector2i], "not the hole, not the ramp, not rock")


func test_the_radius_is_a_disc() -> void:
	# (2, 2) is 2.83 from the origin: inside a square of 2, outside a disc.
	var level: Level = _open_level([Vector2i(2, 2), Vector2i(2, 0)] as Array[Vector2i])
	var candidates: Array[Vector2i] = LevelGenerator.spawn_candidates(level, Vector2i.ZERO, 2)
	assert_eq(candidates, [Vector2i(2, 0)] as Array[Vector2i], "(2, 2) is outside the disc")


func test_candidates_come_row_by_row() -> void:
	var open: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(0, 0)]
	var level: Level = _open_level(open)
	var candidates: Array[Vector2i] = LevelGenerator.spawn_candidates(level, Vector2i.ZERO, 3)
	assert_eq(candidates, [Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 1)] as Array[Vector2i],
		"top row first, left to right")


func test_a_ladder_tile_is_not_a_candidate() -> void:
	var level: Level = _open_level([Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])
	level.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(1, 0, 1), 900))
	var candidates: Array[Vector2i] = LevelGenerator.spawn_candidates(level, Vector2i.ZERO, 4)
	assert_eq(candidates, [Vector2i(2, 0)] as Array[Vector2i], "ladder and spawn conflict (D-103)")


func test_no_candidate_is_reported_and_places_nothing() -> void:
	var level: Level = _spawn_on([] as Array[Vector2i], 3)
	assert_push_error("No tile for the world spawn")
	assert_eq(level.level_fixtures.all().size(), 0, "no spawn placed")


func test_a_placement_without_a_radius_places_no_spawn() -> void:
	var level: Level = _spawn_on([Vector2i(1, 0)] as Array[Vector2i], 0)
	assert_eq(level.level_fixtures.all().size(), 0, "radius 0 is not a start placement")


func test_the_other_levels_have_no_world_spawn() -> void:
	for depth in [1, 2]:
		var level: Level = LevelGenerator.generate_level(World.level_recipes.get_recipe(depth))
		autofree(level)
		assert_eq(level.level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN).size(), 0, "depth %d" % depth)
