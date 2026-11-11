class_name InventoryOverlay
extends ScaledHud

# What the local player carries, what to leave behind, and what goes
# on the bars (ui-ux §5, D-175 to D-178). An 8 x 8 grid of the pack,
# each cell an item's icon, count and weight; the eight build slots in
# a column on its right; the eight tool slots along its bottom. A
# weight bar heads it, the focused thing is described under it, and a
# preview says what the load would be after taking everything in
# reach.
#
# One focus moves over all three, by the D-pad, the arrow keys or the
# mouse. Things move by picking up and putting down (D-177): A or a
# click picks up the focused thing, and again puts it down where the
# focus is, swapping; B or a right-click cancels. Only a tool goes on
# a tool slot, only a buildable on a build slot. Everything changed is
# asked of the actor's grid, hotbar or world; this only shows and asks.
# An overlay: the game keeps running. Presentation, for the local
# player (D-045).
#
# Three tabs (D-222, D-252): PACK, all of the above; CRAFT, the things
# the player can make by hand and at the stations in reach (D-237), a
# list on the left and the focused one's detail on the right: what it
# needs against what's carried, what it makes, and the key to make it;
# and BUILD, every buildable, laid out the same, the assign key putting
# the focused one in the selected build slot. Q and RB step forward
# through the tabs, LB back; it opens on the last one used. Every key
# named on screen is the current scheme's only (D-223).

# Opened or closed: the hotbar on screen hides while this shows its
# own bars.
signal open_changed(open: bool)

enum REGION {
	GRID,
	BUILD,
	TOOLS,
	# The light slot (D-247): a light is put down on it
	LIGHT,
}

enum TAB {
	PACK,
	CRAFT,
	BUILD,
}

const TAB_NAMES: Dictionary = {TAB.PACK: "PACK", TAB.CRAFT: "CRAFT", TAB.BUILD: "BUILD"}
# The CRAFT tab's sections, by station, in the order they show; a
# station's only while one is in reach (D-237)
const SECTION_TITLES: Dictionary = {&"hand": "BY HAND", &"workbench": "AT A WORKBENCH",
	&"forge": "AT A FORGE"}

# Cells big enough for the pixel font's count over the icon and the
# weight under it; six grid rows show, the rest scroll (D-190)
const CELL: int = 32
const PITCH: int = 34
const BAR_GAP: int = 6
# The tab strip on top, then the load's header under it
const TABS: int = 14
const HEADER: int = TABS + 16
const VISIBLE_ROWS: int = 6
const GRID_ORIGIN: Vector2 = Vector2(0, HEADER)
const BUILD_X: float = PackGrid.COLUMNS * PITCH + BAR_GAP
const TOOLS_Y: float = HEADER + VISIBLE_ROWS * PITCH + BAR_GAP
# The words under the board: wrapped to this width, in this many lines
# at most (the focused thing, the preview over two, the keys)
const TEXT_WIDTH: int = 480
const LINE: int = 11
const TEXT_LINES: int = 4
# Below the tool row and the build column, which runs past it
const TEXT_TOP: float = maxf(TOOLS_Y + CELL, HEADER + (Hotbar.SLOTS - 1) * PITCH + CELL) + 8
const BOARD_SIZE: Vector2 = Vector2(maxf(BUILD_X + CELL, TEXT_WIDTH),
	TEXT_TOP + TEXT_LINES * LINE)

const BACK: Color = Color(0.08, 0.07, 0.07, 0.92)
const CELL_COLOR: Color = Color(0.2, 0.19, 0.18)
const SLOT_COLOR: Color = Color(0.16, 0.18, 0.2)
const BORDER: Color = Color(0.45, 0.43, 0.4)
const FOCUS_COLOR: Color = Color(1.0, 0.9, 0.45)
const HELD_COLOR: Color = Color(0.45, 0.85, 1.0)
const SELECTED_COLOR: Color = Color(0.85, 0.85, 0.8)
const TEXT_COLOR: Color = Color(0.9, 0.9, 0.85)
const DIM_TEXT: Color = Color(0.7, 0.7, 0.65)
const HAVE_COLOR: Color = Color(0.6, 0.89, 0.48)
const LACK_COLOR: Color = Color(1.0, 0.5, 0.42)
# The CRAFT tab's two panes: the list, and the detail beside it
const LIST_WIDTH: float = 200.0
const DETAIL_X: float = LIST_WIDTH + 12.0
const ROW: float = 22.0
const TITLE_ROW: float = 13.0
const LIST_TOP: float = TABS + 6.0
# The lists end above the load at the board's foot
const LIST_BOTTOM: float = TEXT_TOP + 4.0

var is_open: bool = false
var actor: Actor
# Which tab shows; kept when closed, so it opens on the last one used
var tab: TAB = TAB.PACK
# The focused recipe on the CRAFT tab, an index into recipes()
var craft_index: int = 0
# The focused buildable on the BUILD tab, an index into Hotbar.BUILDABLE
var build_index: int = 0
# The first line of the CRAFT or BUILD list shown: it scrolls to keep
# the focused row in sight
var list_scroll: int = 0
# Whether the keys named on screen are a pad's (D-223). Set from the
# local player's input handler as its scheme changes.
var gamepad: bool = true
# The focus: a region, and a cell (the grid, absolute) or a slot
var focus_region: REGION = REGION.GRID
var focus_index: int = 0
# What's picked up, if anything (D-177)
var holding: bool = false
var held_region: REGION = REGION.GRID
var held_index: int = 0
# The last thing said: a refusal, or what a move did
var message: String = ""
# The first grid row shown, when there are more than eight
var scroll: int = 0

var _panel: PanelContainer
var _board: Control


func _init() -> void:
	super()
	name = "InventoryOverlay"
	layer = 85
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	root.add_child(_panel)
	_board = Control.new()
	_board.custom_minimum_size = BOARD_SIZE
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_on_board_input)
	_panel.add_child(_board)


