extends GutTest

# The grid's cell order (D-175 to D-177): one cell per item id, never
# a cap, following the pack and the tool bar, saved per actor.

const PICK: StringName = &"flint_pickaxe"


func _grid_with(items: Dictionary) -> PackGrid:
	var pack: Pack = Pack.new()
	var hotbar: Hotbar = Hotbar.new()
	hotbar.watch(pack)
	var grid: PackGrid = PackGrid.new()
	grid.watch(pack, hotbar)
	for id: StringName in items: pack.add(id, items[id])
	return grid


func test_things_take_the_first_empty_cell_and_leave_when_gone() -> void:
	var grid: PackGrid = _grid_with({&"stone": 2, &"timber": 1})
	assert_eq(grid.cells.slice(0, 3), [&"stone", &"timber", &""], "in the pack's order")
	grid._pack.remove(&"stone", 2)
	assert_eq(grid.cells.slice(0, 2), [&"", &"timber"], "the stone's cell empties; timber stays")
	grid._pack.add(&"copper_ore", 1)
	assert_eq(grid.cells[0], &"copper_ore", "the next thing takes the gap")


func test_a_tool_on_the_bar_isnt_in_the_grid_until_a_second_one_comes() -> void:
	var grid: PackGrid = _grid_with({PICK: 1})
	assert_false(grid.cells.has(PICK), "the pick is on the bar")
	grid._hotbar.tools.fill(PICK)
	grid._pack.add(PICK, 8)
	assert_eq(grid.count_in_grid(PICK), 1, "eight on the bar, the ninth in the grid")
	assert_true(grid.cells.has(PICK), "shown")


func test_the_cells_are_room_not_a_cap() -> void:
	var grid: PackGrid = PackGrid.new()
	var pack: Pack = Pack.new()
	grid.watch(pack, null)
	for i in range(70): pack.add(StringName("thing_%d" % i), 1)
	assert_eq(grid.cells.size(), 72, "a ninth row for kinds 65 to 70")
	assert_eq(grid.cells[69], &"thing_69", "every one has a cell")
	assert_eq(pack.to_save().size(), 70, "nothing refused")


func test_a_grid_round_trips_and_a_malformed_one_is_rebuilt() -> void:
	var grid: PackGrid = _grid_with({&"stone": 1, &"timber": 1})
	grid.swap(0, 12)
	var copy: PackGrid = PackGrid.from_save(grid.to_save())
	assert_eq(copy.cells, grid.cells, "cell for cell")
	var broken: PackGrid = PackGrid.from_save([1, 2, 3])
	assert_push_warning("isn't rows of 8")
	assert_eq(broken.cells.size(), 64, "an empty grid")
	assert_eq(PackGrid.from_save(null).cells.size(), 64, "no grid saved: an empty one, quietly")


func test_a_saved_cell_for_something_gone_empties_and_new_things_fill_in() -> void:
	var saved: Array = []
	saved.resize(64)
	saved.fill("")
	saved[10] = "stone"
	saved[11] = "mithril"
	var grid: PackGrid = PackGrid.from_save(saved)
	var pack: Pack = Pack.new()
	pack.add(&"stone", 1)
	pack.add(&"timber", 1)
	grid.watch(pack, null)
	assert_eq(grid.cells[10], &"stone", "where it was saved")
	assert_eq(grid.cells[11], &"", "nothing carried, no cell")
	assert_eq(grid.cells[0], &"timber", "the rest fills in")


func test_moving_a_thing_to_a_cell_swaps() -> void:
	var grid: PackGrid = _grid_with({&"stone": 1, &"timber": 1})
	assert_true(grid.move_to(&"timber", 0), "the timber to the first cell")
	assert_eq(grid.cells.slice(0, 2), [&"timber", &"stone"], "swapped")
	assert_false(grid.move_to(&"copper_ore", 3), "not in the grid")
	assert_false(grid.swap(0, 99), "no cell 99")


func test_an_actors_grid_is_saved() -> void:
	var actor: Actor = autofree(Global.actor_packed_scene.instantiate())
	actor.pack.add(&"stone", 1)
	actor.grid.swap(0, 7)
	var copy: PackGrid = PackGrid.from_save(actor.grid.to_save())
	assert_eq(copy.cells[7], &"stone", "the order the player gave it")
