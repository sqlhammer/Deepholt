extends GutTest

# The oil lantern (D-246, D-247): radius 7, burning 1 oil every 90 s
# from a 10-oil tank that fills from the pack when it's empty; with no
# oil it stays dark and says so. It goes in the light slot, which the
# PACK tab assigns: a torch or a lantern put down on it.

const Worlds = preload("res://tests/worlds.gd")

var _world: World
var _actor: Actor
var _tuning: TuningProfile


func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1]))
	_tuning = _world.tuning
	var tiles: LevelTiles = _world.level_at(1).level_tiles
	for x in range(0, 16):
		tiles.set_top(x, 0, TileKind.TOP.OPEN)
	_actor = Actor.create(Global.actor_packed_scene, "Carrier", WorldPos.new(0, 0, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)


func _burn(seconds: float, step: float = 1.0) -> void:
	for i in roundi(seconds / step):
		_actor._physics_process(step)


func _lantern_with_oil(oil: int) -> void:
	_actor.pack.add(&"lantern", 1)
	if oil > 0: _actor.pack.add(&"lamp_oil", oil)
	assert_eq(_actor.hotbar.light, Hotbar.LANTERN, "in the light slot")


func test_lit_it_fills_its_tank_from_the_pack() -> void:
	_lantern_with_oil(14)
	assert_true(_actor.toggle_light(), "lit")
	assert_eq(_actor.hotbar.tank, 9, "ten poured, one burning")
	assert_eq(_actor.pack.count_of(&"lamp_oil"), 4, "four left in the pack")
	assert_almost_eq(_actor.hotbar.lantern_fuel(_tuning), 1.0, 0.001, "full")


func test_one_oil_burns_90_seconds() -> void:
	_lantern_with_oil(2)
	_actor.toggle_light()
	_burn(89.0)
	assert_eq(_actor.hotbar.tank, 1, "the first still burning")
	_burn(2.0)
	assert_eq(_actor.hotbar.tank, 0, "the second lit")
	assert_true(_actor.hotbar.lit, "still lit")


func test_out_of_oil_it_goes_dark_and_says_so() -> void:
	_lantern_with_oil(1)
	watch_signals(_actor.hotbar)
	_actor.toggle_light()
	_burn(91.0)
	assert_false(_actor.hotbar.lit, "dark")
	assert_signal_emitted(_actor.hotbar, "light_dry")


func test_with_no_oil_it_wont_light() -> void:
	_lantern_with_oil(0)
	watch_signals(_actor.hotbar)
	assert_false(_actor.toggle_light(), "not lit")
	assert_signal_emitted(_actor.hotbar, "light_dry")


func test_it_tops_up_from_the_pack_when_the_tank_runs_dry() -> void:
	_lantern_with_oil(10)
	_actor.toggle_light()
	_actor.pack.add(&"lamp_oil", 3)
	_burn(900.0, 5.0)
	assert_true(_actor.hotbar.lit, "past the first tank")
	assert_eq(_actor.pack.count_of(&"lamp_oil"), 0, "the pack's three poured in")


func test_put_out_it_burns_nothing() -> void:
	_lantern_with_oil(3)
	_actor.toggle_light()
	_actor.toggle_light()
	var fuel: float = _actor.hotbar.lantern_fuel(_tuning)
	_burn(300.0, 5.0)
	assert_almost_eq(_actor.hotbar.lantern_fuel(_tuning), fuel, 0.0001, "the same")


func test_it_lights_farther_than_a_torch() -> void:
	_lantern_with_oil(1)
	_actor.toggle_light()
	assert_eq(Light.carried_radius(_actor, _tuning), 7, "the lantern's 7")
	var lit: Array[Vector2i] = Light.carried_lit_tiles(_world.level_at(1), [_actor] as Array[Actor], _tuning)
	assert_true(Vector2i(7, 0) in lit, "seven along")
	assert_false(Vector2i(8, 0) in lit, "not eight")


func test_dropping_the_last_lantern_puts_its_oil_back_in_the_pack() -> void:
	_lantern_with_oil(4)
	_actor.toggle_light()
	_world.drop_requested.emit(_actor, &"lantern", 1)
	assert_eq(_actor.hotbar.light, &"", "the slot's empty")
	assert_eq(_actor.pack.count_of(&"lamp_oil"), 3, "three back; the burning one is spent")
	assert_eq(_world.level_at(1).level_drops.at(Vector2i.ZERO).get(&"lantern", 0), 1,
		"on the ground, unlit")
	assert_true(_world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.TORCH).is_empty(),
		"not a burning torch")


