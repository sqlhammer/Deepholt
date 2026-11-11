extends GutTest

# The hand winch and its crate (D-224, D-225): over a hole, for 12
# timber and 20 stone, it makes its crate at the foot of the hole. The
# crate holds 120 kg, filled by dropping while facing it and emptied by
# the take key. Held interact at the top lifts it in 15 s and lowers it
# in 5 s; two cranking add their rates. It is on one level or the
# other, never between, and is never in a pack.

const Worlds = preload("res://tests/worlds.gd")
const HOLE: Vector2i = Vector2i(2, 0)
const BESIDE: Vector2i = Vector2i(1, 0)
const FOOT_SIDE: Vector2i = Vector2i(1, 0)

var _world: World
var _top: Actor
var _bottom: Actor


# Levels 0 to 3 of solid rock. On -1, floor at BESIDE and below the
# hole, and the hole at HOLE; on -2, the hole's foot is open with floor
# beside it. One player at the top facing the hole, one at the bottom
# facing the foot.
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2, 3]))
	for tile: Vector2i in [BESIDE, HOLE, HOLE + Vector2i.DOWN]:
		_open(1, tile)
	_world.level_at(1).level_tiles.set_ground(HOLE.x, HOLE.y, TileKind.GROUND.HOLE)
	for tile: Vector2i in [HOLE, FOOT_SIDE]:
		_open(2, tile)
	_top = _player("Top", 1, BESIDE, Vector2i.RIGHT)
	_bottom = _player("Bottom", 2, FOOT_SIDE, Vector2i.RIGHT)
	watch_signals(_world)


func _open(depth: int, tile: Vector2i) -> void:
	_world.level_at(depth).level_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)


func _player(name: String, depth: int, tile: Vector2i, facing: Vector2i) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, name, WorldPos.new(tile.x, tile.y, depth),
		_world.level_at(depth), ActorKind.ACTOR.PLAYER)
	_world.add_actor(actor)
	actor.facing = facing
	return actor


# A winch over the hole and its crate at the foot, as building one
# makes.
func _build_winch() -> Fixture:
	_world.place_requested.emit(null, ObjectKind.OBJECT.WINCH, WorldPos.new(HOLE.x, HOLE.y, 1))
	return _world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.WINCH)[0]


func _crate() -> Fixture:
	for depth: int in [1, 2]:
		var found: Array[Fixture] = _world.level_at(depth).level_fixtures.of_kind(ObjectKind.OBJECT.CRATE)
		if not found.is_empty(): return found[0]
	return null


func _refusal() -> int:
	var args: Array = get_signal_parameters(_world, "request_refused")
	return args[3] if args != null else -1


func _crank(actor: Actor, seconds: float, step: float = 0.1) -> void:
	var ticks: int = roundi(seconds / step)
	for i in ticks:
		_world.crank(actor, step)


# --- building it ---

func test_a_winch_costs_twelve_timber_and_twenty_stone_and_makes_its_crate() -> void:
	_top.pack.add(&"timber", 12)
	_top.pack.add(&"stone", 25)
	_world.place_requested.emit(_top, ObjectKind.OBJECT.WINCH, WorldPos.new(HOLE.x, HOLE.y, 1))
	assert_eq(_world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.WINCH).size(), 1, "placed")
	assert_eq(_top.pack.count_of(&"timber"), 0, "12 timber paid")
	assert_eq(_top.pack.count_of(&"stone"), 5, "20 stone paid")
	var crate: Fixture = _crate()
	assert_not_null(crate, "with its crate")
	assert_true(crate.tile.equals(WorldPos.new(HOLE.x, HOLE.y, 2)), "at the foot of the hole")
	assert_true(crate.contents != null and crate.contents.is_empty(), "empty")


func test_a_winch_with_no_floor_below_for_its_crate_is_refused() -> void:
	_world.level_at(2).level_tiles.set_top(HOLE.x, HOLE.y, TileKind.TOP.MINABLE_ROCK)
	_world.place_requested.emit(null, ObjectKind.OBJECT.WINCH, WorldPos.new(HOLE.x, HOLE.y, 1))
	assert_eq(_refusal(), World.FIXTURE_REFUSAL.LANDING_BLOCKED, "nowhere for the crate")


func test_a_winch_with_someone_standing_below_is_refused() -> void:
	_bottom.move_to(WorldPos.new(HOLE.x, HOLE.y, 2), &"test")
	_world.place_requested.emit(null, ObjectKind.OBJECT.WINCH, WorldPos.new(HOLE.x, HOLE.y, 1))
	assert_eq(_refusal(), World.FIXTURE_REFUSAL.LANDING_BLOCKED, "the crate would land on them")


