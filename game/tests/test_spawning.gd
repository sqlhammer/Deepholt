extends GutTest

# Spawning -- where an actor appears (D-091, D-105): its own spawn
# point, else the world's default; then the nearest free tile, ring by
# ring, in a fixed order. Actors on other depths aren't in the way.


func _open_level(depth: int, open: Array[Vector2i]) -> Level:
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(depth)
	add_child_autofree(level)
	for tile in open:
		level.level_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)
	return level


func _square(radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			tiles.append(Vector2i(x, y))
	return tiles


func _actor_at(tile: Vector2i, depth: int) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", WorldPos.new(tile.x, tile.y, depth), World.get_level_by_depth(depth))
	add_child_autofree(actor)
	return actor


func _add_world_spawn(level: Level, tile: Vector2i) -> void:
	level.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.WORLD_SPAWN,
		WorldPos.new(tile.x, tile.y, level.depth), 900 + level.level_fixtures.all().size()))


func test_the_world_spawn_is_found_on_whichever_level_has_it() -> void:
	var levels: Array[Level] = [_open_level(0, []), _open_level(1, [Vector2i(2, 2)])]
	_add_world_spawn(levels[1], Vector2i(2, 2))
	var spawn: Fixture = Spawning.world_spawn(levels)
	assert_not_null(spawn, "found")
	if spawn: assert_eq(spawn.tile.depth, 1, "on -1")


func test_no_world_spawn_or_two_is_an_error() -> void:
	var levels: Array[Level] = [_open_level(0, [Vector2i(1, 1), Vector2i(2, 2)])]
	assert_null(Spawning.world_spawn(levels), "none")
	assert_push_error("Expected one world spawn, found 0.")
	_add_world_spawn(levels[0], Vector2i(1, 1))
	_add_world_spawn(levels[0], Vector2i(2, 2))
	assert_null(Spawning.world_spawn(levels), "two")
	assert_push_error("Expected one world spawn, found 2.")


func test_alone_you_spawn_on_the_spawn_tile() -> void:
	var level: Level = _open_level(0, _square(2))
	_add_world_spawn(level, Vector2i.ZERO)
	var tile: WorldPos = Spawning.spawn_tile_for(null, [level] as Array[Level], [] as Array[Actor])
	assert_true(tile.equals(WorldPos.new(0, 0, 0)), "on the spawn")


func test_your_own_spawn_point_wins() -> void:
	var level: Level = _open_level(0, _square(2))
	_add_world_spawn(level, Vector2i.ZERO)
	var tile: WorldPos = Spawning.spawn_tile_for(WorldPos.new(2, 2, 0), [level] as Array[Level], [] as Array[Actor])
	assert_true(tile.equals(WorldPos.new(2, 2, 0)), "your own, not the world's")


func test_an_occupied_spawn_sends_you_to_the_first_free_tile_in_the_ring() -> void:
	var level: Level = _open_level(0, _square(2))
	var first: Actor = _actor_at(Vector2i.ZERO, 0)
	var tile: WorldPos = Spawning.free_tile_near(WorldPos.new(0, 0, 0), level.level_tiles, [first] as Array[Actor])
	assert_true(tile.equals(WorldPos.new(-1, -1, 0)), "ring 1, top row, leftmost: (-1, -1)")


func test_a_spawn_skips_rock_holes_and_ramps() -> void:
	var level: Level = _open_level(0, [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)])
	level.level_tiles.set_ground(0, -1, TileKind.GROUND.HOLE)
	level.level_tiles.set_ground(-1, 0, TileKind.GROUND.RAMP_DOWN_W)
	var tile: WorldPos = Spawning.free_tile_near(WorldPos.new(0, 0, 0), level.level_tiles, [] as Array[Actor])
	assert_true(tile.equals(WorldPos.new(1, 0, 0)), "the only open, non-hole, non-ramp tile")


func test_an_actor_on_another_depth_is_not_in_the_way() -> void:
	var level: Level = _open_level(0, _square(1))
	_open_level(1, _square(1))
	var elsewhere: Actor = _actor_at(Vector2i.ZERO, 1)
	var tile: WorldPos = Spawning.free_tile_near(WorldPos.new(0, 0, 0), level.level_tiles, [elsewhere] as Array[Actor])
	assert_true(tile.equals(WorldPos.new(0, 0, 0)), "the actor on -1 doesn't block the Surface tile")


func test_nowhere_free_is_an_error() -> void:
	var level: Level = _open_level(0, [])
	assert_null(Spawning.free_tile_near(WorldPos.new(0, 0, 0), level.level_tiles, [] as Array[Actor]), "all rock")
	assert_push_error("No free tile within")


func test_a_spawn_point_on_a_depth_with_no_level_is_an_error() -> void:
	var level: Level = _open_level(0, _square(1))
	assert_null(Spawning.spawn_tile_for(WorldPos.new(0, 0, 5), [level] as Array[Level], [] as Array[Actor]),
		"nowhere to put it")
	assert_push_error("No level at depth 5 to spawn on.")
