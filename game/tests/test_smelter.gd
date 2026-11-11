extends GutTest

# The smelter (D-238, D-239, D-242, D-243): loaded by dropping while
# facing it, emptied of what it made with the take key. 3 ore and 1
# coal make 1 ingot; 3 copper ingots, 1 tin ingot and 1 coal make 4
# bronze; it alloys only ingots dropped in, and works its inputs in the
# order they went in. A batch takes 10 s lit, twice that unlit. It's a
# rate machine: it keeps working on a level nobody is on, and across a
# save, exactly as if it had run.

const Worlds = preload("res://tests/worlds.gd")
const SMELTER_TILE: Vector2i = Vector2i(1, 0)

var _world: World
var _actor: Actor
var _smelter: Fixture
var _output: Pack


# -1 and -2, open floor at the origin and east of it on -1; a smelter
# east of a player facing it. -1 is unlit.
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([1, 2]))
	for x in range(0, 3):
		_world.level_at(1).level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	_world.level_at(2).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	_actor = Actor.create(Global.actor_packed_scene, "Smith", WorldPos.new(0, 0, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)
	_actor.facing = Vector2i.RIGHT
	_world.place_requested.emit(null, ObjectKind.OBJECT.SMELTER,
		WorldPos.new(SMELTER_TILE.x, SMELTER_TILE.y, 1))
	_smelter = _world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.SMELTER)[0]
	# What the rule's own tests make goes here, not in the world's smelter
	_output = Pack.new()


func _drop(id: StringName, count: int) -> void:
	_actor.pack.add(id, count)
	_world.drop_requested.emit(_actor, id, count)


# --- the rule, alone ---

func test_three_ore_and_a_coal_make_an_ingot_in_one_batch() -> void:
	var smelter: Smelter = Smelter.new()
	smelter.load_items(&"copper_ore", 3)
	smelter.load_items(&"coal", 1)
	assert_true(smelter.advance_to(9.9, 1.0, 10.0, _output).is_empty(), "not yet")
	assert_eq(smelter.advance_to(10.0, 1.0, 10.0, _output), {&"copper_ingot": 1} as Dictionary[StringName, int])
	assert_eq(smelter.coal, 0, "the coal burned")
	assert_true(smelter.inputs.is_empty(), "the ore used")


func test_no_coal_no_work() -> void:
	var smelter: Smelter = Smelter.new()
	smelter.load_items(&"iron_ore", 6)
	assert_true(smelter.advance_to(100.0, 1.0, 10.0, _output).is_empty(), "nothing")
	assert_false(smelter.is_working(), "and it says so")
	assert_eq(smelter.progress, 0.0, "no progress kept while waiting")


func test_a_long_time_away_works_out_every_batch_in_one_step() -> void:
	var smelter: Smelter = Smelter.new()
	smelter.load_items(&"tin_ore", 9)
	smelter.load_items(&"coal", 5)
	assert_eq(smelter.advance_to(3600.0, 1.0, 10.0, _output), {&"tin_ingot": 3} as Dictionary[StringName, int],
		"three batches, then it runs out of ore")
	assert_eq(smelter.coal, 2, "two coal left")


func test_inputs_are_worked_in_the_order_they_went_in() -> void:
	var smelter: Smelter = Smelter.new()
	smelter.load_items(&"iron_ore", 3)
	smelter.load_items(&"copper_ore", 3)
	smelter.load_items(&"coal", 1)
	assert_eq(smelter.advance_to(10.0, 1.0, 10.0, _output), {&"iron_ingot": 1} as Dictionary[StringName, int],
		"iron first: it went in first")


func test_a_short_lot_waits_and_the_next_whole_one_is_worked() -> void:
	var smelter: Smelter = Smelter.new()
	smelter.load_items(&"copper_ore", 2)
	smelter.load_items(&"tin_ore", 3)
	smelter.load_items(&"coal", 2)
	assert_eq(smelter.advance_to(10.0, 1.0, 10.0, _output), {&"tin_ingot": 1} as Dictionary[StringName, int],
		"two copper isn't a batch")
	assert_eq(smelter.count_of(&"copper_ore"), 2, "still waiting")