func test_a_hole_with_a_winch_takes_no_ladder_or_chute() -> void:
	_build_winch()
	_world.place_requested.emit(null, ObjectKind.OBJECT.CHUTE, WorldPos.new(HOLE.x, HOLE.y, 1))
	assert_eq(_refusal(), World.FIXTURE_REFUSAL.TILE_OCCUPIED, "no chute beside it")
	_world.place_requested.emit(null, ObjectKind.OBJECT.LADDER, WorldPos.new(HOLE.x, HOLE.y, 2))
	assert_ne(get_signal_emit_count(_world, "fixture_placed"), 3, "no ladder under it either")


func test_a_built_winch_and_its_crate_load_clean() -> void:
	_build_winch()
	assert_eq(FixturePlacement.problems(_world.levels()), [] as Array[String], "at the foot")
	_crank(_top, 15.0)
	assert_eq(FixturePlacement.problems(_world.levels()), [] as Array[String], "and in the hole")


# --- filling and emptying ---

func test_a_drop_facing_the_crate_goes_into_it() -> void:
	_build_winch()
	_bottom.pack.add(&"stone", 10)
	_world.drop_requested.emit(_bottom, &"stone", 10)
	assert_eq(_crate().contents.count_of(&"stone"), 10, "in the crate")
	assert_eq(_bottom.pack.count_of(&"stone"), 0, "out of the pack")
	assert_true(_world.level_at(2).level_drops.is_empty(), "nothing on the ground")


func test_the_crate_holds_120_kg_and_says_when_its_full() -> void:
	_build_winch()
	_bottom.pack.add(&"stone", 50)
	_world.drop_requested.emit(_bottom, &"stone", 50)
	assert_eq(_crate().contents.count_of(&"stone"), 40, "40 stone is 120 kg")
	assert_eq(_bottom.pack.count_of(&"stone"), 10, "the rest stays in the pack")
	var heard: Array = get_signal_parameters(_world, "crank_refused")
	assert_eq(heard[1], World.CRANK_REFUSAL.CRATE_FULL, "and the notice says it's full")


func test_the_take_key_empties_the_crate() -> void:
	_build_winch()
	_crate().contents.add(&"stone", 6)
	_world.take_requested.emit(_bottom)
	assert_eq(_bottom.pack.count_of(&"stone"), 6, "into the pack")
	assert_true(_crate().contents.is_empty(), "the crate is empty")
	assert_eq(get_signal_parameters(_world, "took")[1], {&"stone": 6}, "and the notice says what")


# --- cranking ---

func test_cranking_at_the_top_lifts_the_crate_in_fifteen_seconds() -> void:
	var winch: Fixture = _build_winch()
	_crate().contents.add(&"stone", 4)
	_crank(_top, 14.0)
	assert_eq(_crate().tile.depth, 2, "still at the foot at 14 s")
	assert_almost_eq(_world.crank_progress(winch), 14.0 / 15.0, 0.01, "most of the way")
	_crank(_top, 1.0)
	assert_eq(_crate().tile.depth, 1, "in the hole at 15 s")
	assert_eq(_crate().contents.count_of(&"stone"), 4, "with what it held")
	assert_eq(_world.crank_progress(winch), 0.0, "and the next move starts fresh")
	assert_signal_emitted(_world, "crate_arrived")


func test_two_players_cranking_lift_it_in_half_the_time() -> void:
	_build_winch()
	var second: Actor = _player("Second", 1, HOLE + Vector2i.DOWN, Vector2i.UP)
	for i in 75:
		_world.crank(_top, 0.1)
		_world.crank(second, 0.1)
	assert_eq(_crate().tile.depth, 1, "up in 7.5 s")


func test_letting_go_stops_the_crate_short_of_the_top() -> void:
	var winch: Fixture = _build_winch()
	_crank(_top, 10.0)
	assert_eq(_crate().tile.depth, 2, "not arrived")
	assert_gt(_world.crank_progress(winch), 0.6, "and where it stopped is kept")


func test_lowering_takes_five_seconds() -> void:
	_build_winch()
	_crank(_top, 15.0)
	_crank(_top, 4.9)
	assert_eq(_crate().tile.depth, 1, "still up at 4.9 s")
	_crank(_top, 0.1)
	assert_eq(_crate().tile.depth, 2, "down at 5 s")


func test_lowering_onto_someone_waits_and_says_so_once() -> void:
	_build_winch()
	_crank(_top, 15.0)
	_bottom.move_to(WorldPos.new(HOLE.x, HOLE.y, 2), &"test")
	_crank(_top, 8.0)
	assert_eq(_crate().tile.depth, 1, "it waits in the hole")
	assert_signal_emit_count(_world, "crank_refused", 1, "said once")