func toggle() -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	var was: bool = is_open
	is_open = value and actor != null
	_panel.visible = is_open
	holding = false
	if is_open:
		craft_index = clampi(craft_index, 0, maxi(recipes().size() - 1, 0))
		for source: Variant in [actor.pack, actor.hotbar, actor.grid]:
			if not source.changed.is_connected(_on_contents_changed):
				source.changed.connect(_on_contents_changed)
		focus_region = REGION.GRID
		focus_index = 0
		scroll = 0
		message = ""
	if is_open != was: open_changed.emit(is_open)
	_refresh()


# Q or RB: the next tab; LB, the one before. What's held is put back.
func switch_tab(step: int = 1) -> void:
	if not is_open: return
	holding = false
	message = ""
	tab = posmod(tab + step, TAB.size()) as TAB
	list_scroll = 0
	_refresh()


func show_tab(which: TAB) -> void:
	if not is_open or which == tab: return
	switch_tab(which - tab)


# The scheme whose keys are named on screen (D-223).
func set_gamepad(value: bool) -> void:
	gamepad = value
	_refresh()


# --- the CRAFT tab (D-222) ---

# What can be made here, section by section: by hand, then at each
# station in reach (D-237), each section in a stable order.
func recipes() -> Array[Recipe]:
	var list: Array[Recipe] = []
	for section: Dictionary in craft_sections(): list.append_array(section.recipes)
	return list


# The CRAFT tab's sections: {"station", "title", "recipes"}, the hand's
# always and each station's while one is in reach.
func craft_sections() -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	var near: Array[StringName] = []
	if actor != null and actor.current_level != null:
		near = actor.current_level.world.stations_near(actor)
	for station: StringName in SECTION_TITLES:
		if station != Recipe.HAND and station not in near: continue
		sections.append({"station": station, "title": SECTION_TITLES[station],
			"recipes": RecipeRegistry.at_station(station)})
	return sections


func focused_recipe() -> Recipe:
	var list: Array[Recipe] = recipes()
	if list.is_empty(): return null
	return list[clampi(craft_index, 0, list.size() - 1)]


# Confirm, or a click on Make: asks the world to make the focused
# recipe once. The world answers with what was made, or why not.
func make() -> void:
	if not is_open or tab != TAB.CRAFT: return
	var recipe: Recipe = focused_recipe()
	if recipe == null: return
	var world: World = actor.current_level.world
	var reason: World.CRAFT_REFUSAL = world.craft_problem(actor, recipe.id)
	if reason == World.CRAFT_REFUSAL.CANNOT_AFFORD:
		message = "You don't have enough to make that."
		_refresh()
		return
	message = ""
	world.craft_requested.emit(actor, recipe.id)
	_refresh()


# "1 timber -> 2": a recipe in short, for its row in the list.
static func recipe_short(recipe: Recipe) -> String:
	var parts: PackedStringArray = []
	for id: StringName in recipe.inputs:
		parts.append("%d %s" % [recipe.inputs[id], _item_name(id).to_lower()])
	var made: int = 0
	for id: StringName in recipe.outputs: made += recipe.outputs[id]
	return "%s -> %d" % [", ".join(parts), made]


# Each input as "Timber  have 3 / need 1", with whether there's enough.
func needs_lines(recipe: Recipe) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for id: StringName in recipe.inputs:
		var have: int = actor.pack.count_of(id)
		lines.append({"text": "%s  have %d / need %d" % [_item_name(id), have, recipe.inputs[id]],
			"enough": have >= recipe.inputs[id]})
	return lines


# "2 x Torch, 0.4 kg": what one making gives.
static func makes_text(recipe: Recipe) -> String:
	var parts: PackedStringArray = []
	var kg: float = 0.0
	for id: StringName in recipe.outputs:
		parts.append("%d x %s" % [recipe.outputs[id], _item_name(id)])
		var item: Item = ItemRegistry.find(id)
		kg += (item.weight_kg if item != null else 0.0) * recipe.outputs[id]
	return "%s, %s kg" % [", ".join(parts), CarryHud._kg(kg)]


static func _item_name(id: StringName) -> String:
	var item: Item = ItemRegistry.find(id)
	return item.display_key if item != null else String(id)


# The Make prompt, in the current scheme's keys only (D-223).
func make_text() -> String:
	return "%s Make" % ("[A]" if gamepad else "[Enter]")


# --- what's where ---

# The pack's item ids, best value per kilo first: what a sort makes
# of the grid.
func rows() -> Array[StringName]:
	var ids: Array[StringName] = []
	if actor == null: return ids
	ids.assign(actor.pack.to_save().keys().map(func(k: String) -> StringName: return StringName(k)))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return PackGrid.value_density(a) > PackGrid.value_density(b))
	return ids


# The item id (grid cell or tool slot) at a place; &"" when empty.
func id_at(region: REGION, index: int) -> StringName:
	match region:
		REGION.GRID: return actor.grid.cells[index] if index < actor.grid.cells.size() else &""
		REGION.TOOLS: return actor.hotbar.tools[index]
		REGION.LIGHT: return actor.hotbar.light
	return &""


func kind_at(slot: int) -> int:
	return actor.hotbar.builds[slot]


func _is_empty(region: REGION, index: int) -> bool:
	if region == REGION.BUILD: return kind_at(index) == ObjectKind.OBJECT.NULL
	# The light slot is put down on, never picked up from: its light
	# stays in the pack's grid too
	if region == REGION.LIGHT: return true
	return id_at(region, index) == &""


# --- moving the focus (the D-pad, the arrows) ---