func test_three_copper_and_one_tin_ingot_alloy_into_four_bronze() -> void:
	var smelter: Smelter = Smelter.new()
	smelter.load_items(&"copper_ingot", 3)
	smelter.load_items(&"tin_ingot", 1)
	smelter.load_items(&"coal", 1)
	assert_eq(smelter.advance_to(10.0, 1.0, 10.0, _output), {&"bronze_ingot": 4} as Dictionary[StringName, int])


func test_ingots_it_makes_are_never_alloyed() -> void:
	var smelter: Smelter = Smelter.new()
	smelter.load_items(&"copper_ore", 9)
	smelter.load_items(&"tin_ore", 3)
	smelter.load_items(&"coal", 10)
	smelter.advance_to(1000.0, 1.0, 10.0, _output)
	assert_eq(_output.count_of(&"copper_ingot"), 3, "copper kept")
	assert_eq(_output.count_of(&"tin_ingot"), 1, "tin kept")
	assert_eq(_output.count_of(&"bronze_ingot"), 0, "no bronze (D-243)")


func test_unlit_it_works_at_half_speed() -> void:
	var smelter: Smelter = Smelter.new()
	smelter.load_items(&"copper_ore", 3)
	smelter.load_items(&"coal", 1)
	assert_true(smelter.advance_to(19.0, 0.5, 10.0, _output).is_empty(), "19 s unlit")
	assert_eq(smelter.advance_to(20.0, 0.5, 10.0, _output).size(), 1, "20 s")


func test_it_takes_only_what_it_smelts() -> void:
	for id: StringName in [&"copper_ore", &"tin_ore", &"iron_ore", &"copper_ingot", &"tin_ingot", &"coal"]:
		assert_true(Smelter.takes(id), "%s" % id)
	for id: StringName in [&"stone", &"timber", &"bronze_ingot", &"iron_ingot"]:
		assert_false(Smelter.takes(id), "not %s" % id)


func test_it_saves_and_loads_whole() -> void:
	var smelter: Smelter = Smelter.new(5.0)
	smelter.load_items(&"iron_ore", 4)
	smelter.load_items(&"copper_ingot", 3)
	smelter.load_items(&"coal", 2)
	smelter.progress = 3.5
	var back: Smelter = Smelter.from_save(smelter.to_save())
	assert_eq(back.to_save(), smelter.to_save(), "the same")


func test_a_broken_save_loads_what_it_can() -> void:
	var back: Smelter = Smelter.from_save({"inputs": [{"id": "stone", "count": 3},
		{"id": "tin_ore", "count": 2}], "coal": "lots"})
	assert_push_warning("isn't one it takes")
	assert_eq(back.count_of(&"tin_ore"), 2, "the tin")
	assert_eq(back.coal, 0, "no coal")


# --- in the world ---

func test_a_drop_made_facing_it_goes_in() -> void:
	watch_signals(_world)
	_drop(&"copper_ore", 6)
	_drop(&"coal", 2)
	assert_eq(_smelter.machine.count_of(&"copper_ore"), 6, "the ore")
	assert_eq(_smelter.machine.coal, 2, "the coal")
	assert_true(_actor.pack.is_empty(), "out of the pack")
	assert_signal_emit_count(_world, "smelter_loaded", 2)


func test_what_it_doesnt_take_stays_in_the_pack() -> void:
	watch_signals(_world)
	_drop(&"stone", 3)
	assert_eq(_actor.pack.count_of(&"stone"), 3, "kept")
	assert_signal_emitted_with_parameters(_world, "load_refused",
		[_actor, _smelter, World.LOAD_REFUSAL.NOT_SMELTABLE])


func test_it_holds_a_crates_worth() -> void:
	watch_signals(_world)
	_drop(&"iron_ore", 30)
	# 120 kg of 6 kg ore is 20
	assert_eq(_smelter.machine.count_of(&"iron_ore"), 20, "20 fit")
	assert_eq(_actor.pack.count_of(&"iron_ore"), 10, "the rest kept")
	assert_signal_emitted_with_parameters(_world, "load_refused",
		[_actor, _smelter, World.LOAD_REFUSAL.FULL])


