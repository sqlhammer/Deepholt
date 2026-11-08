class_name InventoryOverlay
extends CanvasLayer

# What the local player carries, and what to leave behind (ui-ux §5,
# D-160, D-162): each item with its weight, sorted by value density
# (trade value per kilo, best first), one selected. Dropping asks the
# player's world, which moves the items onto its tile. An overlay: the
# game keeps running. Presentation, for the local player (D-045).

var is_open: bool = false
var actor: Actor
# The selected row
var selected: int = 0

var _panel: PanelContainer
var _label: Label


func _init() -> void:
	name = "InventoryOverlay"
	layer = 85
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	add_child(_panel)
	_label = Label.new()
	_panel.add_child(_label)


func toggle() -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	is_open = value and actor != null
	_panel.visible = is_open
	if is_open:
		if not actor.pack.changed.is_connected(_on_pack_changed):
			actor.pack.changed.connect(_on_pack_changed)
		selected = 0
	_refresh()


# The pack's item ids, best value per kilo first; ids this build
# doesn't know, last.
func rows() -> Array[StringName]:
	var ids: Array[StringName] = []
	if actor == null: return ids
	ids.assign(actor.pack.to_save().keys().map(func(k: String) -> StringName: return StringName(k)))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return value_density(a) > value_density(b))
	return ids


static func value_density(id: StringName) -> float:
	var item: Item = ItemRegistry.find(id)
	if item == null or item.weight_kg <= 0.0: return -1.0
	return item.trade_value / item.weight_kg


func select(step: int) -> void:
	var count: int = rows().size()
	if count == 0: return
	selected = posmod(selected + step, count)
	_refresh()


func drop_one() -> void:
	_drop(1)


func drop_stack() -> void:
	var ids: Array[StringName] = rows()
	if ids.is_empty(): return
	_drop(actor.pack.count_of(ids[selected]))


func _drop(count: int) -> void:
	var ids: Array[StringName] = rows()
	if not is_open or ids.is_empty(): return
	actor.current_level.world.drop_requested.emit(actor, ids[selected], count)


func _on_pack_changed(_pack: Pack) -> void:
	selected = clampi(selected, 0, maxi(rows().size() - 1, 0))
	_refresh()


# The rows as text: a marker on the selected one, the count, the name
# and the stack's weight.
func text() -> String:
	return _label.text


func _refresh() -> void:
	if not is_open:
		_label.text = ""
		return
	var lines: PackedStringArray = ["Pack  (X drop one, Z drop all, Tab close)"]
	var ids: Array[StringName] = rows()
	if ids.is_empty(): lines.append("  empty")
	for i in range(ids.size()):
		var id: StringName = ids[i]
		var item: Item = ItemRegistry.find(id)
		var name: String = item.display_key if item != null else String(id)
		var weight: float = item.weight_kg * actor.pack.count_of(id) if item != null else 0.0
		lines.append("%s %d %s  %.0f kg" % [">" if i == selected else " ",
			actor.pack.count_of(id), name, weight])
	_label.text = "\n".join(lines)