# One step. The grid's right edge leads to the build column, its
# bottom to the tool row; the two bars meet at their last slots.
func move(direction: Vector2i) -> void:
	if not is_open or direction == Vector2i.ZERO: return
	if tab == TAB.CRAFT:
		craft_index = clampi(craft_index + direction.y, 0, maxi(recipes().size() - 1, 0))
		_refresh()
		return
	if tab == TAB.BUILD:
		build_index = clampi(build_index + direction.y, 0, Hotbar.BUILDABLE.size() - 1)
		_refresh()
		return
	var rows_total: int = actor.grid.cells.size() / PackGrid.COLUMNS
	match focus_region:
		REGION.GRID:
			var col: int = focus_index % PackGrid.COLUMNS
			var row: int = focus_index / PackGrid.COLUMNS
			if direction.x > 0 and col == PackGrid.COLUMNS - 1:
				_focus(REGION.BUILD, clampi(row - scroll, 0, VISIBLE_ROWS - 1))
			elif direction.y > 0 and row == rows_total - 1:
				_focus(REGION.TOOLS, col)
			else:
				col = clampi(col + direction.x, 0, PackGrid.COLUMNS - 1)
				row = clampi(row + direction.y, 0, rows_total - 1)
				_focus(REGION.GRID, row * PackGrid.COLUMNS + col)
		REGION.BUILD:
			# The column runs past the grid's shown rows: its last slots
			# sit beside the tool row, so left from them is the row's end
			if direction.x < 0 and focus_index >= VISIBLE_ROWS:
				_focus(REGION.TOOLS, Hotbar.SLOTS - 1)
			elif direction.x < 0:
				_focus(REGION.GRID, (scroll + focus_index) * PackGrid.COLUMNS + PackGrid.COLUMNS - 1)
			elif direction.y > 0 and focus_index == Hotbar.SLOTS - 1:
				_focus(REGION.TOOLS, Hotbar.SLOTS - 1)
			elif direction.x > 0 and focus_index == Hotbar.SLOTS - 1:
				# The light slot sits right of the column's foot (D-247)
				_focus(REGION.LIGHT, 0)
			else:
				_focus(REGION.BUILD, clampi(focus_index + direction.y, 0, Hotbar.SLOTS - 1))
		REGION.LIGHT:
			if direction.x < 0 or direction.y < 0: _focus(REGION.BUILD, Hotbar.SLOTS - 1)
		REGION.TOOLS:
			if direction.y < 0:
				_focus(REGION.GRID, (scroll + VISIBLE_ROWS - 1) * PackGrid.COLUMNS + focus_index)
			elif direction.x > 0 and focus_index == Hotbar.SLOTS - 1:
				_focus(REGION.BUILD, Hotbar.SLOTS - 1)
			else:
				_focus(REGION.TOOLS, clampi(focus_index + direction.x, 0, Hotbar.SLOTS - 1))


func _focus(region: REGION, index: int) -> void:
	focus_region = region
	focus_index = index
	if region == REGION.GRID:
		var row: int = index / PackGrid.COLUMNS
		if row < scroll: scroll = row
		elif row >= scroll + VISIBLE_ROWS: scroll = row - VISIBLE_ROWS + 1
	_refresh()


# --- picking up and putting down (D-177) ---

# A or a click: picks up the focused thing, or puts down what's held.
func pick_or_place() -> void:
	if not is_open: return
	if tab == TAB.CRAFT:
		make()
		return
	if tab == TAB.BUILD:
		assign_build_focused()
		return
	if holding: _place()
	elif not _is_empty(focus_region, focus_index):
		holding = true
		held_region = focus_region
		held_index = focus_index
		message = ""
		_refresh()


# B or a right-click: puts it back where it was.
func cancel() -> void:
	if not holding: return
	holding = false
	_refresh()


func _place() -> void:
	holding = false
	message = ""
	var from: REGION = held_region
	var to: REGION = focus_region
	var hotbar: Hotbar = actor.hotbar
	if to == REGION.LIGHT:
		var light: StringName = id_at(from, held_index)
		if not _is_light(light): message = "Only a torch or a lantern goes in the light slot."
		elif hotbar.assign_light(light):
			message = "The light slot holds the %s." % _item_name(light).to_lower()
	elif from == REGION.BUILD or to == REGION.BUILD:
		if from == to: hotbar.move_build(held_index, focus_index)
		else: message = "Build slots hold only what you can build."
	elif from == REGION.GRID and to == REGION.GRID:
		actor.grid.swap(held_index, focus_index)
	elif from == REGION.TOOLS and to == REGION.TOOLS:
		hotbar.move_tool(held_index, focus_index)
	elif from == REGION.GRID:
		var id: StringName = id_at(REGION.GRID, held_index)
		if not _is_tool(id): message = "Only tools go on the tool bar."
		else: hotbar.place_from_grid(id, focus_index)
	else:
		# A tool off the bar, into the grid at the focused cell
		var id: StringName = id_at(REGION.TOOLS, held_index)
		hotbar.unassign_tool(held_index)
		actor.grid.move_to(id, focus_index)
	_refresh()


# A number key: the focused thing into that slot of its own bar.
func assign_to(slot: int) -> bool:
	if not is_open: return false
	holding = false
	if tab == TAB.BUILD: return _assign_build(slot)
	var done: bool = false
	match focus_region:
		REGION.GRID:
			var id: StringName = id_at(REGION.GRID, focus_index)
			if id == &"": return false
			if not _is_tool(id):
				message = "Only tools go on the tool bar."
				_refresh()
				return false
			done = actor.hotbar.place_from_grid(id, slot)
		REGION.TOOLS: done = actor.hotbar.move_tool(focus_index, slot)
		REGION.BUILD: done = actor.hotbar.move_build(focus_index, slot)
	message = "Put in slot %d." % (slot + 1) if done else ""
	_refresh()
	return done


func sort() -> void:
	if not is_open or tab != TAB.PACK: return
	holding = false
	actor.grid.sort_by_value()
	_focus(REGION.GRID, 0)


static func _is_tool(id: StringName) -> bool:
	var item: Item = ItemRegistry.find(id)
	return item != null and item.is_tool()


static func _is_light(id: StringName) -> bool:
	var item: Item = ItemRegistry.find(id)
	return item != null and Hotbar.LIGHT_TAG in item.tags


# --- the BUILD tab (D-252) ---

func focused_entry() -> int:
	return Hotbar.BUILDABLE[clampi(build_index, 0, Hotbar.BUILDABLE.size() - 1)]


# Confirm or the assign key: the focused buildable into the selected
# build slot, which build mode places from.
func assign_build_focused() -> bool:
	if not is_open or tab != TAB.BUILD: return false
	return _assign_build(actor.hotbar.selected_build)


