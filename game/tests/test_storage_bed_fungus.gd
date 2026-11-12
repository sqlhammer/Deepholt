extends GutTest

# Storage (D-249), beds (D-248) and cave fungus (D-245). A storage
# crate holds 200 kg, filled by dropping while facing it and emptied by
# the take key. A bed is its player's: claimed by building or using it,
# one each, and where they come back to. Fungus grows in clumps in
# -1's caves; taking one harvests it whole.

const Worlds = preload("res://tests/worlds.gd")

var _world: World
var _actor: Actor


func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([1, 2]))
	for x in range(-4, 5):
		for y in [0, 1]:
			_world.level_at(1).level_tiles.set_top(x, y, TileKind.TOP.OPEN)
	_actor = _player("P", Vector2i.ZERO)
	_actor.facing = Vector2i.RIGHT


func _player(name: String, tile: Vector2i) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, name, WorldPos.new(tile.x, tile.y, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(actor)
	return actor


func _place(entry: int, tile: Vector2i, by: Actor = null) -> Fixture:
	# A builder pays (D-159): the cost goes in first, so only the rule
	# under test refuses
	if by != null:
		var cost: Dictionary[StringName, int] = Building.cost_of(_world.tuning, entry)
		for id: StringName in cost: by.pack.add(id, cost[id])
	_world.place_requested.emit(by, entry, WorldPos.new(tile.x, tile.y, 1))
	for fixture: Fixture in _world.level_at(1).level_fixtures.at(tile):
		if fixture.kind == Building.kind_of(entry): return fixture
	return null


# --- storage (D-249) ---

func test_a_storage_crate_costs_6_timber_and_starts_empty() -> void:
	assert_eq(Building.cost_of(_world.tuning, ObjectKind.OBJECT.STORAGE_CRATE),
		{&"timber": 6} as Dictionary[StringName, int], "6 timber")
	var crate: Fixture = _place(ObjectKind.OBJECT.STORAGE_CRATE, Vector2i(1, 0), _actor)
	assert_not_null(crate, "built")
	assert_true(_actor.pack.is_empty(), "paid")
	assert_true(crate.contents.is_empty(), "empty")


func test_it_fills_by_dropping_and_empties_with_the_take_key() -> void:
	var crate: Fixture = _place(ObjectKind.OBJECT.STORAGE_CRATE, Vector2i(1, 0))
	_actor.pack.add(&"stone", 10)
	_world.drop_requested.emit(_actor, &"stone", 10)
	assert_eq(crate.contents.count_of(&"stone"), 10, "in")
	assert_eq(_actor.pack.count_of(&"stone"), 0, "out of the pack")
	_world.take_requested.emit(_actor)
	assert_eq(_actor.pack.count_of(&"stone"), 10, "back")
	assert_true(crate.contents.is_empty(), "empty again")


func test_it_holds_200_kg() -> void:
	var crate: Fixture = _place(ObjectKind.OBJECT.STORAGE_CRATE, Vector2i(1, 0))
	watch_signals(_world)
	_actor.pack.add(&"stone", 70)
	_world.drop_requested.emit(_actor, &"stone", 70)
	# 200 kg of 3 kg stone is 66
	assert_eq(crate.contents.count_of(&"stone"), 66, "66 fit")
	assert_eq(_actor.pack.count_of(&"stone"), 4, "the rest kept")
	assert_signal_emitted_with_parameters(_world, "load_refused",
		[_actor, crate, World.LOAD_REFUSAL.FULL])


func test_storage_and_its_contents_are_saved() -> void:
	var crate: Fixture = _place(ObjectKind.OBJECT.STORAGE_CRATE, Vector2i(1, 0))
	crate.contents.add(&"copper_ore", 7)
	var world: World = add_child_autofree(Worlds.with_levels([]))
	SaveGame._deserialize_levels(SaveGame._serialize_levels(_world.levels()), world)
	var back: Fixture = world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.STORAGE_CRATE)[0]
	assert_eq(back.contents.count_of(&"copper_ore"), 7, "what it held")


func test_a_buried_crate_keeps_its_contents_and_cant_be_reached() -> void:
	var crate: Fixture = _place(ObjectKind.OBJECT.STORAGE_CRATE, Vector2i(1, 0))
	crate.contents.add(&"stone", 3)
	_world.level_at(1).level_tiles.set_top(1, 0, TileKind.TOP.RUBBLE)
	assert_null(_world.container_faced(_actor), "buried")
	assert_eq(crate.contents.count_of(&"stone"), 3, "never destroyed")


# --- beds (D-248) ---

