class_name HotbarHud
extends ScaledHud

# The followed actor's hotbar (D-170, ui-ux §4): eight slots at the
# bottom center, under the carry bar. Outside build mode it shows the
# tool slots; in build mode, the build slots. The selected slot is
# outlined, an empty one is dim, and while the inventory is choosing a
# slot to assign to (D-172) that slot is marked too. Presentation: it
# follows the view's actor (D-045). A click on a slot is announced,
# not acted on: the input handler decides what a click means.

signal slot_clicked(slot: int)

const SLOT_SIZE: Vector2 = Vector2(30, 20)
const GAP: int = 2
const EMPTY: Color = Color(0, 0, 0, 0.45)
const FILLED: Color = Color(0, 0, 0, 0.7)
const BORDER: Color = Color(0.6, 0.6, 0.55)
const SELECTED: Color = Color(1.0, 0.9, 0.45)
const ASSIGNING: Color = Color(0.45, 0.85, 1.0)

# Short names for the slots, which are too narrow for a display name.
# Anything not listed shows the last word of its name.
const SHORT_NAMES: Dictionary = {
	&"flint_pickaxe": "Pick",
	&"flint_shovel": "Shovel",
}
const BUILD_NAMES: Dictionary = {
	ObjectKind.OBJECT.LADDER: "Ladder",
	ObjectKind.OBJECT.TIMBER_PROP: "Prop",
}

# Whether the build slots are shown: build mode is on (D-170), or the
# inventory's build section is open (D-174)
var showing_builds: bool:
	get: return _build_mode or _inventory_builds
# The slot the inventory is choosing to assign to, or -1 (D-172)
var assign_slot: int = -1:
	set(value):
		assign_slot = value
		_redraw()

var _view: View
var _actor: Actor
var _build_mode: bool = false
var _inventory_builds: bool = false
var _row: HBoxContainer
var _slots: Array[Control] = []


func _init() -> void:
	super()
	name = "HotbarHud"
	layer = 80
	_row = HBoxContainer.new()
	_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_row.offset_bottom = -6
	_row.add_theme_constant_override("separation", GAP)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_row)
	for i in range(Hotbar.SLOTS):
		var slot: Control = Control.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.draw.connect(_draw_slot.bind(i))
		_row.add_child(slot)
		_slots.append(slot)


func watch(view: View) -> void:
	_view = view
	view.followed_moved.connect(_on_followed_moved)
	if view.actor != null: _on_followed_moved(view.actor)


# The tool slots in build mode's absence, the build slots in its
# presence.
func watch_cursor(cursor: BuildCursor) -> void:
	cursor.active_changed.connect(_on_build_mode_changed)


func _on_followed_moved(actor: Actor) -> void:
	if actor == _actor: return
	if is_instance_valid(_actor) and _actor.hotbar.changed.is_connected(_on_hotbar_changed):
		_actor.hotbar.changed.disconnect(_on_hotbar_changed)
	_actor = actor
	_actor.hotbar.changed.connect(_on_hotbar_changed)
	_redraw()


# The inventory's section picks the slots shown, and the slot it's
# choosing is marked.
func watch_inventory(inventory: InventoryOverlay) -> void:
	inventory.section_changed.connect(_on_inventory_section_changed)
	inventory.assign_slot_changed.connect(func(slot: int) -> void: assign_slot = slot)


func _on_build_mode_changed(active: bool) -> void:
	_build_mode = active
	_redraw()


func _on_inventory_section_changed(section: InventoryOverlay.SECTION) -> void:
	_inventory_builds = section == InventoryOverlay.SECTION.BUILD
	_redraw()


func _on_hotbar_changed(_hotbar: Hotbar) -> void:
	_redraw()


# --- what each slot shows ---

func selected() -> int:
	if _actor == null: return -1
	return _actor.hotbar.selected_build if showing_builds else _actor.hotbar.selected_tool


# A slot's short name, "" when it's empty.
func slot_text(slot: int) -> String:
	if _actor == null: return ""
	if showing_builds:
		var kind: int = _actor.hotbar.builds[slot]
		return BUILD_NAMES.get(kind, "")
	var id: StringName = _actor.hotbar.tools[slot]
	if id == &"": return ""
	if SHORT_NAMES.has(id): return SHORT_NAMES[id]
	var item: Item = ItemRegistry.find(id)
	return item.display_key.get_slice(" ", item.display_key.get_slice_count(" ") - 1) \
		if item != null else String(id)


# --- the mouse (ui-ux §3: a click on a slot selects it) ---

# The slot under a point on the screen, or -1.
func slot_at(point: Vector2) -> int:
	# In the frame's own coordinates: the slots sit in the row, the
	# row in the frame, so no layer transform enters into it
	var at: Vector2 = to_design(point)
	for i in range(_slots.size()):
		if Rect2(_row.position + _slots[i].position, _slots[i].size).has_point(at): return i
	return -1


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton: return
	var button: InputEventMouseButton = event
	if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed: return
	var slot: int = slot_at(button.position)
	if slot != -1: slot_clicked.emit(slot)


# --- drawing ---

func _redraw() -> void:
	for slot: Control in _slots: slot.queue_redraw()


func _draw_slot(i: int) -> void:
	var slot: Control = _slots[i]
	var rect: Rect2 = Rect2(Vector2.ZERO, slot.size)
	var text: String = slot_text(i)
	slot.draw_rect(rect, FILLED if text != "" else EMPTY)
	var border: Color = BORDER
	var width: float = 1.0
	if i == selected():
		border = SELECTED
		width = 2.0
	if i == assign_slot:
		border = ASSIGNING
		width = 2.0
	slot.draw_rect(rect, border, false, width)
	var font: Font = ThemeDB.fallback_font
	slot.draw_string(font, Vector2(2, 7), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, BORDER)
	if text != "":
		slot.draw_string(font, Vector2(0, slot.size.y - 3), text, HORIZONTAL_ALIGNMENT_CENTER,
			slot.size.x, 8, Color.WHITE)
