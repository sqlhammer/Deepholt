extends GutTest

# The fixture gatekeeper, on the world (D-090, D-100, D-103, D-104,
# D-125), and the placement rules it enforces (FixturePlacement).
# Requests in, a re-check, a change through the level's LevelFixtures,
# then an outcome out. Mirrors the world's dig flow (D-078).

const OPEN: Vector2i = Vector2i(3, 3)
const UNDER_HOLE: Vector2i = Vector2i(2, 2)

var _world: World
var _levels: Array[Level] = []


func before_each() -> void:
	_levels.clear()
	_world = autofree(World.new())
	for depth in [0, 1]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		_world.add_level(level)
		_levels.append(level)
		for tile: Vector2i in [OPEN, UNDER_HOLE]:
			level.level_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)
	# A hole on the Surface over (2, 2), so a ladder there on -1 is
	# legal.
	_levels[0].level_tiles.set_ground(UNDER_HOLE.x, UNDER_HOLE.y, TileKind.GROUND.HOLE)
	watch_signals(_world)


func _place(kind: int, tile: Vector2i, depth: int = 1) -> void:
	_world.place_requested.emit(null, kind, WorldPos.new(tile.x, tile.y, depth))


func _refusal_reason() -> int:
	var args: Array = get_signal_parameters(_world, "request_refused")
	return args[3] if args != null else -1


# --- placing ---

func test_an_accepted_placement_adds_the_fixture_and_announces_it() -> void:
	_place(ObjectKind.OBJECT.WORLD_SPAWN, OPEN)
	var on_tile: Array[Fixture] = _levels[1].level_fixtures.at(OPEN)
	assert_eq(on_tile.size(), 1, "the fixture is in -1's store")
	assert_signal_emitted(_world, "fixture_placed", "and announced")
	assert_signal_not_emitted(_world, "request_refused")
	if on_tile.size() == 1:
		assert_eq(on_tile[0].kind, ObjectKind.OBJECT.WORLD_SPAWN, "of the requested kind")
		assert_eq(on_tile[0].tile.depth, 1, "at the requested depth")


func test_a_ladder_under_a_hole_is_accepted() -> void:
	_place(ObjectKind.OBJECT.LADDER, UNDER_HOLE)
	assert_true(_levels[1].level_fixtures.has_kind_at(UNDER_HOLE, ObjectKind.OBJECT.LADDER), "placed")


# --- refusals ---

func test_a_depth_with_no_level_is_refused() -> void:
	_place(ObjectKind.OBJECT.WORLD_SPAWN, OPEN, 5)
	assert_eq(_refusal_reason(), World.FIXTURE_REFUSAL.LEVEL_NOT_EXISTS)


func test_outside_the_level_is_refused() -> void:
	_place(ObjectKind.OBJECT.WORLD_SPAWN, Vector2i(500, 0))
	assert_eq(_refusal_reason(), World.FIXTURE_REFUSAL.TILE_NOT_EXISTS)


func test_rock_is_refused() -> void:
	_place(ObjectKind.OBJECT.WORLD_SPAWN, Vector2i(10, 10))
	assert_eq(_refusal_reason(), World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE)


func test_a_hole_is_refused() -> void:
	_place(ObjectKind.OBJECT.WORLD_SPAWN, UNDER_HOLE, 0)
	assert_eq(_refusal_reason(), World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE)


func test_a_ladder_with_no_hole_above_is_refused() -> void:
	_place(ObjectKind.OBJECT.LADDER, OPEN)
	assert_eq(_refusal_reason(), World.FIXTURE_REFUSAL.NO_HOLE_ABOVE)


func test_a_ladder_on_the_top_level_is_refused() -> void:
	_place(ObjectKind.OBJECT.LADDER, OPEN, 0)
	assert_eq(_refusal_reason(), World.FIXTURE_REFUSAL.NO_HOLE_ABOVE, "nothing above the Surface")