func _assign_build(slot: int) -> bool:
	var entry: int = focused_entry()
	var done: bool = actor.hotbar.assign_build(entry, slot)
	if done or actor.hotbar.builds[slot] == entry:
		message = "%s is in build slot %d." % [Building.entry_name(entry), slot + 1]
	_refresh()
	return done


# Each cost of `entry` as "Stone  have 3 / need 8", with whether there's
# enough.
func cost_lines(entry: int) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var cost: Dictionary[StringName, int] = Building.cost_of(actor.current_level.world.tuning, entry)
	for id: StringName in cost:
		var have: int = actor.pack.count_of(id)
		lines.append({"text": "%s  have %d / need %d" % [_item_name(id), have, cost[id]],
			"enough": have >= cost[id]})
	return lines


# The assign prompt, in the current scheme's keys only (D-223).
func assign_text() -> String:
	var slot: int = actor.hotbar.selected_build + 1 if actor != null else 1
	return "%s Put in slot %d" % ["[A]" if gamepad else "[Enter]", slot]


# --- dropping: the focused cell, or the focused tool ---

func drop_one() -> void:
	_drop(false)


func drop_stack() -> void:
	_drop(true)


func _drop(whole_stack: bool) -> void:
	# On the BUILD tab the pad's Y (drop one) is the assign key (D-252)
	if is_open and tab == TAB.BUILD and not whole_stack:
		assign_build_focused()
		return
	if not is_open or tab != TAB.PACK or focus_region in [REGION.BUILD, REGION.LIGHT]: return
	var id: StringName = id_at(focus_region, focus_index)
	if id == &"": return
	holding = false
	var count: int = 1
	if whole_stack and focus_region == REGION.GRID: count = actor.grid.count_in_grid(id)
	actor.current_level.world.drop_requested.emit(actor, id, count)


# --- the mouse: hover focuses, a click picks up or puts down, a
# right-click cancels ---

# The region and index under a point on the board, or [-1, -1].
func place_at(point: Vector2) -> Array[int]:
	if light_rect().has_point(point): return [REGION.LIGHT, 0]
	for slot in range(Hotbar.SLOTS):
		if _slot_rect(REGION.BUILD, slot).has_point(point): return [REGION.BUILD, slot]
		if _slot_rect(REGION.TOOLS, slot).has_point(point): return [REGION.TOOLS, slot]
	for row in range(VISIBLE_ROWS):
		for col in range(PackGrid.COLUMNS):
			var cell: int = (scroll + row) * PackGrid.COLUMNS + col
			if cell < actor.grid.cells.size() and _slot_rect(REGION.GRID, cell).has_point(point):
				return [REGION.GRID, cell]
	return [-1, -1]


func _on_board_input(event: InputEvent) -> void:
	if not is_open: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tab_hit: int = tab_at(event.position)
		if tab_hit != -1:
			if tab_hit != tab: switch_tab()
			return
		if tab == TAB.CRAFT:
			_click_craft(event.position)
			return
		if tab == TAB.BUILD:
			_click_build(event.position)
			return
	if tab != TAB.PACK: return
	if event is InputEventMouseMotion:
		var at: Array[int] = place_at(event.position)
		if at[0] != -1 and (at[0] != focus_region or at[1] != focus_index): _focus(at[0], at[1])
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT: cancel()
			MOUSE_BUTTON_WHEEL_UP: move(Vector2i.UP)
			MOUSE_BUTTON_WHEEL_DOWN: move(Vector2i.DOWN)
			MOUSE_BUTTON_LEFT:
				var at: Array[int] = place_at(event.position)
				if at[0] == -1: return
				_focus(at[0], at[1])
				pick_or_place()


# The tab under a point on the board, or -1.
func tab_at(point: Vector2) -> int:
	for t: int in TAB.values():
		if _tab_rect(t).has_point(point): return t
	return -1


func _tab_rect(t: int) -> Rect2:
	return Rect2(Vector2(28 + t * 60, 0), Vector2(56, TABS - 2))


# A click on the CRAFT tab: a row focuses its recipe, Make makes it.
func _click_craft(point: Vector2) -> void:
	if make_rect().has_point(point):
		make()
		return
	for i in range(recipes().size()):
		if _row_rect(i).has_point(point):
			craft_index = i
			_refresh()
			return


# A click on the BUILD tab: a row focuses its buildable, the button
# puts it in the selected build slot.
func _click_build(point: Vector2) -> void:
	if make_rect().has_point(point):
		assign_build_focused()
		return
	for i in range(Hotbar.BUILDABLE.size()):
		if _row_rect(i).has_point(point):
			build_index = i
			_refresh()
			return


# The list's lines, top to bottom: a section's title ({"title"}) or a
# row ({"row": index into the list}). CRAFT has a title per section;
# BUILD one for the whole list.
func _list_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if tab == TAB.BUILD:
		lines.append({"title": "EVERYTHING YOU CAN BUILD"})
		for i in range(Hotbar.BUILDABLE.size()): lines.append({"row": i})
		return lines
	var index: int = 0
	for section: Dictionary in craft_sections():
		lines.append({"title": section.title})
		for _recipe: Recipe in section.recipes:
			lines.append({"row": index})
			index += 1
	return lines


func _line_height(line: Dictionary) -> float:
	return ROW if line.has("row") else TITLE_ROW


# Where the list's rows are drawn: each line in turn from the first
# shown, until the list's foot. A row scrolled out of sight has no
# rect (an empty one).
func _row_rect(index: int) -> Rect2:
	var y: float = LIST_TOP
	var lines: Array[Dictionary] = _list_lines()
	for i in range(list_scroll, lines.size()):
		var height: float = _line_height(lines[i])
		if y + height > LIST_BOTTOM: break
		if lines[i].get("row", -1) == index:
			return Rect2(Vector2(0, y), Vector2(LIST_WIDTH, ROW - 2))
		y += height
	return Rect2()


