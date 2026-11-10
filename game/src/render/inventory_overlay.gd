class_name InventoryOverlay
extends CanvasLayer

# What the local player carries, what to leave behind, and what goes
# in the hotbar (ui-ux §5, D-162, D-172). Two sections: the pack, each
# item with its weight, sorted by value density (trade value per kilo,
# best first); and what can be built. One entry has the focus, moved
# by the D-pad, the arrow keys or the mouse alike. A weight bar heads
# the screen, and a preview says what the load would be after taking
# everything in reach.
#
# Assigning puts the focused entry in a hotbar slot: a number key or a
# click on the slot does it at once; on the pad, Y begins choosing,
# LB / RB move along the slots, A confirms and B cancels. Dropping and
# assigning are requests on the player's world and hotbar; this only
# shows and asks. An overlay: the game keeps running. Presentation,
# for the local player (D-045).

# The slot being chosen to assign to, -1 when not choosing: the
# hotbar on screen marks it.
signal assign_slot_changed(slot: int)
# Which section is shown, so the hotbar on screen can show the slots
# that section assigns to.
signal section_changed(section: SECTION)

enum SECTION {
	PACK,
	BUILD,
}

const BAR_SIZE: Vector2 = Vector2(160, 6)
const FOCUS_COLOR: Color = Color(1.0, 0.9, 0.45)
const ROW_COLOR: Color = Color(0.85, 0.85, 0.8)

var is_open: bool = false
var actor: Actor
var section: SECTION = SECTION.PACK
# The focused row in the shown section
var focus: int = 0
# Whether a slot is being chosen for the focused entry (pad Y)
var assigning: bool = false
var assign_slot: int = -1
# The last thing said: a refusal, or what an assignment did
var message: String = ""

var _panel: PanelContainer
var _header: Label
var _bar: Control
var _rows_box: VBoxContainer
var _preview: Label
var _help: Label
var _row_labels: Array[Label] = []


func _init() -> void:
	name = "InventoryOverlay"
	layer = 85
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	add_child(_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	_header = Label.new()
	box.add_child(_header)
	_bar = Control.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 0)
	box.add_child(_rows_box)
	_preview = Label.new()
	box.add_child(_preview)
	_help = Label.new()
	_help.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_help)


func toggle() -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	is_open = value and actor != null
	_panel.visible = is_open
	_end_assign()
	if is_open:
		if not actor.pack.changed.is_connected(_on_contents_changed):
			actor.pack.changed.connect(_on_contents_changed)
		if not actor.hotbar.changed.is_connected(_on_contents_changed):
			actor.hotbar.changed.connect(_on_contents_changed)
		focus = 0
		message = ""
	section_changed.emit(section if is_open else SECTION.PACK)
	_refresh()


# --- the entries ---

# The pack's item ids, best value per kilo first; ids this build
# doesn't know, last.
func rows() -> Array[StringName]:
	var ids: Array[StringName] = []
	if actor == null: return ids
	ids.assign(actor.pack.to_save().keys().map(func(k: String) -> StringName: return StringName(k)))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return value_density(a) > value_density(b))
	return ids


# What the build section lists: every buildable kind.
func build_rows() -> Array[int]:
	return Hotbar.BUILDABLE.duplicate()


func row_count() -> int:
	return rows().size() if section == SECTION.PACK else build_rows().size()


static func value_density(id: StringName) -> float:
	var item: Item = ItemRegistry.find(id)
	if item == null or item.weight_kg <= 0.0: return -1.0
	return item.trade_value / item.weight_kg


# --- focus (the D-pad, the arrows, the mouse) ---

func move_focus(step: int) -> void:
	var count: int = row_count()
	if count == 0: return
	focus = posmod(focus + step, count)
	_refresh()


func focus_row(row: int) -> void:
	if row < 0 or row >= row_count() or row == focus: return
	focus = row
	_refresh()


func switch_section(step: int) -> void:
	if not is_open: return
	_end_assign()
	section = SECTION.values()[posmod(section + step, SECTION.size())]
	focus = 0
	message = ""
	section_changed.emit(section)
	_refresh()


# --- dropping (the pack only) ---

func drop_one() -> void:
	_drop(1)


func drop_stack() -> void:
	var ids: Array[StringName] = rows()
	if section != SECTION.PACK or ids.is_empty() or focus >= ids.size(): return
	_drop(actor.pack.count_of(ids[focus]))


func _drop(count: int) -> void:
	var ids: Array[StringName] = rows()
	if not is_open or section != SECTION.PACK or ids.is_empty() or focus >= ids.size(): return
	actor.current_level.world.drop_requested.emit(actor, ids[focus], count)


# --- assigning (D-172, D-174) ---

# Puts the focused entry in `slot`, at once: a number key, or a click
# on the slot. Only tools go in tool slots; only buildables in build
# slots.
func assign_to(slot: int) -> bool:
	if not is_open: return false
	_end_assign()
	var done: bool = false
	if section == SECTION.PACK:
		var ids: Array[StringName] = rows()
		if focus >= ids.size(): return false
		var item: Item = ItemRegistry.find(ids[focus])
		if item == null or not item.is_tool():
			message = "Only tools go on the hotbar."
			_refresh()
			return false
		done = actor.hotbar.assign_tool(ids[focus], slot)
	else:
		var kinds: Array[int] = build_rows()
		if focus >= kinds.size(): return false
		done = actor.hotbar.assign_build(kinds[focus], slot)
	message = "Put in slot %d." % (slot + 1) if done else ""
	_refresh()
	return done