func test_the_winch_is_cranked_from_the_top_only() -> void:
	_build_winch()
	_bottom.crank(true)
	assert_eq(get_signal_parameters(_world, "crank_refused")[1], World.CRANK_REFUSAL.FROM_BELOW,
		"from below, it says why")
	_world.crank(_bottom, 20.0)
	assert_eq(_crate().tile.depth, 2, "and nothing moves")


func test_held_interact_cranks_on_the_physics_tick() -> void:
	var winch: Fixture = _build_winch()
	assert_true(_top.has_interaction(), "a winch is something to interact with")
	_top.crank(true)
	_top._physics_process(0.5)
	assert_almost_eq(_world.crank_progress(winch), 0.5 / 15.0, 0.001, "half a second's work")
	_top.crank(false)
	_top._physics_process(0.5)
	assert_almost_eq(_world.crank_progress(winch), 0.5 / 15.0, 0.001, "let go, it stops")


func test_at_the_top_the_crate_is_filled_and_emptied_in_the_hole() -> void:
	_build_winch()
	_crate().contents.add(&"stone", 3)
	_crank(_top, 15.0)
	_world.take_requested.emit(_top)
	assert_eq(_top.pack.count_of(&"stone"), 3, "taken from the hole")
	_top.pack.add(&"timber", 2)
	_world.drop_requested.emit(_top, &"timber", 2)
	assert_eq(_crate().contents.count_of(&"timber"), 2, "and put back in")


# --- saving (015 trap 4) ---

func test_the_crate_and_what_it_holds_are_saved() -> void:
	_build_winch()
	_crate().contents.add(&"stone", 7)
	var saved: Array = SaveGame._serialize_fixtures(_world.level_at(2).level_fixtures)
	var back: LevelFixtures = SaveGame._deserialize_fixtures(2, saved)
	var crate: Fixture = back.of_kind(ObjectKind.OBJECT.CRATE)[0]
	assert_eq(crate.contents.count_of(&"stone"), 7, "its stone")


func test_a_save_mid_crank_finds_the_crate_at_its_last_end() -> void:
	_build_winch()
	_crank(_top, 10.0)
	var saved: Array = SaveGame._serialize_fixtures(_world.level_at(2).level_fixtures)
	assert_eq(saved.filter(func(entry: Dictionary) -> bool:
		return entry.kind == ObjectKind.OBJECT.CRATE).size(), 1, "on -2, where it last arrived")
	var fresh: World = autofree(World.new())
	assert_eq(fresh._crank_progress.size(), 0, "a loaded world has no crank under way")


func test_a_crate_saved_without_contents_loads_empty() -> void:
	var back: LevelFixtures = SaveGame._deserialize_fixtures(2,
		[{"kind": ObjectKind.OBJECT.CRATE, "x": 0, "y": 0, "id": 5}])
	assert_true(back.find(5).contents.is_empty(), "an empty crate, not none")


# --- building it from build mode ---

func _cursor_on(tile: Vector2i) -> BuildCursor:
	var cursor: BuildCursor = autofree(BuildCursor.new())
	cursor.actor = _top
	cursor.set_active(true)
	cursor.tile = tile
	return cursor


func test_build_mode_aims_a_winch_at_a_hole_with_room_below() -> void:
	_top.pack.add(&"timber", 12)
	_top.pack.add(&"stone", 20)
	assert_eq(_cursor_on(HOLE).problem(ObjectKind.OBJECT.WINCH), BuildCursor.PROBLEM.NONE, "valid")
	assert_eq(_cursor_on(HOLE).label_text(ObjectKind.OBJECT.WINCH), "Winch · 12 timber, 20 stone",
		"named with its cost")
	_world.level_at(2).level_tiles.set_top(HOLE.x, HOLE.y, TileKind.TOP.MINABLE_ROCK)
	assert_eq(_cursor_on(HOLE).problem(ObjectKind.OBJECT.WINCH),
		BuildCursor.PROBLEM.LANDING_OCCUPIED, "no floor for the crate")


func test_the_winch_and_crate_have_art_and_a_build_slot() -> void:
	assert_true(FixtureRenderer.TEXTURES.has(ObjectKind.OBJECT.WINCH), "a winch")
	assert_true(FixtureRenderer.TEXTURES.has(ObjectKind.OBJECT.CRATE), "a crate")
	assert_true(Hotbar.new().builds.has(ObjectKind.OBJECT.WINCH), "buildable")
	assert_false(ObjectKind.OBJECT.CRATE in Hotbar.BUILDABLE, "the crate comes with its winch")


func test_the_notice_says_how_full_the_crate_is() -> void:
	assert_eq(RefusalNotice.crate_text(46.0, 120.0), "In the crate: 46 / 120 kg")
