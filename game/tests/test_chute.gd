extends GutTest

# The chute (D-219, D-220): over a hole, on the hole's own level, for
# 2 timber. A drop made facing it goes down it and lands on the level
# below at the same (x, y), on through any chute there, spilled to the
# nearest open tile when the landing can't hold it. A hole holds a
# ladder under it or a chute over it, never both.

const Worlds = preload("res://tests/worlds.gd")
const HOLE: Vector2i = Vector2i(2, 0)
const BESIDE: Vector2i = Vector2i(1, 0)

var _world: World
var _actor: Actor


# Levels 0 to 3 of solid rock. On -1: open floor at BESIDE and a hole
# at HOLE; on -2 the hole's landing is open, as a breach leaves it.
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2, 3]))
	var minus_one: LevelTiles = _world.level_at(1).level_tiles
	minus_one.set_top(BESIDE.x, BESIDE.y, TileKind.TOP.OPEN)
	minus_one.set_top(HOLE.x, HOLE.y, TileKind.TOP.OPEN)
	minus_one.set_ground(HOLE.x, HOLE.y, TileKind.GROUND.HOLE)
	_open(2, HOLE)
	_actor = Actor.create(Global.actor_packed_scene, "Hauler", WorldPos.new(BESIDE.x, BESIDE.y, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)
	_actor.facing = Vector2i.RIGHT
	watch_signals(_world)


func _open(depth: int, tile: Vector2i) -> void:
	_world.level_at(depth).level_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)


func _hole(depth: int, tile: Vector2i) -> void:
	_open(depth, tile)
	_world.level_at(depth).level_tiles.set_ground(tile.x, tile.y, TileKind.GROUND.HOLE)


func _add(kind: int, depth: int, tile: Vector2i) -> Fixture:
	var fixture: Fixture = Fixture.new(kind, WorldPos.new(tile.x, tile.y, depth),
		_world.fixture_ids.allocate())
	_world.level_at(depth).level_fixtures.add(fixture)
	return fixture


func _place(kind: int, depth: int, tile: Vector2i, actor: Actor = null) -> void:
	_world.place_requested.emit(actor, kind, WorldPos.new(tile.x, tile.y, depth))


func _refusal() -> int:
	var args: Array = get_signal_parameters(_world, "request_refused")
	return args[3] if args != null else -1


# --- placing ---

func test_a_chute_goes_over_a_hole_for_two_timber() -> void:
	_actor.pack.add(&"timber", 3)
	_place(ObjectKind.OBJECT.CHUTE, 1, HOLE, _actor)
	assert_signal_emitted(_world, "fixture_placed")
	assert_eq(_world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.CHUTE).size(), 1, "placed")
	assert_eq(_actor.pack.count_of(&"timber"), 1, "two timber paid")


func test_a_chute_on_plain_floor_is_refused() -> void:
	_place(ObjectKind.OBJECT.CHUTE, 1, BESIDE)
	assert_eq(_refusal(), World.FIXTURE_REFUSAL.NEEDS_HOLE, "it needs a hole")


