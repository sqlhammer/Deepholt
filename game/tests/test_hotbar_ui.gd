extends GutTest

# The hotbar on screen and the keys that drive it (D-170, D-171), and
# the inventory screen (D-172, D-174): focus, sections, assigning by
# key, click and pad, the take-this preview, and the take notice.

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


func test_the_open_inventory_keeps_the_selection_unless_choosing() -> void:
	_inventory.set_open(true)
	_press(&"hotbar_next")
	assert_eq(_actor.hotbar.selected_tool, 0, "LB / RB do nothing to the selection")


func test_the_pad_chooses_a_build_slot_from_the_build_section() -> void:
	_inventory.set_open(true)
	_inventory.switch_section(1)
	_inventory.focus_row(1)
	_inventory.begin_assign()
	assert_eq(_hud.assign_slot, 1, "the prop is in slot 2")
	_inventory.step_assign(2)
	_inventory.confirm_assign()
	assert_eq(_actor.hotbar.builds[3], ObjectKind.OBJECT.TIMBER_PROP, "now slot 4")


func test_a_click_on_a_slot_selects_it() -> void:
	_hud.slot_clicked.connect(_handler.select_slot)
	_hud.slot_clicked.emit(1)
	assert_eq(_actor.hotbar.selected_tool, 1, "the clicked slot")


func test_a_paused_handler_selects_nothing() -> void:
	_handler.pause()
	_press(&"hotbar_2")
	assert_eq(_actor.hotbar.selected_tool, 0, "a fade ignores the keys")


# --- the inventory: focus and sections (D-172) ---

func test_the_inventory_focus_moves_and_wraps_and_switches_sections() -> void:
	_inventory.set_open(true)
	assert_eq(_inventory.section, InventoryOverlay.SECTION.PACK, "the pack first")
	assert_eq(_inventory.row_count(), 3, "timber, pick, shovel")
	_inventory.move_focus(-1)
	assert_eq(_inventory.focus, 2, "up from the top wraps")
	_inventory.focus_row(1)
	assert_eq(_inventory.focus, 1, "the mouse moves it too")
	_inventory.switch_section(1)
	assert_eq(_inventory.section, InventoryOverlay.SECTION.BUILD, "then the build section")
	assert_eq(_inventory.focus, 0, "focus starts at the top")
	assert_true(_hud.showing_builds, "the bar shows build slots for it")
	assert_string_contains(_inventory.text(), "Ladder  4 timber  [1]", "costs and slots")
	_inventory.set_open(false)
	assert_false(_hud.showing_builds, "closing brings the tools back")


func test_every_row_shows_its_weight_and_its_slot() -> void:
	_inventory.set_open(true)
	var text: String = _inventory.text()
	assert_string_contains(text, "1 Flint Shovel  2.5 kg  [2]", "the shovel, in slot 2")
	assert_string_contains(text, "1 Flint Pickaxe  3 kg  [1]", "the pick, in slot 1")
	assert_string_contains(text, "10 Timber  20 kg", "timber, on no slot")
	assert_string_contains(text, "25.5 / 60 kg", "the load in the header")


# --- assigning (D-172, trap 7) ---

func _focus_on(id: StringName) -> void:
	_inventory.focus_row(_inventory.rows().find(id))


func test_a_number_key_with_the_inventory_open_assigns_not_selects() -> void:
	_inventory.set_open(true)
	_focus_on(SHOVEL)
	_press(&"hotbar_5")
	assert_eq(_actor.hotbar.tools[4], SHOVEL, "the shovel to slot 5")
	assert_eq(_actor.hotbar.selected_tool, 0, "and the selection didn't move")


func test_a_click_on_a_slot_with_the_inventory_open_assigns() -> void:
	_inventory.set_open(true)
	_focus_on(PICK)
	_handler.select_slot(3)
	assert_eq(_actor.hotbar.tools[3], PICK, "the pick to slot 4")


func test_only_tools_go_on_the_hotbar() -> void:
	_inventory.set_open(true)
	_focus_on(&"timber")
	assert_false(_inventory.assign_to(2), "timber isn't a tool")
	assert_eq(_inventory.message, "Only tools go on the hotbar.", "and it says so")
	_inventory.begin_assign()
	assert_false(_inventory.assigning, "the pad can't begin it either")


func test_the_pad_chooses_a_slot_then_confirms_or_cancels() -> void:
	_inventory.set_open(true)
	_focus_on(SHOVEL)
	_inventory.begin_assign()
	assert_true(_inventory.assigning, "choosing")
	assert_eq(_hud.assign_slot, 1, "from the slot it's in")
	_press(&"hotbar_next")
	_press(&"hotbar_next")
	assert_eq(_hud.assign_slot, 3, "LB / RB move the choice")
	_inventory.cancel_assign()
	assert_eq(_actor.hotbar.tools[3], &"", "cancelled: nothing moved")
	assert_eq(_hud.assign_slot, -1, "and the mark is gone")
	_inventory.begin_assign()
	_inventory.step_assign(4)
	_inventory.confirm_assign()
	assert_eq(_actor.hotbar.tools[5], SHOVEL, "confirmed: in slot 6")
	assert_false(_inventory.assigning, "and done")


func test_build_slots_are_assigned_from_the_build_section() -> void:
	_inventory.set_open(true)
	_inventory.switch_section(1)
	_inventory.focus_row(1)
	assert_true(_inventory.assign_to(0), "the prop to slot 1")
	assert_eq(_actor.hotbar.builds.slice(0, 2), [ObjectKind.OBJECT.TIMBER_PROP,
		ObjectKind.OBJECT.LADDER], "swapped with the ladder")


func test_the_build_section_drops_nothing() -> void:
	_inventory.set_open(true)
	_inventory.switch_section(1)
	_inventory.drop_stack()
	_inventory.drop_one()
	assert_eq(_actor.pack.count_of(&"timber"), 10, "nothing left the pack")


func test_dropping_the_held_tool_leaves_bare_hands() -> void:
	_inventory.set_open(true)
	_focus_on(PICK)
	_inventory.drop_one()
	assert_eq(_actor.hotbar.tools[0], &"", "its slot empties")
	assert_eq(_actor.tool(), Hotbar.BARE_HANDS, "bare hands")
	assert_eq(_world.level_at(1).level_drops.at(Vector2i.ZERO), {PICK: 1}, "it's on the floor")


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