# Scrolls the list so the focused row is in sight, its section's title
# with it when it's the first.
func _scroll_to_focus() -> void:
	if tab == TAB.PACK or not is_open: return
	var focused: int = craft_index if tab == TAB.CRAFT else build_index
	var lines: Array[Dictionary] = _list_lines()
	var at: int = -1
	for i in range(lines.size()):
		if lines[i].get("row", -1) == focused: at = i
	if at == -1: return
	if at <= list_scroll: list_scroll = maxi(at - 1, 0)
	while list_scroll < at and _row_rect(focused) == Rect2(): list_scroll += 1


func make_rect() -> Rect2:
	return Rect2(Vector2(DETAIL_X, TEXT_TOP - 26), Vector2(110, 16))


# --- words: the preview, the focused thing, the keys ---

# What lies in reach, and the load after taking all of it (ui-ux §5).
func preview_text() -> String:
	if actor == null or actor.current_level == null: return ""
	var world: World = actor.current_level.world
	var lying: Dictionary[StringName, int] = world.drops_in_reach(actor)
	if lying.is_empty(): return "Nothing in reach."
	var parts: PackedStringArray = []
	var kg: float = 0.0
	for id: StringName in lying:
		var item: Item = ItemRegistry.find(id)
		parts.append("%d %s" % [lying[id], item.display_key if item != null else String(id)])
		kg += (item.weight_kg if item != null else 0.0) * lying[id]
	return "In reach: %s (%s kg). Take it all: %s / %s kg" % [", ".join(parts),
		CarryHud._kg(kg), CarryHud._kg(actor.pack.total_weight + kg),
		CarryHud._kg(world.tuning.carry_capacity_kg)]


# The focused thing, in words: its name, count, weight and value per
# kilo, or the buildable and its cost.
func details_text() -> String:
	if not is_open: return ""
	if focus_region == REGION.BUILD:
		var kind: int = kind_at(focus_index)
		if kind == ObjectKind.OBJECT.NULL: return "Build slot %d: empty" % (focus_index + 1)
		return "Build slot %d: %s, %s" % [focus_index + 1, Building.entry_name(kind),
			Building.cost_text(actor.current_level.world.tuning, kind)]
	if focus_region == REGION.LIGHT:
		var light: StringName = actor.hotbar.light
		if light == &"": return "Light slot: empty. Put a torch or a lantern here."
		return "Light slot: %s, %d carried" % [_item_name(light), actor.pack.count_of(light)]
	var id: StringName = id_at(focus_region, focus_index)
	var where: String = "Tool slot %d" % (focus_index + 1) if focus_region == REGION.TOOLS else ""
	if id == &"": return "%s: empty" % where if where != "" else ""
	var item: Item = ItemRegistry.find(id)
	if item == null: return "%s (unknown to this build)" % id
	var count: int = 1 if focus_region == REGION.TOOLS else actor.grid.count_in_grid(id)
	var text: String = "%d %s, %s kg, %s per kg" % [count, item.display_key,
		CarryHud._kg(item.weight_kg * count), "%.2f" % PackGrid.value_density(id)]
	return "%s: %s" % [where, text] if where != "" else text


# The keys, in the current scheme only (D-223).
func help_text() -> String:
	if message != "": return message
	# The tab keys are on the tab strip, so these fit the board's width
	if tab == TAB.CRAFT:
		return "A: make  hold A: keep making" if gamepad \
			else "Enter/click: make  hold: keep making"
	if tab == TAB.BUILD:
		return "A or Y: put in the selected build slot" if gamepad \
			else "Enter/click: put in the selected build slot  1-8: in that slot"
	if holding:
		return "A: put down  B: cancel" if gamepad else "Enter/click: put down  right-click: cancel"
	if gamepad: return "A: pick up  Y: drop 1  X: drop all  R3: sort"
	return "Enter/click: pick up  X: drop 1  Z: drop all  O: sort"


# Everything shown, as text: for tests.
func text() -> String:
	if not is_open: return ""
	if tab == TAB.CRAFT: return craft_text()
	if tab == TAB.BUILD: return build_text()
	var lines: PackedStringArray = [_header_text()]
	for id: StringName in actor.grid.cells:
		if id == &"": continue
		var item: Item = ItemRegistry.find(id)
		var count: int = actor.grid.count_in_grid(id)
		lines.append("%d %s  %s kg" % [count, item.display_key if item != null else String(id),
			CarryHud._kg((item.weight_kg if item != null else 0.0) * count)])
	lines.append(details_text())
	lines.append(preview_text())
	return "\n".join(lines)


# The CRAFT tab, as text: for tests.
func craft_text() -> String:
	var lines: PackedStringArray = []
	for section: Dictionary in craft_sections():
		lines.append(section.title)
		for recipe: Recipe in section.recipes:
			lines.append("%s  %s" % [recipe.display_key, recipe_short(recipe)])
	var recipe: Recipe = focused_recipe()
	if recipe != null:
		lines.append(recipe.display_key)
		for need: Dictionary in needs_lines(recipe): lines.append(need.text)
		lines.append(makes_text(recipe))
		lines.append(make_text())
	lines.append(help_text())
	return "\n".join(lines)


# The BUILD tab, as text: for tests.
func build_text() -> String:
	var tuning: TuningProfile = actor.current_level.world.tuning
	var lines: PackedStringArray = ["EVERYTHING YOU CAN BUILD"]
	for entry: int in Hotbar.BUILDABLE:
		lines.append("%s  %s" % [Building.entry_name(entry), Building.cost_text(tuning, entry)])
	var entry: int = focused_entry()
	lines.append(Building.entry_name(entry))
	lines.append(Building.description(entry))
	for line: Dictionary in cost_lines(entry): lines.append(line.text)
	lines.append(assign_text())
	lines.append(help_text())
	return "\n".join(lines)


func _header_text() -> String:
	return "Pack  %s / %s kg" % [CarryHud._kg(actor.pack.total_weight),
		CarryHud._kg(actor.current_level.world.tuning.carry_capacity_kg)]


func _on_contents_changed(_changed: Variant) -> void:
	if focus_region == REGION.GRID:
		focus_index = clampi(focus_index, 0, actor.grid.cells.size() - 1)
	if holding and _is_empty(held_region, held_index): holding = false
	_refresh()


# The preview follows the player and the ground: redrawn each frame
# while open, which is one small board.
func _process(_delta: float) -> void:
	if is_open: _board.queue_redraw()


