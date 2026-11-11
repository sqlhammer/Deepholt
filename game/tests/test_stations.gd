extends GutTest

# Stations (D-237, D-250), the smelter's two build entries (D-240,
# D-241) and the BUILD tab (D-252): a station's recipes are made within
# 2 tiles of it, each actor by its own reach; the smelter is built for
# ore or for timber, whichever entry the player picks; every buildable
# is reached from the BUILD tab, more of them than build slots.

const Worlds = preload("res://tests/worlds.gd")

var _world: World
var _actor: Actor


# -1 (unlit), open floor from (-6, 0) to (6, 0) and the row under it,
# one player at the origin.
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([1, 2]))
	for x in range(-6, 7):
		for y in [0, 1]:
			_world.level_at(1).level_tiles.set_top(x, y, TileKind.TOP.OPEN)
	_actor = _player("P", Vector2i.ZERO)


func _player(name: String, tile: Vector2i) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, name, WorldPos.new(tile.x, tile.y, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(actor)
	return actor


func _place(entry: int, tile: Vector2i, by: Actor = null) -> Fixture:
	_world.place_requested.emit(by, entry, WorldPos.new(tile.x, tile.y, 1))
	for fixture: Fixture in _world.level_at(1).level_fixtures.at(tile):
		if fixture.kind == Building.kind_of(entry): return fixture
	return null


# --- building them (D-250) ---

func test_a_workbench_costs_6_timber_and_4_stone() -> void:
	_actor.pack.add(&"timber", 6)
	_actor.pack.add(&"stone", 4)
	assert_not_null(_place(ObjectKind.OBJECT.WORKBENCH, Vector2i(2, 0), _actor), "built")
	assert_true(_actor.pack.is_empty(), "paid")


func test_a_forge_costs_20_stone_and_4_bronze_ingots() -> void:
	assert_eq(Building.cost_of(_world.tuning, ObjectKind.OBJECT.FORGE),
		{&"stone": 20, &"bronze_ingot": 4} as Dictionary[StringName, int])


func test_stations_block_their_tile() -> void:
	for kind: int in [ObjectKind.OBJECT.WORKBENCH, ObjectKind.OBJECT.SMELTER,
			ObjectKind.OBJECT.FORGE, ObjectKind.OBJECT.BED, ObjectKind.OBJECT.STORAGE_CRATE]:
		assert_true(ObjectKind.blocks_walking(kind), "%s blocks" % ObjectKind.display_name(kind))


func test_two_stations_cant_share_a_tile() -> void:
	_place(ObjectKind.OBJECT.WORKBENCH, Vector2i(3, 0))
	assert_null(_place(ObjectKind.OBJECT.FORGE, Vector2i(3, 0)), "refused")


# --- the smelter's two entries (D-240, D-241) ---

func test_the_smelter_has_an_ore_entry_and_a_timber_entry() -> void:
	assert_eq(Building.kind_of(ObjectKind.OBJECT.SMELTER), ObjectKind.OBJECT.SMELTER)
	assert_eq(Building.kind_of(Building.SMELTER_FROM_TIMBER), ObjectKind.OBJECT.SMELTER, "the same smelter")
	assert_eq(Building.cost_of(_world.tuning, ObjectKind.OBJECT.SMELTER),
		{&"stone": 8, &"copper_ore": 12} as Dictionary[StringName, int], "ore")
	assert_eq(Building.cost_of(_world.tuning, Building.SMELTER_FROM_TIMBER),
		{&"stone": 16, &"timber": 8} as Dictionary[StringName, int], "timber")
	assert_eq(Building.entry_name(ObjectKind.OBJECT.SMELTER), "Smelter (ore)")
	assert_eq(Building.entry_name(Building.SMELTER_FROM_TIMBER), "Smelter (timber)")


func test_the_entry_picked_is_the_cost_paid() -> void:
	_actor.pack.add(&"stone", 24)
	_actor.pack.add(&"copper_ore", 12)
	_actor.pack.add(&"timber", 8)
	var smelter: Fixture = _place(Building.SMELTER_FROM_TIMBER, Vector2i(2, 0), _actor)
	assert_not_null(smelter, "built")
	assert_eq(_actor.pack.count_of(&"timber"), 0, "the timber paid")
	assert_eq(_actor.pack.count_of(&"copper_ore"), 12, "the ore kept, though it could pay")
	assert_eq(_actor.pack.count_of(&"stone"), 8, "16 stone")
	assert_not_null(smelter.machine, "a smelter, working or not")


func test_without_the_picked_entrys_cost_it_is_refused() -> void:
	_actor.pack.add(&"stone", 8)
	_actor.pack.add(&"copper_ore", 12)
	watch_signals(_world)
	assert_null(_place(Building.SMELTER_FROM_TIMBER, Vector2i(2, 0), _actor), "no timber")
	assert_signal_emitted(_world, "request_refused")
	assert_eq(_actor.pack.count_of(&"copper_ore"), 12, "and nothing taken")


# --- reach (D-237) ---

func test_a_station_is_in_reach_within_two_tiles() -> void:
	_place(ObjectKind.OBJECT.WORKBENCH, Vector2i(2, 1))
	assert_eq(_world.stations_near(_actor), [&"workbench"] as Array[StringName], "two away, diagonal")
	_actor.move_to(WorldPos.new(-1, 0, 1))
	assert_true(_world.stations_near(_actor).is_empty(), "three away")


func test_a_buried_station_is_out_of_reach() -> void:
	_place(ObjectKind.OBJECT.WORKBENCH, Vector2i(1, 0))
	_world.level_at(1).level_tiles.set_top(1, 0, TileKind.TOP.RUBBLE)
	assert_true(_world.stations_near(_actor).is_empty(), "under rubble")


func test_a_station_recipe_needs_the_station() -> void:
	_actor.pack.add(&"bronze_ingot", 4)
	_actor.pack.add(&"timber", 1)
	assert_eq(_world.craft_problem(_actor, &"bronze_pickaxe"), World.CRAFT_REFUSAL.NEEDS_STATION,
		"no bench")
	_place(ObjectKind.OBJECT.WORKBENCH, Vector2i(1, 0))
	assert_eq(_world.craft_problem(_actor, &"bronze_pickaxe"), World.CRAFT_REFUSAL.NONE, "at a bench")
	_world.craft_requested.emit(_actor, &"bronze_pickaxe")
	assert_eq(_actor.pack.count_of(&"bronze_pickaxe"), 1, "made")
	assert_eq(_world.craft_problem(_actor, &"iron_pickaxe"), World.CRAFT_REFUSAL.NEEDS_STATION,
		"iron needs a forge, not a bench")


func test_each_player_has_their_own_reach() -> void:
	var other: Actor = _player("Other", Vector2i(-5, 0))
	_place(ObjectKind.OBJECT.WORKBENCH, Vector2i(1, 0))
	_place(ObjectKind.OBJECT.FORGE, Vector2i(-6, 1))
	assert_eq(_world.stations_near(_actor), [&"workbench"] as Array[StringName], "the bench's")
	assert_eq(_world.stations_near(other), [&"forge"] as Array[StringName], "the forge's")


# --- the CRAFT tab's sections ---

func _inventory_for(actor: Actor) -> InventoryOverlay:
	var inventory: InventoryOverlay = add_child_autofree(InventoryOverlay.new())
	inventory.actor = actor
	inventory.set_open(true)
	return inventory


func test_the_craft_tab_shows_a_stations_recipes_only_in_reach() -> void:
	var inventory: InventoryOverlay = _inventory_for(_actor)
	inventory.switch_tab()
	assert_false(inventory.text().contains("AT A WORKBENCH"), "no bench, no section")
	_place(ObjectKind.OBJECT.WORKBENCH, Vector2i(1, 0))
	assert_string_contains(inventory.text(), "AT A WORKBENCH", "a bench in reach")
	assert_string_contains(inventory.text(), "Bronze Pickaxe  4 bronze, 1 timber -> 1")
	assert_string_contains(inventory.text(), "Lamp oil", "oil is pressed there")
	assert_false(inventory.text().contains("AT A FORGE"), "no forge")


func test_a_long_list_scrolls_to_the_focused_row() -> void:
	_place(ObjectKind.OBJECT.WORKBENCH, Vector2i(1, 0))
	_place(ObjectKind.OBJECT.FORGE, Vector2i(-1, 1))
	var inventory: InventoryOverlay = _inventory_for(_actor)
	inventory.switch_tab()
	var last: int = inventory.recipes().size() - 1
	for i in range(last): inventory.move(Vector2i.DOWN)
	assert_eq(inventory.craft_index, last, "at the last")
	assert_ne(inventory._row_rect(last), Rect2(), "and it's in sight")


# --- the BUILD tab (D-252) ---

func test_there_are_more_buildables_than_build_slots() -> void:
	assert_gt(Hotbar.BUILDABLE.size(), Hotbar.SLOTS)
	var bar: Hotbar = Hotbar.new()
	assert_eq(bar.builds, Hotbar.BUILDABLE.slice(0, Hotbar.SLOTS), "a new bar holds the first eight")


func test_the_build_tab_lists_every_buildable() -> void:
	var inventory: InventoryOverlay = _inventory_for(_actor)
	inventory.show_tab(InventoryOverlay.TAB.BUILD)
	var text: String = inventory.text()
	for entry: int in Hotbar.BUILDABLE:
		assert_string_contains(text, Building.entry_name(entry))
	assert_string_contains(text, "Forge  20 stone, 4 bronze ingot", "with its cost")


func test_assign_puts_the_focused_buildable_in_the_selected_slot() -> void:
	var inventory: InventoryOverlay = _inventory_for(_actor)
	inventory.show_tab(InventoryOverlay.TAB.BUILD)
	var forge: int = Hotbar.BUILDABLE.find(ObjectKind.OBJECT.FORGE)
	for i in range(forge): inventory.move(Vector2i.DOWN)
	_actor.hotbar.select_build(2)
	inventory.pick_or_place()
	assert_eq(_actor.hotbar.builds[2], ObjectKind.OBJECT.FORGE, "in slot 3")
	assert_string_contains(inventory.help_text(), "build slot 3")
	inventory.move(Vector2i.UP)
	inventory.assign_to(6)
	assert_eq(_actor.hotbar.builds[6], Building.SMELTER_FROM_TIMBER, "a number key picks the slot")


func test_the_pads_y_assigns_on_the_build_tab() -> void:
	var inventory: InventoryOverlay = _inventory_for(_actor)
	inventory.show_tab(InventoryOverlay.TAB.BUILD)
	inventory.move(Vector2i.DOWN)
	_actor.hotbar.select_build(5)
	inventory.drop_one()
	assert_eq(_actor.hotbar.builds[5], ObjectKind.OBJECT.TIMBER_PROP, "Y is assign here")
	assert_true(_actor.pack.is_empty(), "and nothing dropped")


func test_build_mode_places_the_timber_smelter_from_its_slot() -> void:
	var cursor: BuildCursor = add_child_autofree(BuildCursor.new())
	cursor.actor = _actor
	_actor.hotbar.assign_build(Building.SMELTER_FROM_TIMBER, 0)
	_actor.hotbar.select_build(0)
	cursor.set_active(true)
	cursor.set_tile(Vector2i(2, 0))
	assert_eq(cursor.problem(), BuildCursor.PROBLEM.CANNOT_AFFORD, "nothing to pay with")
	_actor.pack.add(&"stone", 16)
	_actor.pack.add(&"timber", 8)
	assert_eq(cursor.problem(), BuildCursor.PROBLEM.NONE, "now it can")
	assert_eq(cursor.label_text(), "Smelter (timber) · 16 stone, 8 timber")
	assert_true(cursor.place(), "asked")
	assert_eq(_world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.SMELTER).size(), 1, "built")


func test_a_saved_bar_from_before_gets_the_new_buildables() -> void:
	var old: Dictionary = {"tools": ["", "", "", "", "", "", "", ""],
		"builds": [1, 4, 6, 7, 0, 0, 0, 0], "selected_tool": 0, "selected_build": 0}
	var bar: Hotbar = Hotbar.from_save(old)
	assert_eq(bar.builds.slice(0, 4), [1, 4, 6, 7], "the old four kept")
	assert_eq(bar.builds.slice(4), Hotbar.BUILDABLE.slice(4, 8), "the next four after them")