func test_the_tank_is_saved() -> void:
	_lantern_with_oil(5)
	_actor.toggle_light()
	_burn(30.0)
	var back: Hotbar = Hotbar.from_save(_actor.hotbar.to_save())
	assert_eq(back.tank, 4, "the tank")
	assert_almost_eq(back.oil_left, 60.0, 0.01, "and the oil burning")


func test_the_hud_shows_its_fuel() -> void:
	var view: View = add_child_autofree(View.new())
	var hud: HotbarHud = add_child_autofree(HotbarHud.new())
	hud.watch(view)
	view.follow(_actor)
	_lantern_with_oil(10)
	assert_eq(hud.light_text(), "1 out fuel 0%", "an empty tank")
	_actor.toggle_light()
	assert_eq(hud.light_text(), "1 lit fuel 100%", "full")


# --- the light slot (D-247) ---

func _inventory() -> InventoryOverlay:
	var inventory: InventoryOverlay = add_child_autofree(InventoryOverlay.new())
	inventory.actor = _actor
	inventory.set_open(true)
	return inventory


func test_the_first_light_takes_an_empty_slot() -> void:
	_actor.pack.add(&"torch", 2)
	_actor.pack.add(&"lantern", 1)
	assert_eq(_actor.hotbar.light, &"torch", "the torch came first")


func test_a_light_put_down_on_the_slot_is_assigned() -> void:
	_actor.pack.add(&"torch", 2)
	_actor.pack.add(&"lantern", 1)
	var inventory: InventoryOverlay = _inventory()
	var cell: int = _actor.grid.cells.find(&"lantern")
	inventory._focus(InventoryOverlay.REGION.GRID, cell)
	inventory.pick_or_place()
	inventory._focus(InventoryOverlay.REGION.LIGHT, 0)
	inventory.pick_or_place()
	assert_eq(_actor.hotbar.light, Hotbar.LANTERN, "the lantern")
	assert_string_contains(inventory.help_text(), "light slot holds the oil lantern")


func test_only_a_light_goes_in_the_slot() -> void:
	_actor.pack.add(&"stone", 2)
	var inventory: InventoryOverlay = _inventory()
	inventory._focus(InventoryOverlay.REGION.GRID, _actor.grid.cells.find(&"stone"))
	inventory.pick_or_place()
	inventory._focus(InventoryOverlay.REGION.LIGHT, 0)
	inventory.pick_or_place()
	assert_eq(_actor.hotbar.light, &"", "still empty")
	assert_string_contains(inventory.help_text(), "Only a torch or a lantern")


func test_the_focus_reaches_the_light_slot_from_the_build_column() -> void:
	var inventory: InventoryOverlay = _inventory()
	inventory._focus(InventoryOverlay.REGION.BUILD, Hotbar.SLOTS - 1)
	inventory.move(Vector2i.RIGHT)
	assert_eq(inventory.focus_region, InventoryOverlay.REGION.LIGHT, "right of the column's foot")
	inventory.move(Vector2i.LEFT)
	assert_eq(inventory.focus_region, InventoryOverlay.REGION.BUILD, "and back")


func test_switching_lights_puts_the_old_one_out() -> void:
	_actor.pack.add(&"torch", 2)
	_actor.pack.add(&"lantern", 1)
	_actor.toggle_light()
	assert_true(_actor.hotbar.assign_light(Hotbar.LANTERN), "assigned")
	assert_false(_actor.hotbar.lit, "put out")
	assert_false(_actor.hotbar.assign_light(&"stone"), "stone is no light")
