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

# Opened or closed: the hotbar on screen hides while this shows its
# own bars.
signal open_changed(open: bool)

enum REGION {
	GRID,
	BUILD,
	TOOLS,
}

const CELL: int = 24
const PITCH: int = 26
const BAR_GAP: int = 6
const HEADER: int = 16
const VISIBLE_ROWS: int = 8
const GRID_ORIGIN: Vector2 = Vector2(0, HEADER)
const BUILD_X: float = PackGrid.COLUMNS * PITCH + BAR_GAP
const TOOLS_Y: float = HEADER + VISIBLE_ROWS * PITCH + BAR_GAP
const BOARD_SIZE: Vector2 = Vector2(BUILD_X + CELL, TOOLS_Y + CELL + 40)

const BACK: Color = Color(0.08, 0.07, 0.07, 0.92)
const CELL_COLOR: Color = Color(0.2, 0.19, 0.18)
const SLOT_COLOR: Color = Color(0.16, 0.18, 0.2)
const BORDER: Color = Color(0.45, 0.43, 0.4)
const FOCUS_COLOR: Color = Color(1.0, 0.9, 0.45)
const HELD_COLOR: Color = Color(0.45, 0.85, 1.0)
const SELECTED_COLOR: Color = Color(0.85, 0.85, 0.8)
const TEXT_COLOR: Color = Color(0.9, 0.9, 0.85)
const DIM_TEXT: Color = Color(0.7, 0.7, 0.65)

var is_open: bool = false
var actor: Actor
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
		for source: Variant in [actor.pack, actor.hotbar, actor.grid]:
			if not source.changed.is_connected(_on_contents_changed):
				source.changed.connect(_on_contents_changed)
		focus_region = REGION.GRID
		focus_index = 0
		scroll = 0
		message = ""
	if is_open != was: open_changed.emit(is_open)
	_refresh()


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
	return &""


func kind_at(slot: int) -> int:
	return actor.hotbar.builds[slot]


func _is_empty(region: REGION, index: int) -> bool:
	if region == REGION.BUILD: return kind_at(index) == ObjectKind.OBJECT.NULL
	return id_at(region, index) == &""


# --- moving the focus (the D-pad, the arrows) ---

# One step. The grid's right edge leads to the build column, its
# bottom to the tool row; the two bars meet at their last slots.
func move(direction: Vector2i) -> void:
	if not is_open or direction == Vector2i.ZERO: return
	var rows_total: int = actor.grid.cells.size() / PackGrid.COLUMNS
	match focus_region:
		REGION.GRID:
			var col: int = focus_index % PackGrid.COLUMNS
			var row: int = focus_index / PackGrid.COLUMNS
			if direction.x > 0 and col == PackGrid.COLUMNS - 1:
				_focus(REGION.BUILD, clampi(row - scroll, 0, Hotbar.SLOTS - 1))
			elif direction.y > 0 and row == rows_total - 1:
				_focus(REGION.TOOLS, col)
			else:
				col = clampi(col + direction.x, 0, PackGrid.COLUMNS - 1)
				row = clampi(row + direction.y, 0, rows_total - 1)
				_focus(REGION.GRID, row * PackGrid.COLUMNS + col)
		REGION.BUILD:
			if direction.x < 0:
				_focus(REGION.GRID, (scroll + focus_index) * PackGrid.COLUMNS + PackGrid.COLUMNS - 1)
			elif direction.y > 0 and focus_index == Hotbar.SLOTS - 1:
				_focus(REGION.TOOLS, Hotbar.SLOTS - 1)
			else:
				_focus(REGION.BUILD, clampi(focus_index + direction.y, 0, Hotbar.SLOTS - 1))
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
	if from == REGION.BUILD or to == REGION.BUILD:
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
	if not is_open: return
	holding = false
	actor.grid.sort_by_value()
	_focus(REGION.GRID, 0)


static func _is_tool(id: StringName) -> bool:
	var item: Item = ItemRegistry.find(id)
	return item != null and item.is_tool()


# --- dropping: the focused cell, or the focused tool ---

func drop_one() -> void:
	_drop(false)


func drop_stack() -> void:
	_drop(true)


