extends GutTest

# Tools (D-168, D-169, D-171, D-174): items with a class and power, a
# speed from the class-and-kind table, a hotbar on every actor that
# follows its pack, and bare hands for an empty slot.

const Worlds = preload("res://tests/worlds.gd")
const FLINT_PICKAXE: String = "res://src/entity/tools/flint_pickaxe.tres"
const PICK: StringName = &"flint_pickaxe"
const SHOVEL: StringName = &"flint_shovel"

var _tuning: TuningProfile


func before_each() -> void:
	_tuning = TuningProfile.default_profile()


func _seconds(tool: ToolData, kind: int, ore: int = TileKind.ORE.NONE) -> float:
	return Digging.dig_hardness(_tuning, kind, ore) / Digging.dig_power(_tuning, tool, kind)


func _tool(id: StringName) -> ToolData:
	return ItemRegistry.get_item(id).tool


# --- tools as items (D-169) ---

func test_the_pick_and_shovel_are_items_with_tools() -> void:
	var pick: Item = ItemRegistry.get_item(PICK)
	var shovel: Item = ItemRegistry.get_item(SHOVEL)
	assert_true(pick.is_tool() and shovel.is_tool(), "both are tools")
	assert_eq(pick.tool.resource_path, FLINT_PICKAXE, "the pick's tool is the old fixed one")
	assert_eq(pick.tool.tool_class, ToolData.CLASS.PICK, "a pick")
	assert_eq(shovel.tool.tool_class, ToolData.CLASS.SHOVEL, "a shovel")
	assert_eq(pick.tool.power, 16.0, "flint's power")
	assert_eq(shovel.tool.power, 16.0, "flint's power")
	assert_eq(pick.weight_kg, 3.0, "the brief's weight")
	assert_eq(shovel.weight_kg, 2.5, "the brief's weight")
	assert_false(ItemRegistry.get_item(&"stone").is_tool(), "stone isn't a tool")


func test_bare_hands_is_a_tool_with_no_item() -> void:
	assert_eq(Hotbar.BARE_HANDS.tool_class, ToolData.CLASS.BARE_HANDS, "its own class")
	assert_eq(Hotbar.BARE_HANDS.power, 8.0, "D-081's power 8")
	for id: StringName in ItemRegistry.ids():
		assert_ne(ItemRegistry.get_item(id).tool, Hotbar.BARE_HANDS, "%s isn't bare hands" % id)


# --- the class-and-kind table (D-168, the brief's numbers) ---

func test_the_pick_digs_as_before_except_rubble() -> void:
	var pick: ToolData = _tool(PICK)
	assert_almost_eq(_seconds(pick, TileKind.TOP.MINABLE_ROCK), 0.375, 0.0001, "rock: 6 / 16")
	assert_almost_eq(_seconds(pick, TileKind.TOP.MINABLE_DIRT), 0.25, 0.0001, "dirt: 4 / 16")
	assert_almost_eq(_seconds(pick, TileKind.TOP.RUBBLE), 0.8, 0.0001, "rubble: half speed")
	assert_almost_eq(_seconds(pick, TileKind.TOP.MINABLE_ROCK, TileKind.ORE.COPPER), 0.5625,
		0.0001, "ore: 1.5x its rock")


func test_the_shovel_is_fast_on_dirt_and_slow_on_rock() -> void:
	var shovel: ToolData = _tool(SHOVEL)
	assert_almost_eq(_seconds(shovel, TileKind.TOP.MINABLE_DIRT), 0.125, 0.0001, "dirt: x2")
	assert_almost_eq(_seconds(shovel, TileKind.TOP.RUBBLE), 0.4, 0.0001,
		"rubble: the appendix's 0.4 s with a shovel")
	assert_almost_eq(_seconds(shovel, TileKind.TOP.MINABLE_ROCK), 0.9375, 0.0001, "rock: x0.4")


func test_bare_hands_digs_everything_at_power_8() -> void:
	var hands: ToolData = Hotbar.BARE_HANDS
	assert_almost_eq(_seconds(hands, TileKind.TOP.MINABLE_ROCK), 0.75, 0.0001, "rock")
	assert_almost_eq(_seconds(hands, TileKind.TOP.MINABLE_DIRT), 0.5, 0.0001, "dirt")
	assert_almost_eq(_seconds(hands, TileKind.TOP.RUBBLE), 0.8, 0.0001, "rubble")


func test_a_kind_the_table_doesnt_list_is_x1() -> void:
	var tool: ToolData = ToolData.new()
	tool.tool_class = ToolData.CLASS.SHOVEL
	tool.power = 10.0
	assert_eq(Digging.dig_power(_tuning, tool, TileKind.TOP.IMPENETRABLE_ROCK), 10.0, "no entry")
	assert_eq(Digging.dig_power(_tuning, null, TileKind.TOP.MINABLE_ROCK), 0.0, "no tool")