func test_each_conflicting_pair_is_refused() -> void:
	var pairs: Array = [
		[ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.LADDER],
		[ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.WORLD_SPAWN],
		[ObjectKind.OBJECT.WORLD_SPAWN, ObjectKind.OBJECT.LADDER],
	]
	for pair in pairs:
		var existing: Fixture = Fixture.new(pair[0], WorldPos.new(UNDER_HOLE.x, UNDER_HOLE.y, 1), 900)
		_levels[1].level_fixtures.add(existing)
		var reason: int = FixturePlacement.problem(pair[1], UNDER_HOLE,
			_levels[1].level_tiles, _levels[1].level_fixtures, _levels[0].level_tiles)
		assert_eq(reason, World.FIXTURE_REFUSAL.TILE_OCCUPIED, "%s then %s" % pair)
		_levels[1].level_fixtures.remove(900)


func test_two_world_spawns_conflict() -> void:
	_place(ObjectKind.OBJECT.WORLD_SPAWN, OPEN)
	_place(ObjectKind.OBJECT.WORLD_SPAWN, OPEN)
	assert_eq(_refusal_reason(), World.FIXTURE_REFUSAL.TILE_OCCUPIED)
	assert_eq(_levels[1].level_fixtures.at(OPEN).size(), 1, "only the first was placed")


func test_a_refusal_changes_nothing() -> void:
	watch_signals(_levels[1].level_fixtures)
	_place(ObjectKind.OBJECT.LADDER, OPEN)
	assert_eq(_levels[1].level_fixtures.all().size(), 0, "nothing stored")
	assert_signal_not_emitted(_levels[1].level_fixtures, "fixture_changed")
	assert_signal_not_emitted(_world, "fixture_placed")


# --- removing ---

func test_removing_by_id_takes_it_out_and_announces_it() -> void:
	_place(ObjectKind.OBJECT.WORLD_SPAWN, OPEN)
	var id: int = _levels[1].level_fixtures.at(OPEN)[0].id
	_world.remove_requested.emit(null, id)
	assert_eq(_levels[1].level_fixtures.at(OPEN).size(), 0, "gone from the store")
	assert_signal_emitted(_world, "fixture_removed")


func test_removing_an_unknown_id_is_refused() -> void:
	_world.remove_requested.emit(null, 4242)
	assert_signal_emitted_with_parameters(_world, "request_refused",
		[null, World.FIXTURE_VERB.REMOVE, null, World.FIXTURE_REFUSAL.FIXTURE_NOT_EXISTS])


# --- ids ---

func test_a_placement_takes_the_worlds_next_fixture_id() -> void:
	_place(ObjectKind.OBJECT.WORLD_SPAWN, OPEN)
	assert_eq(_levels[1].level_fixtures.at(OPEN)[0].id, IdAllocator.FIRST_ID,
		"a fresh world's first fixture is 1")
	assert_eq(_world.fixture_ids.peek(), IdAllocator.FIRST_ID + 1, "and the counter moved on")


func test_placed_fixtures_get_different_ids() -> void:
	_place(ObjectKind.OBJECT.WORLD_SPAWN, OPEN)
	_place(ObjectKind.OBJECT.LADDER, UNDER_HOLE)
	var a: Fixture = _levels[1].level_fixtures.at(OPEN)[0]
	var b: Fixture = _levels[1].level_fixtures.at(UNDER_HOLE)[0]
	assert_ne(a.id, b.id, "unique")


func test_every_level_has_a_fixture_store() -> void:
	for level in _levels:
		assert_not_null(level.level_fixtures, "depth %d" % level.depth)


# --- the load report (D-113) ---

func _add(kind: int, tile: Vector2i, id: int, depth: int = 1) -> Fixture:
	var fixture: Fixture = Fixture.new(kind, WorldPos.new(tile.x, tile.y, depth), id)
	_levels[depth].level_fixtures.add(fixture)
	return fixture


