extends GutTest

# The hotbar on screen and the keys that drive it (D-170, D-171), and
# the grid inventory (D-175 to D-178): the focus over the grid and the
# bars, picking up and putting down, dropping, sorting, the take-this
# preview, and the take notice.

const Worlds = preload("res://tests/worlds.gd")
const PICK: StringName = &"flint_pickaxe"
const SHOVEL: StringName = &"flint_shovel"

var _world: World
var _actor: Actor
var _view: View
var _cursor: BuildCursor
var _inventory: InventoryOverlay
var _hud: HotbarHud
var _handler: InputHandler


# Open floor along y = 0 on -1, a player at the origin with the
# starting kit, followed, with the cursor, inventory and HUD wired as
# the game wires them.
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([1, 2]))
	for x in range(-6, 7):
		_world.level_at(1).level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	_actor = Actor.create(Global.actor_packed_scene, "P", WorldPos.new(0, 0, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)
	for id: StringName in [&"timber", PICK, SHOVEL]:
		_actor.pack.add(id, 10 if id == &"timber" else 1)
	_view = add_child_autofree(View.new())
	_view.follow(_actor)
	_cursor = add_child_autofree(BuildCursor.new())
	_cursor.actor = _actor
	_inventory = add_child_autofree(InventoryOverlay.new())
	_inventory.actor = _actor
	_hud = add_child_autofree(HotbarHud.new())
	_hud.watch(_view)
	_hud.watch_cursor(_cursor)
	_hud.watch_inventory(_inventory)
	_handler = add_child_autofree(InputHandler.new())
	_handler.setup(_actor, func() -> Vector2: return Vector2.ZERO)
	_handler.set_physics_process(false)
	_handler.build = _cursor
	_handler.inventory = _inventory
	_handler.hotbar_hud = _hud


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	_handler._input(event)


# --- the bar (D-170) ---

func test_the_bar_shows_the_tools_then_the_build_slots_in_build_mode() -> void:
	assert_eq(_hud.slot_text(0), "Pick", "slot 1")
	assert_eq(_hud.slot_text(1), "Shovel", "slot 2")
	assert_eq(_hud.slot_text(2), "", "slot 3 empty")
	_cursor.set_active(true)
	assert_true(_hud.showing_builds, "build mode shows build slots")
	assert_eq(_hud.slot_text(0), "Ladder", "slot 1")
	assert_eq(_hud.slot_text(1), "Prop", "slot 2")
	_cursor.set_active(false)
	assert_eq(_hud.slot_text(0), "Pick", "and back")


func test_the_number_keys_select_a_tool_or_a_build_slot() -> void:
	_press(&"hotbar_2")
	assert_eq(_actor.tool(), ItemRegistry.get_item(SHOVEL).tool, "2: the shovel")
	assert_eq(_hud.selected(), 1, "outlined")
	_cursor.set_active(true)
	_press(&"hotbar_2")
	assert_eq(_cursor.item, ObjectKind.OBJECT.TIMBER_PROP, "in build mode, 2 is the prop")
	_cursor.set_active(false)
	assert_eq(_actor.hotbar.selected_tool, 1, "the tool selection kept through build mode")


func test_the_bumpers_and_the_wheel_step_along() -> void:
	_press(&"hotbar_next")
	assert_eq(_actor.hotbar.selected_tool, 1, "on one")
	_press(&"hotbar_prev")
	_press(&"hotbar_prev")
	assert_eq(_actor.hotbar.selected_tool, 7, "back past 1 to 8")
	for action: StringName in [&"hotbar_prev", &"hotbar_next"]:
		var wheel: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventMouseButton: wheel = true
		assert_true(wheel, "%s has the wheel" % action)


func test_the_bumpers_step_the_build_slots_in_build_mode() -> void:
	_cursor.set_active(true)
	_press(&"hotbar_next")
	assert_eq(_actor.hotbar.selected_build, 1, "the prop's slot")
	assert_eq(_actor.hotbar.selected_tool, 0, "tools untouched")


func test_a_click_on_a_slot_selects_it() -> void:
	_hud.slot_clicked.connect(_handler.select_slot)
	_hud.slot_clicked.emit(1)
	assert_eq(_actor.hotbar.selected_tool, 1, "the clicked slot")


func test_a_paused_handler_selects_nothing() -> void:
	_handler.pause()
	_press(&"hotbar_2")
	assert_eq(_actor.hotbar.selected_tool, 0, "a fade ignores the keys")


func test_the_bar_shows_icons() -> void:
	assert_eq(_hud.slot_icon(0), ItemRegistry.get_item(PICK).icon, "the pick's icon")
	assert_null(_hud.slot_icon(2), "an empty slot has none")
	_cursor.set_active(true)
	assert_eq(_hud.slot_icon(1), FixtureRenderer.TEXTURES[ObjectKind.OBJECT.TIMBER_PROP],
		"a build slot shows the fixture's art")


func test_every_item_has_an_icon() -> void:
	for id: StringName in ItemRegistry.ids():
		var icon: Texture2D = ItemRegistry.get_item(id).icon
		assert_not_null(icon, "%s has an icon" % id)
		if icon != null: assert_eq(icon.get_size(), Vector2(16, 16), "%s: 16 x 16" % id)


# --- the grid inventory (D-175) ---

func test_the_bar_on_screen_hides_while_the_inventory_shows_its_own() -> void:
	_inventory.set_open(true)
	assert_false(_hud.visible, "hidden")
	_inventory.set_open(false)
	assert_true(_hud.visible, "back")


func test_the_load_and_refusals_hide_under_the_open_inventory() -> void:
	var carry: CarryHud = add_child_autofree(CarryHud.new())
	var refusals: RefusalNotice = add_child_autofree(RefusalNotice.new())
	carry.watch_inventory(_inventory)
	refusals.watch_inventory(_inventory)
	_inventory.set_open(true)
	assert_false(carry.visible or refusals.visible, "both hidden: they'd show through it")
	_inventory.set_open(false)
	assert_true(carry.visible and refusals.visible, "both back")


func test_the_open_inventory_keeps_the_selection() -> void:
	_inventory.set_open(true)
	_press(&"hotbar_next")
	assert_eq(_actor.hotbar.selected_tool, 0, "LB / RB do nothing to the selection")


func test_tools_on_the_bar_arent_in_the_grid() -> void:
	_inventory.set_open(true)
	assert_eq(_actor.grid.cells.slice(0, 2), [&"timber", &""], "only the timber in the grid")
	assert_eq(_actor.hotbar.tools.slice(0, 2), [PICK, SHOVEL], "the tools on their bar")
	var text: String = _inventory.text()
	assert_string_contains(text, "10 Timber  20 kg", "count and weight")
	assert_string_contains(text, "Pack  25.5 / 60 kg", "the load in the header")


func test_the_focus_walks_the_grid_into_the_bars_and_back() -> void:
	_inventory.set_open(true)
	for i in range(7): _inventory.move(Vector2i.RIGHT)
	assert_eq([_inventory.focus_region, _inventory.focus_index], [InventoryOverlay.REGION.GRID, 7],
		"the grid's right edge")
	_inventory.move(Vector2i.RIGHT)
	assert_eq([_inventory.focus_region, _inventory.focus_index], [InventoryOverlay.REGION.BUILD, 0],
		"into the build column, level with the row")
	_inventory.move(Vector2i.LEFT)
	_inventory.move(Vector2i.LEFT)
	for i in range(8): _inventory.move(Vector2i.DOWN)
	assert_eq([_inventory.focus_region, _inventory.focus_index], [InventoryOverlay.REGION.TOOLS, 6],
		"down off the grid's bottom: the tool row, same column")
	_inventory.move(Vector2i.RIGHT)
	_inventory.move(Vector2i.RIGHT)
	assert_eq([_inventory.focus_region, _inventory.focus_index], [InventoryOverlay.REGION.BUILD, 7],
		"the tool row's end meets the build column's")
	_inventory.move(Vector2i.UP)
	assert_eq(_inventory.focus_index, 6, "up the column")


func test_the_focused_thing_is_described() -> void:
	_inventory.set_open(true)
	assert_eq(_inventory.details_text(), "10 Timber, 20 kg, 1.00 per kg", "the timber")
	_inventory._focus(InventoryOverlay.REGION.TOOLS, 1)
	assert_eq(_inventory.details_text(), "Tool slot 2: 1 Flint Shovel, 2.5 kg, 0.40 per kg",
		"the shovel")
	_inventory._focus(InventoryOverlay.REGION.BUILD, 0)
	assert_eq(_inventory.details_text(), "Build slot 1: Ladder, 4 timber", "the ladder")


func test_the_mouse_finds_cells_and_slots() -> void:
	_inventory.set_open(true)
	assert_eq(_inventory.place_at(Vector2(40, 24)), [InventoryOverlay.REGION.GRID, 1] as Array[int],
		"the grid's second cell")
	assert_eq(_inventory.place_at(Vector2(InventoryOverlay.BUILD_X + 2, 24)),
		[InventoryOverlay.REGION.BUILD, 0] as Array[int], "the first build slot")
	assert_eq(_inventory.place_at(Vector2(2, InventoryOverlay.TOOLS_Y + 2)),
		[InventoryOverlay.REGION.TOOLS, 0] as Array[int], "the first tool slot")
	assert_eq(_inventory.place_at(Vector2(33, 24)), [-1, -1] as Array[int], "a gap")
	assert_eq(_inventory.place_at(Vector2(2, InventoryOverlay.HEADER + 6 * InventoryOverlay.PITCH
		- 2)), [-1, -1] as Array[int], "a seventh row isn't shown, so isn't hit")


# D-190: 32 px cells, six rows shown, the words wrapped under them;
# the whole board fits the smallest HUD frame.
func test_the_board_fits_the_smallest_frame() -> void:
	var board: Vector2 = InventoryOverlay.BOARD_SIZE + Vector2(8, 8)
	assert_true(board.x <= ScaledHud.MIN_FRAME.x and board.y <= ScaledHud.MIN_FRAME.y,
		"%s inside %s" % [board, ScaledHud.MIN_FRAME])
	_inventory.set_open(true)
	for text: String in [_inventory.help_text(), "A/click: put down  B/right-click: cancel"]:
		assert_eq(InventoryOverlay.wrap_text(text).size(), 1, "one line: %s" % text)


func test_long_words_wrap_between_words_keeping_double_spaces() -> void:
	var long: String = "In reach: 12 Stone, 3 Copper ore, 2 Tin ore, 6 Timber (61 kg). Take it all: 86.5 / 60 kg"
	var lines: PackedStringArray = InventoryOverlay.wrap_text(long)
	assert_eq(lines.size(), 2, "two lines")
	assert_eq(" ".join(lines), long, "nothing lost")
	assert_eq(InventoryOverlay.wrap_text("a  b"), PackedStringArray(["a  b"]), "the gap kept")


func test_a_cells_weight_fits_in_four_characters() -> void:
	assert_eq(InventoryOverlay.cell_weight(2.5), "2.5", "under ten: as the pack says")
	assert_eq(InventoryOverlay.cell_weight(12.5), "13", "ten and up: whole kilos")
	assert_eq(InventoryOverlay.cell_weight(30.0), "30", "whole")


func test_the_build_columns_last_slots_lead_left_to_the_tool_row() -> void:
	_inventory.set_open(true)
	_inventory._focus(InventoryOverlay.REGION.BUILD, 5)
	_inventory.move(Vector2i.LEFT)
	assert_eq([_inventory.focus_region, _inventory.focus_index], [InventoryOverlay.REGION.GRID, 47],
		"slot 6 is level with the grid's sixth row")
	_inventory._focus(InventoryOverlay.REGION.BUILD, 6)
	_inventory.move(Vector2i.LEFT)
	assert_eq([_inventory.focus_region, _inventory.focus_index], [InventoryOverlay.REGION.TOOLS, 7],
		"slot 7 sits beside the tool row")
	_inventory._focus(InventoryOverlay.REGION.GRID, 63)
	assert_eq(_inventory.scroll, 2, "the eighth row scrolls into view")
	_inventory.move(Vector2i.RIGHT)
	assert_eq(_inventory.focus_index, 5, "from the bottom shown row: the sixth build slot")


# --- picking up and putting down (D-177) ---

func _pick(region: InventoryOverlay.REGION, index: int) -> void:
	_inventory._focus(region, index)
	_inventory.pick_or_place()


func test_cells_swap() -> void:
	_actor.pack.add(&"stone", 2)
	_inventory.set_open(true)
	_pick(InventoryOverlay.REGION.GRID, 0)
	assert_true(_inventory.holding, "the timber picked up")
	_pick(InventoryOverlay.REGION.GRID, 9)
	assert_false(_inventory.holding, "put down")
	assert_eq(_actor.grid.cells[9], &"timber", "the timber moved")
	assert_eq(_actor.grid.cells[0], &"", "and left its cell")


func test_a_tool_moves_off_the_bar_into_the_grid_and_stays_there() -> void:
	_inventory.set_open(true)
	_pick(InventoryOverlay.REGION.TOOLS, 1)
	_pick(InventoryOverlay.REGION.GRID, 5)
	assert_eq(_actor.hotbar.tools[1], &"", "off the bar")
	assert_eq(_actor.grid.cells[5], SHOVEL, "into the cell put down on")
	assert_eq(_actor.pack.count_of(SHOVEL), 1, "still carried")
	_actor.pack.add(&"stone", 1)
	assert_eq(_actor.hotbar.tools[1], &"", "a change to the pack doesn't pull it back (D-176)")


func test_a_tool_from_the_grid_onto_a_full_slot_sends_that_tool_to_the_grid() -> void:
	_inventory.set_open(true)
	_pick(InventoryOverlay.REGION.TOOLS, 1)
	_pick(InventoryOverlay.REGION.GRID, 5)
	_pick(InventoryOverlay.REGION.GRID, 5)
	_pick(InventoryOverlay.REGION.TOOLS, 0)
	assert_eq(_actor.hotbar.tools[0], SHOVEL, "the shovel in slot 1")
	assert_true(_actor.grid.cells.has(PICK), "the pick went to the grid")
	assert_false(_actor.grid.cells.has(SHOVEL), "and the shovel left it")


func test_tool_slots_swap_and_build_slots_swap() -> void:
	_inventory.set_open(true)
	_pick(InventoryOverlay.REGION.TOOLS, 0)
	_pick(InventoryOverlay.REGION.TOOLS, 4)
	assert_eq(_actor.hotbar.tools[4], PICK, "the pick to slot 5")
	_pick(InventoryOverlay.REGION.BUILD, 1)
	_pick(InventoryOverlay.REGION.BUILD, 6)
	assert_eq(_actor.hotbar.builds[6], ObjectKind.OBJECT.TIMBER_PROP, "the prop to build slot 7")


func test_only_tools_on_tool_slots_and_buildables_on_build_slots() -> void:
	_inventory.set_open(true)
	_pick(InventoryOverlay.REGION.GRID, 0)
	_pick(InventoryOverlay.REGION.TOOLS, 3)
	assert_eq(_actor.hotbar.tools[3], &"", "timber isn't a tool")
	assert_eq(_inventory.message, "Only tools go on the tool bar.", "and it says so")
	_pick(InventoryOverlay.REGION.BUILD, 0)
	_pick(InventoryOverlay.REGION.GRID, 3)
	assert_eq(_actor.grid.cells[3], &"", "a ladder isn't an item")
	assert_eq(_inventory.message, "Build slots hold only what you can build.", "and it says so")


func test_cancel_puts_it_back_and_an_empty_place_picks_up_nothing() -> void:
	_inventory.set_open(true)
	_pick(InventoryOverlay.REGION.GRID, 0)
	_inventory.cancel()
	assert_false(_inventory.holding, "nothing held")
	assert_eq(_actor.grid.cells[0], &"timber", "where it was")
	_pick(InventoryOverlay.REGION.GRID, 20)
	assert_false(_inventory.holding, "an empty cell")


func test_a_number_key_puts_the_focused_tool_in_that_slot() -> void:
	_inventory.set_open(true)
	_inventory._focus(InventoryOverlay.REGION.TOOLS, 1)
	_press(&"hotbar_5")
	assert_eq(_actor.hotbar.tools[4], SHOVEL, "the shovel to slot 5")
	assert_eq(_actor.hotbar.selected_tool, 0, "and the selection didn't move")
	_inventory._focus(InventoryOverlay.REGION.GRID, 0)
	assert_false(_inventory.assign_to(2), "timber isn't a tool")


# --- dropping and sorting (D-178) ---

func test_dropping_a_cell_or_a_tool() -> void:
	_inventory.set_open(true)
	_inventory.drop_one()
	assert_eq(_actor.pack.count_of(&"timber"), 9, "one timber")
	_inventory.drop_stack()
	assert_eq(_actor.pack.count_of(&"timber"), 0, "then the rest")
	_inventory._focus(InventoryOverlay.REGION.TOOLS, 0)
	_inventory.drop_stack()
	assert_eq(_actor.hotbar.tools[0], &"", "the pick's slot empties")
	assert_eq(_actor.tool(), Hotbar.BARE_HANDS, "bare hands")
	assert_eq(_world.level_at(1).level_drops.at(Vector2i.ZERO), {&"timber": 10, PICK: 1},
		"all on the floor")
	_inventory._focus(InventoryOverlay.REGION.BUILD, 0)
	_inventory.drop_stack()
	assert_eq(_actor.hotbar.builds[0], ObjectKind.OBJECT.LADDER, "build slots drop nothing")


func test_sorting_puts_the_best_value_per_kilo_first() -> void:
	_actor.pack.add(&"stone", 1)
	_actor.pack.add(&"copper_ore", 1)
	_inventory.set_open(true)
	_inventory.sort()
	assert_eq(_actor.grid.cells.slice(0, 3), [&"copper_ore", &"timber", &"stone"],
		"1.2, 1.0, 0.33 per kg")


func test_the_pad_buttons_in_the_inventory() -> void:
	for pair: Array in [[&"inventory_pick", JOY_BUTTON_A], [&"inventory_cancel", JOY_BUTTON_B],
			[&"drop_one", JOY_BUTTON_Y], [&"drop_stack", JOY_BUTTON_X],
			[&"inventory_sort", JOY_BUTTON_RIGHT_STICK]]:
		var found: Array = []
		for event: InputEvent in InputMap.action_get_events(pair[0]):
			if event is InputEventJoypadButton: found.append(event.button_index)
		assert_eq(found, [pair[1]], "%s" % pair[0])


# --- the take-this preview (ui-ux §5) ---

func test_the_preview_says_what_taking_would_weigh() -> void:
	_inventory.set_open(true)
	assert_eq(_inventory.preview_text(), "Nothing in reach.", "an empty floor")
	_world.level_at(1).level_drops.add(Vector2i(1, 0), &"stone", 3)
	assert_eq(_inventory.preview_text(), "In reach: 3 Stone (9 kg). Take it all: 34.5 / 60 kg",
		"the stone beside")
	_world.level_at(1).level_drops.add(Vector2i(4, 0), &"stone", 3)
	assert_string_contains(_inventory.preview_text(), "3 Stone (9 kg)", "out of reach isn't counted")


func test_the_preview_agrees_with_the_take() -> void:
	_world.level_at(1).level_drops.add(Vector2i(1, 0), &"stone", 2)
	_world.level_at(1).level_drops.add(Vector2i(-1, 0), &"copper_ore", 1)
	var shown: Dictionary = _world.drops_in_reach(_actor)
	watch_signals(_world)
	_world.take_requested.emit(_actor)
	assert_signal_emitted_with_parameters(_world, "took", [_actor, shown])


# --- the take notice (D-167) ---

func test_the_take_notice_says_what_was_taken() -> void:
	assert_eq(RefusalNotice.took_text({}), "Nothing in reach to take.", "nothing")
	assert_eq(RefusalNotice.took_text({&"stone": 2, &"copper_ore": 1}),
		"Took 2 Stone, 1 Copper ore.", "everything taken")