func test_only_a_pick_breaches() -> void:
	assert_true(Digging.breaches(_tool(PICK)), "the pick")
	assert_false(Digging.breaches(_tool(SHOVEL)), "not the shovel")
	assert_false(Digging.breaches(Hotbar.BARE_HANDS), "not bare hands")
	assert_false(Digging.breaches(null), "not nothing")


# --- the hotbar follows the pack (D-171, trap 4) ---

func _hotbar_with(items: Dictionary) -> Hotbar:
	var pack: Pack = Pack.new()
	for id: StringName in items: pack.add(id, items[id])
	var hotbar: Hotbar = Hotbar.new()
	hotbar.watch(pack)
	return hotbar


func test_an_empty_hotbar_is_bare_hands_with_the_starting_build_slots() -> void:
	var hotbar: Hotbar = _hotbar_with({})
	assert_eq(hotbar.tool(), Hotbar.BARE_HANDS, "nothing held")
	assert_eq(hotbar.builds.slice(0, 2), [ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.TIMBER_PROP],
		"ladder in 1, prop in 2 (D-174)")
	assert_eq(hotbar.build(), ObjectKind.OBJECT.LADDER, "the ladder selected")


func test_tools_take_the_first_empty_slots_in_the_packs_order() -> void:
	var hotbar: Hotbar = _hotbar_with({&"timber": 10, PICK: 1, SHOVEL: 1})
	assert_eq(hotbar.tools.slice(0, 3), [PICK, SHOVEL, &""], "pick in 1, shovel in 2, not timber")
	assert_eq(hotbar.tool(), _tool(PICK), "slot 1 selected: the pick")
	hotbar.select_tool(1)
	assert_eq(hotbar.tool(), _tool(SHOVEL), "slot 2: the shovel")
	hotbar.select_tool(2)
	assert_eq(hotbar.tool(), Hotbar.BARE_HANDS, "slot 3: empty, bare hands")


func test_losing_a_tool_empties_its_slot_and_regaining_it_takes_the_first_empty() -> void:
	var pack: Pack = Pack.new()
	var hotbar: Hotbar = Hotbar.new()
	hotbar.watch(pack)
	pack.add(PICK, 1)
	pack.add(SHOVEL, 1)
	assert_true(hotbar.assign_tool(SHOVEL, 4), "the shovel moved to 5")
	assert_eq(hotbar.tools.slice(0, 5), [PICK, &"", &"", &"", SHOVEL], "a gap at 2")
	pack.remove(PICK, 1)
	assert_eq(hotbar.tools[0], &"", "the dropped pick's slot is empty")
	pack.add(PICK, 1)
	assert_eq(hotbar.tools[0], PICK, "taken back, it takes the first empty slot")


func test_two_of_a_tool_take_two_slots() -> void:
	var hotbar: Hotbar = _hotbar_with({PICK: 2})
	assert_eq(hotbar.tools.count(PICK), 2, "one slot each")
	hotbar.select_tool(1)
	hotbar._pack.remove(PICK, 1)
	assert_eq(hotbar.tools.count(PICK), 1, "one slot left")
	assert_eq(hotbar.tools[0], PICK, "the last slot emptied, not the first")


func test_assigning_swaps_with_the_target_slot() -> void:
	var hotbar: Hotbar = _hotbar_with({PICK: 1, SHOVEL: 1})
	watch_signals(hotbar)
	assert_true(hotbar.assign_tool(PICK, 1), "the pick onto the shovel's slot")
	assert_eq(hotbar.tools.slice(0, 2), [SHOVEL, PICK], "swapped")
	assert_signal_emitted(hotbar, "changed", "announced")
	assert_false(hotbar.assign_tool(&"stone", 3), "stone isn't a tool")
	assert_false(hotbar.assign_tool(&"flint_pickaxe", 9), "no slot 9")
	assert_false(hotbar.assign_tool(PICK, 1), "already there")


func test_a_tool_the_pack_lacks_cant_be_assigned() -> void:
	var hotbar: Hotbar = _hotbar_with({PICK: 1})
	assert_false(hotbar.assign_tool(SHOVEL, 3), "no shovel in the pack")


func test_build_slots_are_rearranged_by_swapping() -> void:
	var hotbar: Hotbar = _hotbar_with({})
	assert_true(hotbar.assign_build(ObjectKind.OBJECT.LADDER, 3), "the ladder to 4")
	assert_eq(hotbar.builds.slice(0, 4), [ObjectKind.OBJECT.NULL, ObjectKind.OBJECT.TIMBER_PROP,
		ObjectKind.OBJECT.CHUTE, ObjectKind.OBJECT.LADDER], "1 empties")
	assert_eq(hotbar.build(), ObjectKind.OBJECT.NULL, "slot 1 selected, now empty")
	assert_false(hotbar.assign_build(ObjectKind.OBJECT.BRAZIER, 0), "a brazier isn't buildable")