# Pad Y: begins choosing a slot for the focused entry, starting at
# the slot it's already in, else the selected one.
func begin_assign() -> void:
	if not is_open or row_count() == 0: return
	if section == SECTION.PACK:
		var item: Item = ItemRegistry.find(rows()[focus])
		if item == null or not item.is_tool():
			message = "Only tools go on the hotbar."
			_refresh()
			return
		var at: int = actor.hotbar.slot_of_tool(rows()[focus])
		assign_slot = at if at != -1 else actor.hotbar.selected_tool
	else:
		var at: int = actor.hotbar.slot_of_build(build_rows()[focus])
		assign_slot = at if at != -1 else actor.hotbar.selected_build
	assigning = true
	message = ""
	assign_slot_changed.emit(assign_slot)
	_refresh()


func step_assign(step: int) -> void:
	if not assigning: return
	assign_slot = posmod(assign_slot + step, Hotbar.SLOTS)
	assign_slot_changed.emit(assign_slot)
	_refresh()


func confirm_assign() -> void:
	if not assigning: return
	assign_to(assign_slot)


func cancel_assign() -> void:
	_end_assign()
	_refresh()


func _end_assign() -> void:
	if not assigning and assign_slot == -1: return
	assigning = false
	assign_slot = -1
	assign_slot_changed.emit(-1)


# --- the take-this preview (ui-ux §5) ---

# What lies in reach, and the load after taking all of it. "" with
# nothing in reach.
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


# The shown rows as text, for the screen and for tests.
func text() -> String:
	var lines: PackedStringArray = [_header.text]
	for label: Label in _row_labels: lines.append(label.text)
	lines.append(_preview.text)
	return "\n".join(lines)


func _on_contents_changed(_changed: Variant) -> void:
	focus = clampi(focus, 0, maxi(row_count() - 1, 0))
	_refresh()


# The preview follows the player and the ground, cheaply: rebuilt
# only when its text changes.
func _process(_delta: float) -> void:
	if not is_open: return
	var preview: String = preview_text()
	if preview != _preview.text: _preview.text = preview


# --- the mouse: hover moves the focus, a click too ---

func _on_row_input(event: InputEvent, row: int) -> void:
	if event is InputEventMouseMotion: focus_row(row)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		focus_row(row)


# --- drawing ---

func _refresh() -> void:
	if not is_open:
		_header.text = ""
		_preview.text = ""
		_help.text = ""
		_set_rows([])
		return
	var pack_tab: String = "[Pack]" if section == SECTION.PACK else " Pack "
	var build_tab: String = "[Build]" if section == SECTION.BUILD else " Build "
	_header.text = "%s %s    %s / %s kg" % [pack_tab, build_tab, CarryHud._kg(actor.pack.total_weight),
		CarryHud._kg(actor.current_level.world.tuning.carry_capacity_kg)]
	_bar.queue_redraw()
	_set_rows(_pack_lines() if section == SECTION.PACK else _build_lines())
	_preview.text = preview_text()
	_help.text = _help_line()


func _pack_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var ids: Array[StringName] = rows()
	if ids.is_empty(): lines.append("  empty")
	for i in range(ids.size()):
		var id: StringName = ids[i]
		var item: Item = ItemRegistry.find(id)
		var name: String = item.display_key if item != null else String(id)
		var weight: float = item.weight_kg * actor.pack.count_of(id) if item != null else 0.0
		var slot: int = actor.hotbar.slot_of_tool(id)
		lines.append("%s %d %s  %s kg%s" % [">" if i == focus else " ", actor.pack.count_of(id),
			name, CarryHud._kg(weight), "  [%d]" % (slot + 1) if slot != -1 else ""])
	return lines


func _build_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var kinds: Array[int] = build_rows()
	var tuning: TuningProfile = actor.current_level.world.tuning
	for i in range(kinds.size()):
		var slot: int = actor.hotbar.slot_of_build(kinds[i])
		lines.append("%s %s  %s%s" % [">" if i == focus else " ", ObjectKind.display_name(kinds[i]),
			Building.cost_text(tuning, kinds[i]), "  [%d]" % (slot + 1) if slot != -1 else ""])
	return lines


func _help_line() -> String:
	if assigning: return "Slot %d: LB / RB choose, A put here, B cancel" % (assign_slot + 1)
	if message != "": return message
	if section == SECTION.PACK:
		return "X drop one, Z drop all, 1-8 or Y to assign, arrows switch, Tab close"
	return "1-8 or Y to assign, arrows switch, Tab close"


# One label per row, made or freed to match, each taking the mouse.
func _set_rows(lines: PackedStringArray) -> void:
	while _row_labels.size() < lines.size():
		var label: Label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(_on_row_input.bind(_row_labels.size()))
		_rows_box.add_child(label)
		_row_labels.append(label)
	while _row_labels.size() > lines.size():
		var label: Label = _row_labels.pop_back()
		label.queue_free()
	for i in range(lines.size()):
		_row_labels[i].text = lines[i]
		_row_labels[i].modulate = FOCUS_COLOR if lines[i].begins_with(">") else ROW_COLOR


func _draw_bar() -> void:
	if actor == null: return
	var size: Vector2 = _bar.size
	var ratio: float = actor.load_ratio()
	_bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var filled: float = clampf(ratio / CarryHud.BAR_SPAN, 0.0, 1.0) * size.x
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(filled, size.y)), CarryHud.color_for(ratio))
	var full: float = size.x / CarryHud.BAR_SPAN
	_bar.draw_line(Vector2(full, -2), Vector2(full, size.y + 2), Color.WHITE)