func test_building_a_bed_claims_it() -> void:
	var bed: Fixture = _place(ObjectKind.OBJECT.BED, Vector2i(1, 0), _actor)
	assert_eq(bed.owner_id, _actor.actor_id, "the builder's")
	assert_eq(_world.bed_of(_actor.actor_id), bed)
	assert_true(_actor.pack.is_empty(), "6 timber paid")


func test_using_a_bed_claims_it_and_frees_the_old_one() -> void:
	var old: Fixture = _place(ObjectKind.OBJECT.BED, Vector2i(-2, 1), _actor)
	var bed: Fixture = _place(ObjectKind.OBJECT.BED, Vector2i(1, 0))
	assert_eq(bed.owner_id, -1, "built with no actor: nobody's")
	watch_signals(_world)
	assert_true(_actor.interact(), "claimed")
	assert_eq(bed.owner_id, _actor.actor_id, "theirs")
	assert_eq(old.owner_id, -1, "the old one freed")
	assert_signal_emitted(_world, "bed_claimed")


func test_a_bed_has_one_owner() -> void:
	var other: Actor = _player("Other", Vector2i(2, 1))
	var bed: Fixture = _place(ObjectKind.OBJECT.BED, Vector2i(1, 0), _actor)
	assert_eq(bed.owner_id, _actor.actor_id)
	other.facing = Vector2i.LEFT
	other.move_to(WorldPos.new(2, 0, 1))
	other.interact()
	assert_eq(bed.owner_id, other.actor_id, "taken")
	assert_null(_world.bed_of(_actor.actor_id), "and the first has none")


func test_home_is_beside_the_bed_and_a_buried_bed_is_none() -> void:
	_place(ObjectKind.OBJECT.BED, Vector2i(3, 0), _actor)
	var home: WorldPos = _world.home_of(_actor.actor_id)
	assert_true(home != null and home.equals(WorldPos.new(3, 0, 1)), "the bed's tile")
	var tile: WorldPos = Spawning.spawn_tile_for(home, _world.levels(), _world.actors())
	assert_not_null(tile, "somewhere to stand")
	if tile != null:
		assert_false(tile.equals(home), "not in the bed itself")
		assert_lte(maxi(absi(tile.x - 3), absi(tile.y)), 1, "beside it")
	_world.level_at(1).level_tiles.set_top(3, 0, TileKind.TOP.RUBBLE)
	assert_null(_world.home_of(_actor.actor_id), "buried: the world's spawn instead")


func test_a_beds_owner_is_saved() -> void:
	_place(ObjectKind.OBJECT.BED, Vector2i(1, 0), _actor)
	var world: World = add_child_autofree(Worlds.with_levels([]))
	SaveGame._deserialize_levels(SaveGame._serialize_levels(_world.levels()), world)
	var back: Fixture = world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.BED)[0]
	assert_eq(back.owner_id, _actor.actor_id, "whose")


# --- cave fungus (D-245) ---

func test_taking_a_clump_harvests_it_whole() -> void:
	var clump: Fixture = Fixture.new(ObjectKind.OBJECT.FUNGUS, WorldPos.new(1, 0, 1),
		_world.fixture_ids.allocate())
	_world.level_at(1).level_fixtures.add(clump)
	watch_signals(_world)
	_world.take_requested.emit(_actor)
	assert_between(_actor.pack.count_of(&"cave_fungus"), 2, 3, "two or three")
	assert_true(_world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.FUNGUS).is_empty(),
		"the clump is gone")
	assert_signal_emitted(_world, "took")


func test_fungus_grows_in_minus_ones_caves_and_nowhere_else() -> void:
	var world: World = autofree(Worlds.generated(2))
	world.generate_below(1)
	var on_minus_one: Array[Fixture] = world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.FUNGUS)
	assert_gt(on_minus_one.size(), 3, "clumps on -1")
	for clump: Fixture in on_minus_one:
		var tiles: LevelTiles = world.level_at(1).level_tiles
		assert_eq(tiles.get_top(clump.tile.x, clump.tile.y), TileKind.TOP.OPEN, "on open floor")
	for depth: int in [0, 2]:
		assert_true(world.level_at(depth).level_fixtures.of_kind(ObjectKind.OBJECT.FUNGUS).is_empty(),
			"none at depth %d" % depth)


func test_three_fungus_press_into_one_oil_at_a_bench() -> void:
	_place(ObjectKind.OBJECT.WORKBENCH, Vector2i(1, 1))
	_actor.pack.add(&"cave_fungus", 3)
	_world.craft_requested.emit(_actor, &"lamp_oil")
	assert_eq(_actor.pack.count_of(&"lamp_oil"), 1, "one oil")
	assert_eq(_actor.pack.count_of(&"cave_fungus"), 0, "the fungus used")