func _drop(whole_stack: bool) -> void:
	if not is_open or focus_region == REGION.BUILD: return
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
		return "Build slot %d: %s, %s" % [focus_index + 1, ObjectKind.display_name(kind),
			Building.cost_text(actor.current_level.world.tuning, kind)]
	var id: StringName = id_at(focus_region, focus_index)
	var where: String = "Tool slot %d" % (focus_index + 1) if focus_region == REGION.TOOLS else ""
	if id == &"": return "%s: empty" % where if where != "" else ""
	var item: Item = ItemRegistry.find(id)
	if item == null: return "%s (unknown to this build)" % id
	var count: int = 1 if focus_region == REGION.TOOLS else actor.grid.count_in_grid(id)
	var text: String = "%d %s, %s kg, %s per kg" % [count, item.display_key,
		CarryHud._kg(item.weight_kg * count), "%.2f" % PackGrid.value_density(id)]
	return "%s: %s" % [where, text] if where != "" else text


func help_text() -> String:
	if holding: return "A / click: put down    B / right-click: cancel"
	if message != "": return message
	return "A/click: pick up   Y/X: drop 1   X/Z: drop all   R3/O: sort"


# Everything shown, as text: for tests.
func text() -> String:
	if not is_open: return ""
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
	var font: Font = ThemeDB.fallback_font
	_board.draw_rect(Rect2(Vector2(-4, -4), BOARD_SIZE + Vector2(8, 8)), BACK)
	# The header: the load, and its bar (D-159's colors)
	_board.draw_string(font, Vector2(0, 8), _header_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		TEXT_COLOR)
	var bar: Rect2 = Rect2(Vector2(110, 3), Vector2(BUILD_X + CELL - 110, 5))
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
	# Below: the focused thing, the preview, the keys
	var y: float = TOOLS_Y + CELL + 10
	var help: String = help_text()
	for line: String in [details_text(), preview_text(), help]:
		_board.draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, BOARD_SIZE.x,
			6 if line == help else 8, DIM_TEXT if line == help else TEXT_COLOR)
		y += 11


func _draw_item_cell(region: REGION, index: int, id: StringName, count: int) -> void:
	var rect: Rect2 = _slot_rect(region, index)
	_board.draw_rect(rect, CELL_COLOR if region == REGION.GRID else SLOT_COLOR)
	if id != &"":
		var item: Item = ItemRegistry.find(id)
		if item != null and item.icon != null:
			_board.draw_texture(item.icon, rect.position + Vector2(4, 1))
		if region == REGION.GRID:
			# Every cell shows its count and weight (ui-ux §5)
			var font: Font = ThemeDB.fallback_font
			_board.draw_string(font, rect.position + Vector2(1, 6), str(count),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 6, TEXT_COLOR)
			var kg: float = (item.weight_kg if item != null else 0.0) * count
			_board.draw_string(font, rect.position + Vector2(0, CELL - 1), CarryHud._kg(kg) + "kg",
				HORIZONTAL_ALIGNMENT_RIGHT, CELL - 1, 6, TEXT_COLOR)
	if region == REGION.TOOLS:
		_draw_slot_number(rect, index)
		if index == actor.hotbar.selected_tool:
			_board.draw_rect(rect.grow(-1), SELECTED_COLOR, false, 1.0)
	_draw_marks(rect, region, index)


func _draw_build_cell(slot: int) -> void:
	var rect: Rect2 = _slot_rect(REGION.BUILD, slot)
	_board.draw_rect(rect, SLOT_COLOR)
	var texture: Texture2D = FixtureRenderer.TEXTURES.get(kind_at(slot))
	if texture != null:
		var height: float = CELL - 4
		var width: float = texture.get_width() * height / texture.get_height()
		_board.draw_texture_rect(texture, Rect2(rect.position + Vector2((CELL - width) / 2, 2),
			Vector2(width, height)), false)
	_draw_slot_number(rect, slot)
	if slot == actor.hotbar.selected_build:
		_board.draw_rect(rect.grow(-1), SELECTED_COLOR, false, 1.0)
	_draw_marks(rect, REGION.BUILD, slot)


func _draw_slot_number(rect: Rect2, index: int) -> void:
	_board.draw_string(ThemeDB.fallback_font, rect.position + Vector2(1, 6), str(index + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 6, BORDER)


# The border, the focus, and what's held, by shape as well as color:
# the focus is a thick outer frame, what's held a frame inside.
func _draw_marks(rect: Rect2, region: REGION, index: int) -> void:
	_board.draw_rect(rect, BORDER, false, 1.0)
	if holding and region == held_region and index == held_index:
		_board.draw_rect(rect.grow(-3), HELD_COLOR, false, 1.0)
	if region == focus_region and index == focus_index:
		_board.draw_rect(rect.grow(1), HELD_COLOR if holding else FOCUS_COLOR, false, 2.0)