func _refresh() -> void:
	_scroll_to_focus()
	_board.queue_redraw()


# --- drawing ---

func _slot_rect(region: REGION, index: int) -> Rect2:
	match region:
		REGION.BUILD:
			return Rect2(Vector2(BUILD_X, HEADER + index * PITCH), Vector2(CELL, CELL))
		REGION.TOOLS:
			return Rect2(Vector2(index * PITCH, TOOLS_Y), Vector2(CELL, CELL))
	var col: int = index % PackGrid.COLUMNS
	var row: int = index / PackGrid.COLUMNS - scroll
	return Rect2(GRID_ORIGIN + Vector2(col * PITCH, row * PITCH), Vector2(CELL, CELL))


func _draw_board() -> void:
	if not is_open: return
	var font: Font = ScaledHud.FONT
	var font_size: int = ScaledHud.FONT_SIZE
	_board.draw_rect(Rect2(Vector2(-4, -4), BOARD_SIZE + Vector2(8, 8)), BACK)
	_draw_tabs()
	if tab == TAB.CRAFT:
		_draw_craft()
		return
	if tab == TAB.BUILD:
		_draw_build()
		return
	# The header: the load, and its bar (D-159's colors)
	var header: String = _header_text()
	_board.draw_string(font, Vector2(0, TABS + font_size), header, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, TEXT_COLOR)
	var bar_x: float = font.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8
	var bar: Rect2 = Rect2(Vector2(bar_x, TABS + 1), Vector2(BUILD_X + CELL - bar_x, 5))
	var ratio: float = actor.load_ratio()
	_board.draw_rect(bar, Color(0, 0, 0, 0.6))
	_board.draw_rect(Rect2(bar.position, Vector2(clampf(ratio / CarryHud.BAR_SPAN, 0.0, 1.0)
		* bar.size.x, bar.size.y)), CarryHud.color_for(ratio))
	var full: float = bar.position.x + bar.size.x / CarryHud.BAR_SPAN
	_board.draw_line(Vector2(full, bar.position.y - 1), Vector2(full, bar.end.y + 1), Color.WHITE)
	# The grid's visible rows
	for row in range(VISIBLE_ROWS):
		for col in range(PackGrid.COLUMNS):
			var cell: int = (scroll + row) * PackGrid.COLUMNS + col
			if cell >= actor.grid.cells.size(): continue
			var id: StringName = actor.grid.cells[cell]
			_draw_item_cell(REGION.GRID, cell, id, actor.grid.count_in_grid(id))
	# The bars
	for slot in range(Hotbar.SLOTS):
		_draw_item_cell(REGION.TOOLS, slot, actor.hotbar.tools[slot], 1)
		_draw_build_cell(slot)
	_draw_light_cell()
	_draw_scroll_marks()
	# Below: the focused thing, the preview (over two lines if it must),
	# the keys
	var y: float = TEXT_TOP + font_size
	var words: Array[String] = [details_text(), preview_text(), help_text()]
	for i in range(words.size()):
		# The preview may take two lines; the others one
		var lines: PackedStringArray = wrap_text(words[i]).slice(0, 2 if i == 1 else 1)
		for line: String in lines:
			_board.draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				DIM_TEXT if i == 2 else TEXT_COLOR)
			y += LINE
		if lines.is_empty(): y += LINE


# The tab strip: the shown tab underlined, the switch key either side
# in the current scheme (D-223).
func _draw_tabs() -> void:
	var font: Font = ScaledHud.FONT
	var font_size: int = ScaledHud.FONT_SIZE
	var left: String = "LB" if gamepad else "Q"
	_board.draw_string(font, Vector2(0, font_size), left, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		DIM_TEXT)
	for t: int in TAB.values():
		var rect: Rect2 = _tab_rect(t)
		var shown: bool = t == tab
		_board.draw_string(font, rect.position + Vector2(4, font_size), TAB_NAMES[t],
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, FOCUS_COLOR if shown else DIM_TEXT)
		if shown:
			_board.draw_line(Vector2(rect.position.x, rect.end.y), rect.end, FOCUS_COLOR, 2.0)
	if gamepad:
		_board.draw_string(font, Vector2(28 + TAB.size() * 60, font_size), "RB",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DIM_TEXT)


# The CRAFT tab (D-222, D-237): the recipes by section, the focused
# one's detail, Make, and the load at the foot. A station's section
# shows only while one is in reach, so a hint below the list says
# where the rest are made.
func _draw_craft() -> void:
	var list: Array[Recipe] = recipes()
	_draw_list(func(i: int, rect: Rect2) -> void:
		_draw_row(rect, _output_icon(list[i]), list[i].display_key, recipe_short(list[i]),
			i == craft_index))
	if craft_sections().size() == 1:
		_board.draw_string(ScaledHud.FONT, Vector2(0, LIST_BOTTOM - 4),
			"More is made at a workbench or forge.", HORIZONTAL_ALIGNMENT_LEFT, -1,
			ScaledHud.FONT_SIZE, DIM_TEXT)
	var recipe: Recipe = focused_recipe()
	if recipe != null: _draw_detail(recipe)
	_draw_foot()