func test_a_fixture_already_in_place_is_not_its_own_conflict() -> void:
	var ladder: Fixture = _add(ObjectKind.OBJECT.LADDER, UNDER_HOLE, 900)
	assert_eq(FixturePlacement.problem(ObjectKind.OBJECT.LADDER, UNDER_HOLE,
		_levels[1].level_tiles, _levels[1].level_fixtures, _levels[0].level_tiles, ladder),
		World.FIXTURE_REFUSAL.NONE, "ignoring itself, the ladder is fine")
	assert_eq(FixturePlacement.problem(ObjectKind.OBJECT.LADDER, UNDER_HOLE,
		_levels[1].level_tiles, _levels[1].level_fixtures, _levels[0].level_tiles),
		World.FIXTURE_REFUSAL.TILE_OCCUPIED, "a second ladder there still isn't")


func test_a_world_of_legal_fixtures_has_no_problems() -> void:
	_add(ObjectKind.OBJECT.LADDER, UNDER_HOLE, 900)
	_add(ObjectKind.OBJECT.WORLD_SPAWN, OPEN, 901)
	assert_eq(FixturePlacement.problems(_levels), [] as Array[String], "nothing to report")


func test_each_broken_rule_is_one_line_and_nothing_is_removed() -> void:
	# No hole above (3, 3), and (5, 5) is still solid rock.
	var ladder: Fixture = _add(ObjectKind.OBJECT.LADDER, OPEN, 900)
	var spawn: Fixture = _add(ObjectKind.OBJECT.WORLD_SPAWN, Vector2i(5, 5), 901)
	var problems: Array[String] = FixturePlacement.problems(_levels)
	assert_eq(problems.size(), 2, "one line each: %s" % [problems])
	assert_string_contains(problems[0], "NO_HOLE_ABOVE")
	assert_string_contains(problems[1], "TILE_NOT_PASSABLE")
	assert_eq(_levels[1].level_fixtures.all(), [ladder, spawn] as Array[Fixture],
		"both are still there")


func test_two_conflicting_fixtures_on_a_tile_are_both_reported() -> void:
	_add(ObjectKind.OBJECT.LADDER, UNDER_HOLE, 900)
	_add(ObjectKind.OBJECT.WORLD_SPAWN, UNDER_HOLE, 901)
	var problems: Array[String] = FixturePlacement.problems(_levels)
	assert_eq(problems.size(), 2, "each conflicts with the other: %s" % [problems])
	for problem: String in problems:
		assert_string_contains(problem, "TILE_OCCUPIED")


func test_a_ladder_on_the_top_level_has_no_hole_above() -> void:
	_add(ObjectKind.OBJECT.LADDER, OPEN, 900, 0)
	var problems: Array[String] = FixturePlacement.problems(_levels)
	assert_eq(problems.size(), 1, "no level above the Surface: %s" % [problems])
	assert_string_contains(problems[0], "NO_HOLE_ABOVE")


func test_an_unknown_kind_is_reported() -> void:
	_add(200, OPEN, 900)
	_add(ObjectKind.OBJECT.NULL, OPEN, 901)
	var problems: Array[String] = FixturePlacement.problems(_levels)
	assert_eq(problems.size(), 2, "both kinds are unknown: %s" % [problems])
	for problem: String in problems:
		assert_string_contains(problem, "kind this build doesn't know")


func test_an_id_shared_across_levels_is_reported() -> void:
	_add(ObjectKind.OBJECT.WORLD_SPAWN, OPEN, 900, 0)
	_add(ObjectKind.OBJECT.LADDER, UNDER_HOLE, 900, 1)
	var problems: Array[String] = FixturePlacement.problems(_levels)
	assert_eq(problems.size(), 1, "one shared id: %s" % [problems])
	assert_string_contains(problems[0], "shares its id")
