extends GutTest

# Making things by hand (D-222): a CRAFT tab in the inventory beside
# PACK, switched with Q or LB / RB, opening on the last tab used; a
# list of hand recipes and the focused one's detail, what it needs
# against what's carried; confirm makes one. 015's one recipe is the
# torch, 1 timber to 2. Keys on screen are the scheme in use's only
# (D-223).

const Worlds = preload("res://tests/worlds.gd")

var _world: World
var _actor: Actor
var _inventory: InventoryOverlay


func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1]))
	_world.level_at(1).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	_actor = Actor.create(Global.actor_packed_scene, "Maker", WorldPos.new(0, 0, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)
	_inventory = add_child_autofree(InventoryOverlay.new())
	_inventory.actor = _actor
	_inventory.set_open(true)
	watch_signals(_world)


# --- the recipe and the world's rule ---

func test_the_torch_recipe_makes_two_from_one_timber_by_hand() -> void:
	var recipe: Recipe = RecipeRegistry.find(&"torch")
	assert_eq(recipe.inputs, {&"timber": 1} as Dictionary[StringName, int], "1 timber")
	assert_eq(recipe.outputs, {&"torch": 2} as Dictionary[StringName, int], "2 torches")
	assert_eq(recipe.station, Recipe.HAND, "by hand")
	assert_true(RecipeRegistry.at_station(Recipe.HAND).has(recipe), "listed by hand")


func test_making_takes_the_inputs_and_gives_the_outputs() -> void:
	_actor.pack.add(&"timber", 3)
	_world.craft_requested.emit(_actor, &"torch")
	assert_eq(_actor.pack.count_of(&"timber"), 2, "one timber used")
	assert_eq(_actor.pack.count_of(&"torch"), 2, "two torches made")
	assert_signal_emitted(_world, "crafted")


func test_making_without_the_inputs_is_refused() -> void:
	_world.craft_requested.emit(_actor, &"torch")
	assert_eq(get_signal_parameters(_world, "craft_refused")[2], World.CRAFT_REFUSAL.CANNOT_AFFORD,
		"no timber")
	assert_eq(_actor.pack.count_of(&"torch"), 0, "nothing made")


func test_an_unknown_recipe_is_refused() -> void:
	_world.craft_requested.emit(_actor, &"no_such_thing")
	assert_eq(get_signal_parameters(_world, "craft_refused")[2], World.CRAFT_REFUSAL.UNKNOWN_RECIPE)


# --- the tabs ---

func test_the_tab_switches_and_opens_on_the_last_one_used() -> void:
	assert_eq(_inventory.tab, InventoryOverlay.TAB.PACK, "PACK first")
	_inventory.switch_tab()
	assert_eq(_inventory.tab, InventoryOverlay.TAB.CRAFT, "then CRAFT")
	_inventory.set_open(false)
	_inventory.set_open(true)
	assert_eq(_inventory.tab, InventoryOverlay.TAB.CRAFT, "reopened on CRAFT")
	_inventory.switch_tab()
	assert_eq(_inventory.tab, InventoryOverlay.TAB.PACK, "and back")


func test_a_click_on_a_tab_switches_to_it() -> void:
	assert_eq(_inventory.tab_at(_inventory._tab_rect(InventoryOverlay.TAB.CRAFT).get_center()),
		InventoryOverlay.TAB.CRAFT, "the CRAFT tab is where it's drawn")


# --- the CRAFT tab ---

func test_the_craft_tab_lists_the_torch_with_what_it_needs() -> void:
	_actor.pack.add(&"timber", 3)
	_inventory.switch_tab()
	var text: String = _inventory.text()
	assert_string_contains(text, "BY HAND")
	assert_string_contains(text, "Torch  1 timber -> 2", "its row")
	assert_string_contains(text, "Timber  have 3 / need 1", "have against need")
	assert_string_contains(text, "2 x Torch, 0.4 kg", "what it makes")


func test_confirm_on_the_craft_tab_makes_one() -> void:
	_actor.pack.add(&"timber", 2)
	_inventory.switch_tab()
	_inventory.pick_or_place()
	assert_eq(_actor.pack.count_of(&"torch"), 2, "made")
	_inventory.pick_or_place()
	assert_eq(_actor.pack.count_of(&"torch"), 4, "and again")
	_inventory.pick_or_place()
	assert_eq(_actor.pack.count_of(&"torch"), 4, "out of timber, nothing more")
	assert_string_contains(_inventory.help_text(), "don't have enough", "and it says why")


func test_a_click_on_make_makes_one() -> void:
	_actor.pack.add(&"timber", 1)
	_inventory.switch_tab()
	_inventory._click_craft(_inventory.make_rect().get_center())
	assert_eq(_actor.pack.count_of(&"torch"), 2, "made")


func test_the_pack_tab_leaves_making_alone() -> void:
	_actor.pack.add(&"timber", 1)
	_inventory.make()
	assert_eq(_actor.pack.count_of(&"torch"), 0, "only from CRAFT")


# --- D-223: only the scheme in use ---

func test_the_keys_named_are_the_pads_only_with_a_pad() -> void:
	_inventory.set_gamepad(true)
	assert_eq(_inventory.make_text(), "[A] Make")
	assert_false(_inventory.help_text().contains("Enter"), "no keyboard keys")
	_inventory.switch_tab()
	assert_false(_inventory.help_text().contains("Enter"), "on CRAFT either")


func test_the_keys_named_are_the_keyboards_only_with_a_keyboard() -> void:
	_inventory.set_gamepad(false)
	assert_eq(_inventory.make_text(), "[Enter] Make")
	assert_false(_inventory.help_text().contains("A:"), "no pad buttons")
	assert_false(_inventory.help_text().contains("R3"), "none")
	_inventory.switch_tab()
	assert_false(_inventory.help_text().contains("RB"), "on CRAFT either")


func test_the_input_handler_announces_a_scheme_change() -> void:
	var input: InputHandler = add_child_autofree(InputHandler.new())
	input.setup(_actor, func() -> Vector2: return Vector2.ZERO)
	watch_signals(input)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	input._update_device_scheme(click)
	assert_signal_emitted_with_parameters(input, "device_scheme_changed",
		[InputHandler.DEVICE_SCHEME.MOUSE_AND_KEYBOARD])


func test_holding_confirm_keeps_making() -> void:
	_actor.pack.add(&"timber", 10)
	_inventory.switch_tab()
	var input: InputHandler = add_child_autofree(InputHandler.new())
	input.setup(_actor, func() -> Vector2: return Vector2.ZERO)
	input.inventory = _inventory
	Input.action_press("inventory_pick")
	for i in 10:
		input._hold_to_make(0.1)
	Input.action_release("inventory_pick")
	# Held a second in 0.1 s ticks: nothing for the first 0.4 s, then
	# about one every 0.15 s, so three to five makings, never one a tick
	var made: int = _actor.pack.count_of(&"torch") / 2
	assert_between(made, 3, 5, "%d made by holding" % made)