# The BUILD tab (D-252): every buildable, the focused one's detail, and
# the button that puts it in the selected build slot.
func _draw_build() -> void:
	var tuning: TuningProfile = actor.current_level.world.tuning
	_draw_list(func(i: int, rect: Rect2) -> void:
		var entry: int = Hotbar.BUILDABLE[i]
		var slot: int = actor.hotbar.slot_of_build(entry)
		var name: String = Building.entry_name(entry)
		if slot != -1: name = "%s  [%d]" % [name, slot + 1]
		_draw_row(rect, BuildCursor.ghost_texture(entry), name, Building.cost_text(tuning, entry),
			i == build_index))
	var font: Font = ScaledHud.FONT
	var font_size: int = ScaledHud.FONT_SIZE
	var entry: int = focused_entry()
	var x: float = DETAIL_X
	var y: float = LIST_TOP + font_size
	var art: Texture2D = BuildCursor.ghost_texture(entry)
	if art != null:
		var height: float = 32.0
		var width: float = art.get_width() * height / art.get_height()
		_board.draw_texture_rect(art, Rect2(Vector2(x, y - font_size), Vector2(width, height)), false)
	_board.draw_string(font, Vector2(x + 38, y + 4), Building.entry_name(entry),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR)
	y += 36
	for line: String in wrap_to(Building.description(entry), BOARD_SIZE.x - x):
		_board.draw_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DIM_TEXT)
		y += LINE
	y += 6
	_board.draw_string(font, Vector2(x, y), "COSTS", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DIM_TEXT)
	y += LINE
	for line: Dictionary in cost_lines(entry):
		_board.draw_string(font, Vector2(x, y), line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			HAVE_COLOR if line.enough else LACK_COLOR)
		y += LINE
	var button: Rect2 = make_rect()
	_board.draw_rect(button, FOCUS_COLOR)
	_board.draw_string(font, button.position + Vector2(4, font_size + 3), assign_text(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, BACK)
	_draw_foot()


# The list's lines from the first shown: section titles, and each row
# drawn by `draw_row(index, rect)`.
func _draw_list(draw_row: Callable) -> void:
	var font: Font = ScaledHud.FONT
	var font_size: int = ScaledHud.FONT_SIZE
	var y: float = LIST_TOP
	var lines: Array[Dictionary] = _list_lines()
	for i in range(list_scroll, lines.size()):
		var height: float = _line_height(lines[i])
		if y + height > LIST_BOTTOM: break
		if lines[i].has("title"):
			_board.draw_string(font, Vector2(0, y + font_size + 1), lines[i].title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DIM_TEXT)
		else:
			draw_row.call(lines[i].row, Rect2(Vector2(0, y), Vector2(LIST_WIDTH, ROW - 2)))
		y += height
	if list_scroll > 0:
		_board.draw_colored_polygon(PackedVector2Array([Vector2(LIST_WIDTH - 8, LIST_TOP + 3),
			Vector2(LIST_WIDTH - 2, LIST_TOP + 3), Vector2(LIST_WIDTH - 5, LIST_TOP)]), DIM_TEXT)


func _draw_row(rect: Rect2, icon: Texture2D, title: String, line: String, focused: bool) -> void:
	var font: Font = ScaledHud.FONT
	var font_size: int = ScaledHud.FONT_SIZE
	_board.draw_rect(rect, CELL_COLOR)
	if icon != null:
		var height: float = minf(icon.get_height(), 16.0)
		var width: float = icon.get_width() * height / icon.get_height()
		_board.draw_texture_rect(icon, Rect2(rect.position + Vector2(2, 2), Vector2(width, height)), false)
	_board.draw_string(font, rect.position + Vector2(22, font_size + 1), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR)
	_board.draw_string(font, rect.position + Vector2(22, 2 * font_size + 3), line,
		HORIZONTAL_ALIGNMENT_LEFT, LIST_WIDTH - 24, font_size, DIM_TEXT)
	_board.draw_rect(rect, FOCUS_COLOR if focused else BORDER, false, 2.0 if focused else 1.0)


# The load, and the keys or the last word, at the board's foot.
func _draw_foot() -> void:
	var font: Font = ScaledHud.FONT
	var font_size: int = ScaledHud.FONT_SIZE
	_board.draw_string(font, Vector2(0, TEXT_TOP + LINE + font_size), _header_text(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR)
	_board.draw_string(font, Vector2(0, TEXT_TOP + 2 * LINE + font_size), help_text(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DIM_TEXT)


func _draw_detail(recipe: Recipe) -> void:
	var font: Font = ScaledHud.FONT
	var font_size: int = ScaledHud.FONT_SIZE
	var x: float = DETAIL_X
	var y: float = LIST_TOP + font_size
	var icon: Texture2D = _output_icon(recipe)
	if icon != null: _board.draw_texture_rect(icon, Rect2(Vector2(x, y - font_size), Vector2(32, 32)), false)
	_board.draw_string(font, Vector2(x + 38, y + 4), recipe.display_key, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size, TEXT_COLOR)
	y += 36
	for line: String in wrap_to(recipe.description, BOARD_SIZE.x - x):
		_board.draw_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DIM_TEXT)
		y += LINE
	y += 6
	_board.draw_string(font, Vector2(x, y), "NEEDS", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DIM_TEXT)
	y += LINE
	for need: Dictionary in needs_lines(recipe):
		_board.draw_string(font, Vector2(x, y), need.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			HAVE_COLOR if need.enough else LACK_COLOR)
		y += LINE
	y += 6
	_board.draw_string(font, Vector2(x, y), "MAKES", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DIM_TEXT)
	y += LINE
	_board.draw_string(font, Vector2(x, y), makes_text(recipe), HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, TEXT_COLOR)
	var button: Rect2 = make_rect()
	var can: bool = actor.current_level.world.craft_problem(actor, recipe.id) == World.CRAFT_REFUSAL.NONE
	_board.draw_rect(button, FOCUS_COLOR if can else BORDER)
	_board.draw_string(font, button.position + Vector2(4, font_size + 3), make_text(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, BACK)


static func _output_icon(recipe: Recipe) -> Texture2D:
	for id: StringName in recipe.outputs:
		var item: Item = ItemRegistry.find(id)
		if item != null and item.icon != null: return item.icon
	return null


# As wrap_text, to a given width.
static func wrap_to(text: String, width: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	var line: String = ""
	for word: String in text.split(" "):
		var longer: String = word if line == "" else line + " " + word
		if line != "" and _width(longer) > width:
			lines.append(line)
			line = word
		else:
			line = longer
	if line != "": lines.append(line)
	return lines


# A text broken between words into lines no wider than the board's
# text width.
static func wrap_text(text: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var line: String = ""
	# Empty words keep a double space between key groups
	for word: String in text.split(" "):
		var longer: String = word if line == "" else line + " " + word
		if line != "" and _width(longer) > TEXT_WIDTH:
			lines.append(line)
			line = word
		else:
			line = longer
	if line != "": lines.append(line)
	return lines


static func _width(text: String) -> float:
	return ScaledHud.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		ScaledHud.FONT_SIZE).x


# Rows above or below the shown six: a small arrow at the grid's
# right edge, top or bottom.
func _draw_scroll_marks() -> void:
	var rows_total: int = ceili(float(actor.grid.cells.size()) / PackGrid.COLUMNS)
	var x: float = PackGrid.COLUMNS * PITCH - PITCH / 2.0
	if scroll > 0:
		var top: float = HEADER - 2
		_board.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, top), Vector2(x + 3, top),
			Vector2(x, top - 3)]), DIM_TEXT)
	if scroll + VISIBLE_ROWS < rows_total:
		var bottom: float = HEADER + VISIBLE_ROWS * PITCH
		_board.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, bottom - 1),
			Vector2(x + 3, bottom - 1), Vector2(x, bottom + 2)]), DIM_TEXT)


