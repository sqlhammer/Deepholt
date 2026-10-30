extends GutTest

# LevelFixtures -- the fixtures on one level, filed by tile, several to
# a tile (D-100, D-103). Storage only: it announces every change and
# decides nothing.

var _store: LevelFixtures


func before_each() -> void:
	_store = LevelFixtures.new()


func _fixture(kind: int, x: int, y: int, id: int) -> Fixture:
	return Fixture.new(kind, WorldPos.new(x, y, 1), id)


func test_an_added_fixture_reads_back_on_its_tile() -> void:
	var ladder: Fixture = _fixture(ObjectKind.OBJECT.LADDER, 3, -2, 1)
	_store.add(ladder)
	assert_eq(_store.at(Vector2i(3, -2)), [ladder] as Array[Fixture], "on its tile")
	assert_eq(_store.at(Vector2i(0, 0)), [] as Array[Fixture], "and nowhere else")
	assert_eq(_store.find(1), ladder, "found by id")


func test_a_tile_holds_several_fixtures_in_order() -> void:
	var ladder: Fixture = _fixture(ObjectKind.OBJECT.LADDER, 0, 0, 1)
	var spawn: Fixture = _fixture(ObjectKind.OBJECT.WORLD_SPAWN, 0, 0, 2)
	_store.add(ladder)
	_store.add(spawn)
	assert_eq(_store.at(Vector2i.ZERO), [ladder, spawn] as Array[Fixture], "both, in the order added")
	assert_true(_store.has_kind_at(Vector2i.ZERO, ObjectKind.OBJECT.WORLD_SPAWN), "the spawn is there")


func test_removing_by_id_takes_only_that_fixture() -> void:
	var ladder: Fixture = _fixture(ObjectKind.OBJECT.LADDER, 0, 0, 1)
	var spawn: Fixture = _fixture(ObjectKind.OBJECT.WORLD_SPAWN, 0, 0, 2)
	_store.add(ladder)
	_store.add(spawn)
	assert_eq(_store.remove(1), ladder, "the removed fixture is returned")
	assert_eq(_store.at(Vector2i.ZERO), [spawn] as Array[Fixture], "the other stays")


func test_removing_the_last_fixture_on_a_tile_leaves_no_key() -> void:
	_store.add(_fixture(ObjectKind.OBJECT.LADDER, 4, 4, 1))
	_store.remove(1)
	assert_false(_store._by_tile.has(Vector2i(4, 4)), "no empty array left behind")
	assert_eq(_store.all(), [] as Array[Fixture], "the store is empty")


func test_removing_an_unknown_id_returns_null_and_announces_nothing() -> void:
	watch_signals(_store)
	assert_null(_store.remove(99), "nothing to remove")
	assert_signal_not_emitted(_store, "fixture_changed")


func test_every_change_is_announced_once() -> void:
	var ladder: Fixture = _fixture(ObjectKind.OBJECT.LADDER, 0, 0, 1)
	watch_signals(_store)
	_store.add(ladder)
	assert_signal_emitted_with_parameters(_store, "fixture_changed", [ladder, true])
	_store.remove(1)
	assert_signal_emitted_with_parameters(_store, "fixture_changed", [ladder, false])
	assert_signal_emit_count(_store, "fixture_changed", 2, "one per change")


func test_changing_a_returned_array_does_not_change_the_store() -> void:
	_store.add(_fixture(ObjectKind.OBJECT.LADDER, 0, 0, 1))
	var copy: Array[Fixture] = _store.at(Vector2i.ZERO)
	copy.clear()
	assert_eq(_store.at(Vector2i.ZERO).size(), 1, "the store still has its fixture")


func test_all_and_of_kind() -> void:
	var a: Fixture = _fixture(ObjectKind.OBJECT.LADDER, 0, 0, 1)
	var b: Fixture = _fixture(ObjectKind.OBJECT.WORLD_SPAWN, 5, 5, 2)
	var c: Fixture = _fixture(ObjectKind.OBJECT.LADDER, -3, 2, 3)
	for f in [a, b, c]: _store.add(f)
	assert_eq(_store.all(), [a, b, c] as Array[Fixture], "every fixture, in a stable order")
	assert_eq(_store.of_kind(ObjectKind.OBJECT.LADDER), [a, c] as Array[Fixture], "the ladders")


func test_a_fixture_keeps_its_own_copy_of_its_tile() -> void:
	var tile: WorldPos = WorldPos.new(1, 1, 1)
	var fixture: Fixture = Fixture.new(ObjectKind.OBJECT.LADDER, tile, 1)
	tile.x = 50
	assert_eq(fixture.tile.x, 1, "changing the caller's WorldPos doesn't move the fixture")


# Slice 003 trap 6: a load run twice must not double every ladder.
func test_adding_the_same_fixture_twice_is_refused() -> void:
	var ladder: Fixture = _fixture(ObjectKind.OBJECT.LADDER, 0, 0, 1)
	assert_true(_store.add(ladder), "the first add is taken")
	watch_signals(_store)
	assert_false(_store.add(ladder), "the second is refused")
	assert_push_error("Fixture id 1 is already on this level")
	assert_eq(_store.all(), [ladder] as Array[Fixture], "the store holds it once")
	assert_signal_not_emitted(_store, "fixture_changed", "and the refusal announces nothing")


# The id is what makes two fixtures the same: one id names one fixture.
func test_another_fixture_with_a_held_id_is_refused() -> void:
	_store.add(_fixture(ObjectKind.OBJECT.LADDER, 0, 0, 1))
	assert_false(_store.add(_fixture(ObjectKind.OBJECT.WORLD_SPAWN, 5, 5, 1)),
		"a second fixture with id 1 is refused")
	assert_push_error("Fixture id 1 is already on this level")
	assert_eq(_store.at(Vector2i(5, 5)), [] as Array[Fixture], "and not filed anywhere")
