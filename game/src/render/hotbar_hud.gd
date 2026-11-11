class_name HotbarHud
extends ScaledHud

# The followed actor's hotbar (D-170, ui-ux §4): eight slots at the
# bottom center, under the carry bar. Outside build mode it shows the
# tool slots; in build mode, the build slots. Each shows its icon (the
# item's, or the fixture's art), the selected one is outlined, an empty
# one is dim. It hides while the inventory is open, which shows the
# bars itself (D-175). Presentation: it follows the view's actor
# (D-045). A click on a slot is announced, not acted on: the input
# handler decides what a click means.

signal slot_clicked(slot: int)

# As the inventory's cells: the number on top, the icon under it
# (D-190)
const SLOT_SIZE: Vector2 = Vector2(32, 32)
const GAP: int = 2
const EMPTY: Color = Color(0, 0, 0, 0.45)
const FILLED: Color = Color(0, 0, 0, 0.7)
const BORDER: Color = Color(0.6, 0.6, 0.55)
const SELECTED: Color = Color(1.0, 0.9, 0.45)
# The light slot's ring while it burns, and its burn bar (D-221)
const LIT: Color = Color(1.0, 0.6, 0.18)

# Short names for the slots, which are too narrow for a display name.
# Anything not listed shows the last word of its name.
const SHORT_NAMES: Dictionary = {
	&"flint_axe": "Axe",
	&"flint_pickaxe": "Pick",
	&"flint_shovel": "Shovel",
}
const BUILD_NAMES: Dictionary = {
	ObjectKind.OBJECT.LADDER: "Ladder",
	ObjectKind.OBJECT.TIMBER_PROP: "Prop",
}

# Whether the build slots are shown: build mode is on (D-170)
var showing_builds: bool:
	get: return _build_mode

var _view: View
var _actor: Actor
var _build_mode: bool = false
var _row: HBoxContainer
var _slots: Array[Control] = []
var _light_slot: Control


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
	# The light slot at the bar's end (D-228), a gap apart from the
	# eight it doesn't share a number with
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(4, 0)
	_row.add_child(spacer)
	_light_slot = Control.new()
	_light_slot.custom_minimum_size = SLOT_SIZE
	_light_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_slot.draw.connect(_draw_light_slot)
	_row.add_child(_light_slot)


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
	if is_instance_valid(_actor) and _actor.pack.changed.is_connected(_on_pack_changed):
		_actor.pack.changed.disconnect(_on_pack_changed)
	_actor = actor
	_actor.hotbar.changed.connect(_on_hotbar_changed)
	# The light slot shows how many are carried
	_actor.pack.changed.connect(_on_pack_changed)
	_redraw()


func _on_pack_changed(_pack: Pack) -> void:
	if _light_slot != null: _light_slot.queue_redraw()


func _on_build_mode_changed(active: bool) -> void:
	_build_mode = active
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


# A slot's picture: the item's icon, or the buildable's art; null for
# an empty slot or a thing with none.
func slot_icon(slot: int) -> Texture2D:
	if _actor == null: return null
	if showing_builds: return FixtureRenderer.TEXTURES.get(_actor.hotbar.builds[slot])
	var item: Item = ItemRegistry.find(_actor.hotbar.tools[slot])
	return item.icon if item != null else null


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
	if _light_slot != null: _light_slot.queue_redraw()


# A lit light burns down every frame, so its bar is redrawn while lit.
func _process(_delta: float) -> void:
	if is_instance_valid(_actor) and _actor.hotbar.lit and _light_slot != null:
		_light_slot.queue_redraw()


# The light slot's count and burn: "3 torches, 140 s left" in short,
# "" when it's empty. For tests and the slot itself.
func light_text() -> String:
	if not is_instance_valid(_actor) or _actor.hotbar.light == &"": return ""
	var count: int = _actor.pack.count_of(_actor.hotbar.light)
	if not _actor.hotbar.lit: return str(count)
	return "%d lit %ds" % [count, ceili(_actor.hotbar.light_left)]


func _draw_light_slot() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _light_slot.size)
	var has_light: bool = is_instance_valid(_actor) and _actor.hotbar.light != &""
	_light_slot.draw_rect(rect, FILLED if has_light else EMPTY)
	if not has_light:
		_light_slot.draw_rect(rect, BORDER, false, 1.0)
		return
	var hotbar: Hotbar = _actor.hotbar
	var item: Item = ItemRegistry.find(hotbar.light)
	var font: Font = ScaledHud.FONT
	var font_size: int = ScaledHud.FONT_SIZE
	if item != null and item.icon != null:
		_light_slot.draw_texture(item.icon, Vector2((rect.size.x - 16) / 2, 3 + font_size))
	_light_slot.draw_string(font, Vector2(0, rect.size.y - 1), str(_actor.pack.count_of(hotbar.light)),
		HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 2, font_size, Color.WHITE)
	if hotbar.lit:
		var burn_seconds: float = _actor.current_level.world.tuning.torch_burn_seconds
		var share: float = clampf(hotbar.light_left / burn_seconds, 0.0, 1.0)
		_light_slot.draw_rect(Rect2(Vector2(2, 2), Vector2((rect.size.x - 4) * share, 2)), LIT)
	_light_slot.draw_rect(rect, LIT if hotbar.lit else BORDER, false, 2.0 if hotbar.lit else 1.0)


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
	slot.draw_rect(rect, border, false, width)
	var font: Font = ScaledHud.FONT
	var font_size: int = ScaledHud.FONT_SIZE
	slot.draw_string(font, Vector2(2, 2 + font_size), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, BORDER)
	var icon: Texture2D = slot_icon(i)
	var top: float = 3 + font_size
	if icon != null:
		# Under the number, fitted to the room left, keeping its shape:
		# a 16 x 24 fixture shrinks, a 16 x 16 icon sits as drawn
		var icon_height: float = minf(icon.get_height(), slot.size.y - top - 2)
		var icon_width: float = icon.get_width() * icon_height / icon.get_height()
		slot.draw_texture_rect(icon, Rect2(Vector2(roundf((slot.size.x - icon_width) / 2), top),
			Vector2(icon_width, icon_height)), false)
	elif text != "":
		slot.draw_string(font, Vector2(0, slot.size.y - 3), text, HORIZONTAL_ALIGNMENT_CENTER,
			slot.size.x, font_size, Color.WHITE)