func _draw_item_cell(region: REGION, index: int, id: StringName, count: int) -> void:
	var rect: Rect2 = _slot_rect(region, index)
	_board.draw_rect(rect, CELL_COLOR if region == REGION.GRID else SLOT_COLOR)
	if id != &"":
		var item: Item = ItemRegistry.find(id)
		# The icon between the number on top and the weight under it
		if item != null and item.icon != null:
			_board.draw_texture(item.icon, rect.position + Vector2((CELL - 16) / 2, 8))
		if region == REGION.GRID:
			# Every cell shows its count and weight (ui-ux §5): the count
			# bright at the bottom-right, where a player looks for it, the
			# weight dim at the top-right with its unit (D-230)
			var font: Font = ScaledHud.FONT
			var font_size: int = ScaledHud.FONT_SIZE
			var kg: float = (item.weight_kg if item != null else 0.0) * count
			_board.draw_string(font, rect.position + Vector2(0, 1 + font_size), cell_weight(kg),
				HORIZONTAL_ALIGNMENT_RIGHT, CELL - 1, font_size, DIM_TEXT)
			_board.draw_string(font, rect.position + Vector2(0, CELL), str(count),
				HORIZONTAL_ALIGNMENT_RIGHT, CELL - 1, font_size, TEXT_COLOR)
	if region == REGION.TOOLS:
		_draw_slot_number(rect, index)
		if index == actor.hotbar.selected_tool:
			_board.draw_rect(rect.grow(-1), SELECTED_COLOR, false, 1.0)
	_draw_marks(rect, region, index)


func _draw_build_cell(slot: int) -> void:
	var rect: Rect2 = _slot_rect(REGION.BUILD, slot)
	_board.draw_rect(rect, SLOT_COLOR)
	var texture: Texture2D = FixtureRenderer.TEXTURES.get(Building.kind_of(kind_at(slot)))
	if texture != null:
		# Under the slot number, fitted to the room left
		var height: float = minf(texture.get_height(), CELL - 10)
		var width: float = texture.get_width() * height / texture.get_height()
		_board.draw_texture_rect(texture, Rect2(rect.position + Vector2(roundf((CELL - width) / 2),
			9), Vector2(width, height)), false)
	_draw_slot_number(rect, slot)
	if slot == actor.hotbar.selected_build:
		_board.draw_rect(rect.grow(-1), SELECTED_COLOR, false, 1.0)
	_draw_marks(rect, REGION.BUILD, slot)


# The light slot (D-228), past the build column at the tool row's
# height: the light's icon and how many, ringed in flame while lit.
func _draw_light_cell() -> void:
	var rect: Rect2 = light_rect()
	_board.draw_rect(rect, SLOT_COLOR)
	var id: StringName = actor.hotbar.light
	var item: Item = ItemRegistry.find(id)
	if item != null and item.icon != null:
		_board.draw_texture(item.icon, rect.position + Vector2((CELL - 16) / 2, 8))
		_board.draw_string(ScaledHud.FONT, rect.position + Vector2(0, CELL), str(actor.pack.count_of(id)),
			HORIZONTAL_ALIGNMENT_RIGHT, CELL - 1, ScaledHud.FONT_SIZE, TEXT_COLOR)
	_board.draw_string(ScaledHud.FONT, rect.position + Vector2(1, 1 + ScaledHud.FONT_SIZE),
		"L" if not gamepad else "^", HORIZONTAL_ALIGNMENT_LEFT, -1, ScaledHud.FONT_SIZE, BORDER)
	_board.draw_rect(rect, HotbarHud.LIT if actor.hotbar.lit else BORDER, false,
		2.0 if actor.hotbar.lit else 1.0)
	if holding and focus_region == REGION.LIGHT:
		_board.draw_rect(rect.grow(1), HELD_COLOR, false, 2.0)
	elif focus_region == REGION.LIGHT:
		_board.draw_rect(rect.grow(1), FOCUS_COLOR, false, 2.0)


func light_rect() -> Rect2:
	return Rect2(Vector2(BUILD_X + PITCH + BAR_GAP, TOOLS_Y), Vector2(CELL, CELL))


func _draw_slot_number(rect: Rect2, index: int) -> void:
	_board.draw_string(ScaledHud.FONT, rect.position + Vector2(1, 1 + ScaledHud.FONT_SIZE),
		str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, ScaledHud.FONT_SIZE, BORDER)


# A cell's weight, with its unit (D-230): as the pack says it, but
# whole kilos from ten up, so four characters always fit the cell's
# width.
static func cell_weight(kg: float) -> String:
	return (str(roundi(kg)) if kg >= 10.0 else CarryHud._kg(kg)) + "k"


# The border, the focus, and what's held, by shape as well as color:
# the focus is a thick outer frame, what's held a frame inside.
func _draw_marks(rect: Rect2, region: REGION, index: int) -> void:
	_board.draw_rect(rect, BORDER, false, 1.0)
	if holding and region == held_region and index == held_index:
		_board.draw_rect(rect.grow(-3), HELD_COLOR, false, 1.0)
	if region == focus_region and index == focus_index:
		_board.draw_rect(rect.grow(1), HELD_COLOR if holding else FOCUS_COLOR, false, 2.0)