func test_stepping_wraps_both_ways() -> void:
	var hotbar: Hotbar = _hotbar_with({})
	hotbar.step_tool(-1)
	assert_eq(hotbar.selected_tool, 7, "back from 1 is 8")
	hotbar.step_tool(1)
	assert_eq(hotbar.selected_tool, 0, "on from 8 is 1")
	hotbar.step_build(3)
	assert_eq(hotbar.selected_build, 3, "build slots step on their own")
	assert_eq(hotbar.selected_tool, 0, "the tool selection is untouched")


func test_a_hotbar_round_trips_and_a_malformed_one_falls_back() -> void:
	var hotbar: Hotbar = _hotbar_with({PICK: 1, SHOVEL: 1})
	hotbar.assign_tool(SHOVEL, 6)
	hotbar.select_tool(6)
	hotbar.assign_build(ObjectKind.OBJECT.TIMBER_PROP, 4)
	hotbar.select_build(4)
	var copy: Hotbar = Hotbar.from_save(hotbar.to_save())
	assert_eq(copy.tools, hotbar.tools, "tool slots")
	assert_eq(copy.builds, hotbar.builds, "build slots")
	assert_eq(copy.selected_tool, 6, "tool selection")
	assert_eq(copy.selected_build, 4, "build selection")
	var broken: Hotbar = Hotbar.from_save({"tools": [1, 2], "builds": "x", "selected_tool": 99})
	assert_eq(broken.tools.count(&""), Hotbar.SLOTS, "bad tool slots: empty")
	assert_eq(broken.build(), ObjectKind.OBJECT.LADDER, "bad build slots: the starting layout")
	assert_eq(broken.selected_tool, 0, "a slot past 8: the first")
	var odd: Hotbar = Hotbar.from_save({"tools": ["", "", "", "", "", "", "", ""],
		"builds": [3, 1, 0, 0, 0, 0, 0, 0]})
	assert_ne(odd.builds[0], ObjectKind.OBJECT.BRAZIER, "a brazier in a build slot is emptied")
	assert_true(odd.builds.has(ObjectKind.OBJECT.CHUTE), "and every buildable has a slot")


func test_a_saved_slot_for_a_tool_the_pack_lacks_empties() -> void:
	var hotbar: Hotbar = Hotbar.from_save({"tools": ["flint_shovel", "", "", "", "", "", "", ""]})
	hotbar.watch(Pack.new())
	assert_eq(hotbar.tools[0], &"", "no shovel carried, no shovel held")


# --- actors (D-045) ---

func test_every_actor_digs_with_its_own_selected_tool() -> void:
	var world: World = autofree(Worlds.with_levels([0]))
	var level: Level = world.level_at(0)
	var player: Actor = autofree(Actor.create(Global.actor_packed_scene, "P",
		WorldPos.new(0, 0, 0), level, ActorKind.ACTOR.PLAYER))
	var npc: Actor = autofree(Actor.create(Global.actor_packed_scene, "N",
		WorldPos.new(2, 0, 0), level, ActorKind.ACTOR.NULL))
	assert_eq(player.tool(), Hotbar.BARE_HANDS, "an empty pack: bare hands")
	npc.pack.add(SHOVEL, 1)
	assert_eq(npc.tool(), _tool(SHOVEL), "the NPC holds its own shovel")
	assert_eq(player.tool(), Hotbar.BARE_HANDS, "the player still holds nothing")


# A load replaces the pack, then the hotbar. What a replaced pack
# already holds isn't a gain (D-176): its tools sit wherever the
# loaded hotbar put them, or in the grid. What it gains afterwards is.
func test_replacing_an_actors_pack_keeps_the_hotbar_following_it() -> void:
	var actor: Actor = autofree(Global.actor_packed_scene.instantiate())
	var pack: Pack = Pack.new()
	pack.add(PICK, 1)
	actor.pack = pack
	assert_eq(actor.tool(), Hotbar.BARE_HANDS, "what it held already isn't a gain")
	assert_eq(actor.grid.cells[0], PICK, "the pick is in the grid")
	pack.add(SHOVEL, 1)
	assert_eq(actor.tool(), _tool(SHOVEL), "a gain from the new pack takes slot 1")
	pack.remove(SHOVEL, 1)
	assert_eq(actor.tool(), Hotbar.BARE_HANDS, "and it follows the new pack")
