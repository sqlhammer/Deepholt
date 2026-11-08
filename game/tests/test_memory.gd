extends GutTest

# Memory (D-145, D-147): a saved-only byte layer of bit flags per
# tile, bit 0 REMEMBERED. The world marks what each of its players
# senses; NPCs don't map the mountain. A save without the layer loads
# whole, with nothing remembered.

const Worlds = preload("res://tests/worlds.gd")
const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/memory"
const SLOT: String = SAVES_ROOT + "/slot-001"


func after_each() -> void:
	SaveDirs.remove_tree(SAVES_ROOT)


func _tiles() -> LevelTiles:
	return autofree(Worlds.with_levels([1])).level_at(1).level_tiles


# --- the layer ---

func test_nothing_is_remembered_at_first() -> void:
	var tiles: LevelTiles = _tiles()
	assert_false(tiles.is_remembered(0, 0), "a new level")
	assert_eq(tiles.memory.size(), tiles.top.size(), "one byte a tile, like the others")


func test_remembering_sets_bit_zero_and_announces_the_batch_once() -> void:
	var tiles: LevelTiles = _tiles()
	watch_signals(tiles)
	var count: int = tiles.remember([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	assert_eq(count, 2, "two newly remembered")
	assert_true(tiles.is_remembered(1, 0), "remembered")
	assert_eq(tiles.get_memory(1, 0), LevelTiles.REMEMBERED, "bit 0")
	assert_signal_emit_count(tiles, "memory_changed", 1, "one announcement for the batch")
	assert_signal_not_emitted(tiles, "tile_changed", "memory isn't terrain")


func test_remembering_again_changes_nothing_and_stays_quiet() -> void:
	var tiles: LevelTiles = _tiles()
	tiles.remember([Vector2i(0, 0)] as Array[Vector2i])
	watch_signals(tiles)
	assert_eq(tiles.remember([Vector2i(0, 0)] as Array[Vector2i]), 0, "already remembered")
	assert_signal_not_emitted(tiles, "memory_changed")


func test_tiles_outside_the_level_are_skipped() -> void:
	var tiles: LevelTiles = _tiles()
	var radius: int = tiles.level_bound.radius
	assert_eq(tiles.remember([Vector2i(radius + 3, 0), Vector2i(radius, radius)] as Array[Vector2i]),
		0, "past the array, and outside the disc")


# D-147: the other seven bits are reserved, and remembering keeps
# them.
func test_remembering_keeps_the_other_bits() -> void:
	var tiles: LevelTiles = _tiles()
	tiles.bulk_load_tile_arrays({"memory": _filled(tiles, 4)})
	tiles.remember([Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(tiles.get_memory(0, 0), 4 | LevelTiles.REMEMBERED, "bit 2 kept")


func _filled(tiles: LevelTiles, value: int) -> PackedByteArray:
	var bytes: PackedByteArray = []
	bytes.resize(tiles.memory.size())
	bytes.fill(value)
	return bytes


func test_a_short_memory_layer_is_refused() -> void:
	var tiles: LevelTiles = _tiles()
	assert_eq(tiles.bulk_load_tile_arrays({"memory": PackedByteArray([1, 1])}),
		LevelTiles.REFUSAL_REASON.LAYER_SIZE_MISMATCH, "the wrong size")


# --- the world marks it ---

func _world_with_room() -> World:
	var world: World = autofree(Worlds.with_levels([0, 1, 2]))
	for x in range(-12, 13):
		world.level_at(1).level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	return world


func _actor(world: World, x: int, kind: int = ActorKind.ACTOR.PLAYER) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", WorldPos.new(x, 0, 1),
		world.level_at(1), kind)
	world.add_actor(actor)
	return actor


func test_a_player_remembers_what_it_senses_where_it_starts() -> void:
	var world: World = _world_with_room()
	_actor(world, 0)
	var tiles: LevelTiles = world.level_at(1).level_tiles
	var radius: int = world.tuning.sense_radius
	assert_true(tiles.is_remembered(radius, 0), "the corridor to the radius")
	assert_true(tiles.is_remembered(0, -1), "the wall")
	assert_false(tiles.is_remembered(radius + 1, 0), "not past the radius")
	assert_false(tiles.is_remembered(0, -2), "nor the rock behind the wall")


func test_a_players_steps_extend_its_memory() -> void:
	var world: World = _world_with_room()
	var actor: Actor = _actor(world, 0)
	var radius: int = world.tuning.sense_radius
	actor.move_to(WorldPos.new(4, 0, 1))
	assert_true(world.level_at(1).level_tiles.is_remembered(4 + radius, 0), "further east")
	assert_true(world.level_at(1).level_tiles.is_remembered(-radius, 0), "and the west stays")


# D-145: memory is every player's, never an NPC's.
func test_an_npc_remembers_nothing() -> void:
	var world: World = _world_with_room()
	_actor(world, 0, ActorKind.ACTOR.NULL)
	assert_false(world.level_at(1).level_tiles.is_remembered(0, 0), "not mapped")


func test_each_world_remembers_its_own() -> void:
	var first: World = _world_with_room()
	var second: World = _world_with_room()
	_actor(first, 0)
	assert_true(first.level_at(1).level_tiles.is_remembered(0, 0), "the first remembers")
	assert_false(second.level_at(1).level_tiles.is_remembered(0, 0), "the second doesn't")


# --- saving it ---

func _saved(world: World, player: Actor) -> void:
	DirAccess.make_dir_recursive_absolute(SLOT)
	assert_eq(SaveGame.save_game(SLOT, world, SaveSession.new(player.actor_id), SAVES_ROOT),
		SaveGame.REFUSAL_REASON.NONE, "saved")


func _generated_with_player() -> Array:
	var world: World = autofree(LevelGenerator.generate_world(3))
	var spawn: WorldPos = Spawning.world_spawn(world.levels()).tile
	var player: Actor = Actor.create(Global.actor_packed_scene, "P", spawn,
		world.level_at(spawn.depth), ActorKind.ACTOR.PLAYER)
	world.add_actor(player)
	return [world, player]


# Trap 9: a tile no generator or sense would ever mark comes back.
func test_memory_round_trips_through_a_save() -> void:
	var made: Array = _generated_with_player()
	var world: World = made[0]
	var far: Vector2i = Vector2i(-30, 20)
	world.level_at(1).level_tiles.remember([far] as Array[Vector2i])
	_saved(world, made[1])
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(SLOT)
	if loaded == null:
		fail_test("refused")
		return
	assert_true(loaded.world.level_at(1).level_tiles.is_remembered(far.x, far.y), "came back")
	loaded.free_world()


# D-147: a save from before memory existed loads whole (nothing is
# regenerated, so no ids drift) with nothing remembered.
func test_a_save_without_memory_loads_whole_with_nothing_remembered() -> void:
	var made: Array = _generated_with_player()
	_saved(made[0], made[1])
	var file: FileAccess = FileAccess.open(SLOT.path_join(SaveGame.SAVE_BASE_NAME), FileAccess.READ)
	var version: Dictionary = file.get_var(false)
	var data: Dictionary = file.get_var(false)
	file.close()
	for depth: int in data.levels:
		data.levels[depth]["tiles"].erase("memory")
		var layers: Dictionary = SaveGame._deserialize_tile_layers(data.levels[depth])
		assert_true(SaveGame._holds_whole_level(data.levels[depth], layers),
			"depth %d is still whole" % depth)
	SaveGame._overwrite_data(version.format_version, data, SLOT.path_join(SaveGame.SAVE_BASE_NAME))
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(SLOT)
	if loaded == null:
		fail_test("refused")
		return
	# The loaded player senses where it stands as it's added, so look
	# out of its reach
	assert_false(loaded.world.level_at(1).level_tiles.is_remembered(0, 0),
		"nothing remembered on -1")
	loaded.free_world()