func test_the_take_key_takes_what_it_made_and_leaves_the_rest() -> void:
	_drop(&"copper_ore", 4)
	_drop(&"coal", 1)
	# -1 is unlit: 20 s a batch
	_world.advance_time(20.0)
	_world.take_requested.emit(_actor)
	assert_eq(_actor.pack.count_of(&"copper_ingot"), 1, "the ingot")
	assert_eq(_actor.pack.count_of(&"copper_ore"), 0, "not the ore left in it")
	assert_eq(_smelter.machine.count_of(&"copper_ore"), 1, "one waits")


func test_a_brazier_in_reach_makes_it_full_speed() -> void:
	_world.level_at(1).level_fixtures.add(Fixture.new(ObjectKind.OBJECT.BRAZIER,
		WorldPos.new(2, 0, 1), _world.fixture_ids.allocate()))
	_drop(&"copper_ore", 3)
	_drop(&"coal", 1)
	_world.advance_time(10.0)
	_world.take_requested.emit(_actor)
	assert_eq(_actor.pack.count_of(&"copper_ingot"), 1, "made in 10 s, lit")


func test_it_keeps_smelting_while_nobody_is_on_its_level() -> void:
	_drop(&"iron_ore", 9)
	_drop(&"coal", 3)
	_actor.move_to(WorldPos.new(0, 0, 2))
	for i in range(60): _world.advance_time(1.0)
	assert_eq(_smelter.contents.count_of(&"iron_ingot"), 0, "not worked out while away")
	_actor.move_to(WorldPos.new(0, 0, 1))
	assert_eq(_smelter.contents.count_of(&"iron_ingot"), 3, "arriving, it caught up: 60 s unlit")


func test_its_progress_shows_while_working() -> void:
	_drop(&"copper_ore", 3)
	_drop(&"coal", 1)
	_world.advance_time(5.0)
	assert_almost_eq(_world.smelt_progress(_smelter), 0.25, 0.01, "5 s of an unlit 20")


func test_a_buried_smelter_does_no_work_and_loses_none() -> void:
	_drop(&"copper_ore", 3)
	_drop(&"coal", 1)
	_world.level_at(1).level_tiles.set_top(SMELTER_TILE.x, SMELTER_TILE.y, TileKind.TOP.RUBBLE)
	_world.advance_time(100.0)
	_world.work_smelter(_smelter)
	assert_eq(_smelter.contents.count_of(&"copper_ingot"), 0, "nothing made")
	assert_eq(_smelter.machine.count_of(&"copper_ore"), 3, "nothing lost")


func test_across_a_save_it_works_out_the_time_as_if_it_had_run() -> void:
	_drop(&"copper_ore", 6)
	_drop(&"coal", 2)
	_world.advance_time(15.0)
	var levels: Dictionary = SaveGame._serialize_levels(_world.levels())
	var time: float = _world.world_time
	var world: World = add_child_autofree(Worlds.with_levels([]))
	SaveGame._deserialize_levels(levels, world)
	world.world_time = time
	var back: Fixture = world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.SMELTER)[0]
	assert_almost_eq(back.machine.progress, _smelter.machine.progress, 0.001, "mid-batch")
	world.advance_time(25.0)
	world.work_smelter(back)
	assert_eq(back.contents.count_of(&"copper_ingot"), 2, "40 s unlit: both batches")


func test_the_world_time_is_saved() -> void:
	_world.advance_time(42.0)
	var data: Dictionary = SaveGame._serialize_all(_world, SaveSession.new(_actor.actor_id))
	assert_almost_eq(float(data.get("world_time", -1.0)), 42.0, 0.001, "written")
	var world: World = autofree(Worlds.with_levels([1]))
	SaveGame._restore_counters(world, data)
	assert_almost_eq(world.world_time, 42.0, 0.001, "and read back")
