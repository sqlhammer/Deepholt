class_name PackGrid
extends RefCounted

# Where each thing in an actor's pack sits in the inventory's grid
# (D-175, D-177): a cell per item id, in the order the player gave
# them. Room, never a cap: weight is the only limit (D-013), so a
# ninth row is added when the eight are full. A tool on the tool bar
# isn't in the grid; one off the bar is (D-176).
#
# The grid follows its pack and hotbar: a thing that appears takes
# the first empty cell, one that's gone leaves its cell empty. Every
# actor has one (P5), though only a player's is ever shown.

signal changed(grid: PackGrid)

const COLUMNS: int = 8
const ROWS: int = 8

var cells: Array[StringName] = []

var _pack: Pack
var _hotbar: Hotbar


func _init() -> void:
	cells.resize(COLUMNS * ROWS)
	cells.fill(&"")


func watch(pack: Pack, hotbar: Hotbar) -> void:
	if _pack != null and _pack.changed.is_connected(_on_changed):
		_pack.changed.disconnect(_on_changed)
	if _hotbar != null and _hotbar.changed.is_connected(_on_changed):
		_hotbar.changed.disconnect(_on_changed)
	_pack = pack
	_hotbar = hotbar
	if _pack != null: _pack.changed.connect(_on_changed)
	if _hotbar != null: _hotbar.changed.connect(_on_changed)
	reconcile()


# How many of `id` the grid shows: the pack's count, less what the tool
# bar holds.
func count_in_grid(id: StringName) -> int:
	if _pack == null: return 0
	return _hotbar.loose(id) if _is_tool(id) and _hotbar != null else _pack.count_of(id)


# The cell holding `id`, or -1.
func cell_of(id: StringName) -> int:
	return cells.find(id)


# Swaps two cells (D-177).
func swap(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= cells.size() or b >= cells.size() or a == b: return false
	var moving: StringName = cells[a]
	cells[a] = cells[b]
	cells[b] = moving
	changed.emit(self)
	return true


# Puts `id`, already in the grid, at `cell`, swapping with whatever is
# there. Returns whether anything moved.
func move_to(id: StringName, cell: int) -> bool:
	var from: int = cell_of(id)
	if from == -1: return false
	return swap(from, cell)


# Best value per kilo first, then empty cells (ui-ux §5).
func sort_by_value() -> void:
	var ids: Array[StringName] = []
	for id: StringName in cells:
		if id != &"": ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return value_density(a) > value_density(b))
	cells.fill(&"")
	for i in range(ids.size()): cells[i] = ids[i]
	changed.emit(self)


static func value_density(id: StringName) -> float:
	var item: Item = ItemRegistry.find(id)
	if item == null or item.weight_kg <= 0.0: return -1.0
	return item.trade_value / item.weight_kg


# Every id the grid should show has one cell, and no cell holds one it
# shouldn't. New ids take the first empty cell, in the pack's order; a
# full grid grows a row.
func reconcile() -> void:
	var before: Array[StringName] = cells.duplicate()
	for i in range(cells.size()):
		var id: StringName = cells[i]
		if id == &"": continue
		if count_in_grid(id) <= 0 or cells.find(id) != i: cells[i] = &""
	if _pack != null:
		for key: String in _pack.to_save():
			var id: StringName = StringName(key)
			if count_in_grid(id) <= 0 or cells.has(id): continue
			var empty: int = cells.find(&"")
			if empty == -1:
				empty = cells.size()
				for n in range(COLUMNS): cells.append(&"")
			cells[empty] = id
	if cells != before: changed.emit(self)


func _is_tool(id: StringName) -> bool:
	var item: Item = ItemRegistry.find(id)
	return item != null and item.is_tool()


func _on_changed(_what: Variant) -> void:
	reconcile()


# --- saving ---

func to_save() -> Array:
	var saved: Array = []
	for id: StringName in cells: saved.append(String(id))
	return saved


# From a save: a list of ids, a multiple of eight long; anything else
# is an empty grid that the pack then fills, with a warning.
static func from_save(data: Variant) -> PackGrid:
	var grid: PackGrid = PackGrid.new()
	if data == null: return grid
	if not data is Array or data.size() < COLUMNS * ROWS or data.size() % COLUMNS != 0:
		push_warning("A pack grid isn't rows of %d ids; its order is lost." % COLUMNS)
		return grid
	grid.cells.clear()
	for value: Variant in data:
		grid.cells.append(StringName(value) if value is String else &"")
	return grid