func test_a_chute_over_a_hole_with_a_ladder_under_it_is_refused() -> void:
	_add(ObjectKind.OBJECT.LADDER, 2, HOLE)
	_place(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	assert_eq(_refusal(), World.FIXTURE_REFUSAL.HOLE_IN_USE, "one hole, one use")


func test_a_ladder_under_a_hole_with_a_chute_in_it_is_refused() -> void:
	_add(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	_place(ObjectKind.OBJECT.LADDER, 2, HOLE)
	assert_eq(_refusal(), World.FIXTURE_REFUSAL.HOLE_IN_USE, "and the other way")


func test_two_chutes_in_one_hole_are_refused() -> void:
	_add(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	_place(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	assert_eq(_refusal(), World.FIXTURE_REFUSAL.TILE_OCCUPIED, "already there")


func test_a_load_reports_a_hole_used_twice() -> void:
	_add(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	_add(ObjectKind.OBJECT.LADDER, 2, HOLE)
	var found: Array[String] = FixturePlacement.problems(_world.levels())
	assert_eq(found.size(), 2, "both ends report it")
	assert_string_contains(found[0], "HOLE_IN_USE")


func test_a_legal_chute_loads_clean() -> void:
	_add(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	assert_eq(FixturePlacement.problems(_world.levels()), [] as Array[String], "no report")


# --- what goes in comes out below ---

func test_a_drop_facing_a_chute_lands_on_the_level_below() -> void:
	var chute: Fixture = _add(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	_actor.pack.add(&"stone", 5)
	_world.drop_requested.emit(_actor, &"stone", 5)
	assert_eq(_actor.pack.count_of(&"stone"), 0, "out of the pack")
	assert_eq(_world.level_at(1).level_drops.is_empty(), true, "nothing lies up here")
	assert_eq(_world.level_at(2).level_drops.at(HOLE), {&"stone": 5}, "all of it below")
	var heard: Array = get_signal_parameters(_world, "items_chuted")
	assert_true(heard[1].equals(chute.tile), "from the chute")
	assert_true(heard[2].equals(WorldPos.new(HOLE.x, HOLE.y, 2)), "to the tile below")
	assert_eq(heard[4], 5, "five stone")


func test_a_drop_not_facing_a_chute_lands_at_your_feet() -> void:
	_add(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	_actor.facing = Vector2i.LEFT
	_actor.pack.add(&"stone", 2)
	_world.drop_requested.emit(_actor, &"stone", 2)
	assert_eq(_world.level_at(1).level_drops.at(BESIDE), {&"stone": 2}, "on your own tile")
	assert_signal_not_emitted(_world, "items_chuted")


func test_chutes_stack_through_every_level() -> void:
	_add(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	_hole(2, HOLE)
	_add(ObjectKind.OBJECT.CHUTE, 2, HOLE)
	_open(3, HOLE)
	_actor.pack.add(&"stone", 3)
	_world.drop_requested.emit(_actor, &"stone", 3)
	assert_true(_world.level_at(2).level_drops.is_empty(), "straight past -2")
	assert_eq(_world.level_at(3).level_drops.at(HOLE), {&"stone": 3}, "down to -3")


func test_a_landing_with_a_fixture_spills_to_an_open_neighbor() -> void:
	_add(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	_add(ObjectKind.OBJECT.BRAZIER, 2, HOLE)
	_open(2, HOLE + Vector2i.DOWN)
	_actor.pack.add(&"stone", 1)
	_world.drop_requested.emit(_actor, &"stone", 1)
	assert_eq(_world.level_at(2).level_drops.at(HOLE + Vector2i.DOWN), {&"stone": 1},
		"beside the brazier")


func test_a_landing_with_nowhere_open_keeps_the_items_buried() -> void:
	_add(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	_world.level_at(2).level_tiles.set_top(HOLE.x, HOLE.y, TileKind.TOP.RUBBLE)
	_actor.pack.add(&"stone", 1)
	_world.drop_requested.emit(_actor, &"stone", 1)
	assert_eq(_world.level_at(2).level_drops.at(HOLE), {&"stone": 1}, "buried, not lost")


func test_a_player_below_picks_up_what_arrives() -> void:
	_add(ObjectKind.OBJECT.CHUTE, 1, HOLE)
	_open(2, HOLE + Vector2i.LEFT)
	var below: Actor = Actor.create(Global.actor_packed_scene, "Catcher",
		WorldPos.new(HOLE.x - 1, HOLE.y, 2), _world.level_at(2), ActorKind.ACTOR.PLAYER)
	_world.add_actor(below)
	_actor.pack.add(&"stone", 2)
	_world.drop_requested.emit(_actor, &"stone", 2)
	below.move_to(WorldPos.new(HOLE.x, HOLE.y, 2), &"test")
	assert_eq(below.pack.count_of(&"stone"), 2, "caught on the next step")


# --- building it ---

func test_every_buildable_has_a_build_slot() -> void:
	var hotbar: Hotbar = Hotbar.new()
	assert_true(hotbar.builds.has(ObjectKind.OBJECT.CHUTE), "a new bar offers the chute")
	var old: Dictionary = {"builds": [ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.TIMBER_PROP,
		0, 0, 0, 0, 0, 0]}
	assert_true(Hotbar.from_save(old).builds.has(ObjectKind.OBJECT.CHUTE),
		"and a bar saved before chutes gets one")


func _cursor_on(tile: Vector2i) -> BuildCursor:
	var cursor: BuildCursor = autofree(BuildCursor.new())
	cursor.actor = _actor
	cursor.set_active(true)
	cursor.tile = tile
	return cursor


func test_build_mode_aims_a_chute_at_a_hole() -> void:
	_actor.pack.add(&"timber", 2)
	assert_eq(_cursor_on(HOLE).problem(ObjectKind.OBJECT.CHUTE), BuildCursor.PROBLEM.NONE,
		"over the hole")
	assert_eq(_cursor_on(BESIDE).problem(ObjectKind.OBJECT.CHUTE), BuildCursor.PROBLEM.NEEDS_HOLE,
		"not on the floor")
	assert_eq(_cursor_on(HOLE).label_text(ObjectKind.OBJECT.CHUTE), "Chute · 2 timber",
		"named with its cost")


func test_build_mode_says_a_hole_is_in_use() -> void:
	_actor.pack.add(&"timber", 4)
	_add(ObjectKind.OBJECT.LADDER, 2, HOLE)
	assert_eq(_cursor_on(HOLE).problem(ObjectKind.OBJECT.CHUTE), BuildCursor.PROBLEM.HOLE_IN_USE,
		"a ladder is under it")


func test_build_mode_places_a_chute_on_the_holes_own_level() -> void:
	_actor.pack.add(&"timber", 2)
	_cursor_on(HOLE).place(ObjectKind.OBJECT.CHUTE)
	assert_eq(_world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.CHUTE).size(), 1,
		"on -1, over the hole")


func test_a_chute_has_art() -> void:
	assert_true(FixtureRenderer.TEXTURES.has(ObjectKind.OBJECT.CHUTE), "drawn")
	assert_eq(ObjectKind.display_name(ObjectKind.OBJECT.CHUTE), "Chute", "and named")
