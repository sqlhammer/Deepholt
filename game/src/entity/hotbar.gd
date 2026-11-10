class_name Hotbar
extends RefCounted

# One actor's eight slots (D-170): tool slots, used outside build
# mode, and build slots, used inside it, each with its own selection.
# Every actor has one, NPCs too (D-045, P5): what an actor digs with is
# its own selected slot, never "the player's".
#
# A tool slot holds an item id, and only while the pack holds that
# item (slice 011 trap 4). `reconcile` keeps the two agreeing: a tool
# the pack gains takes the first empty slot, and one it loses empties
# the last slot pointing at it (D-171). Two of the same tool take two
# slots. An empty selected slot is bare hands.

signal changed(hotbar: Hotbar)

const SLOTS: int = 8
const BARE_HANDS: ToolData = preload("res://src/entity/tools/bare_hands.tres")

# The build slots a new hotbar starts with (D-174): ladder, then prop.
const STARTING_BUILDS: Array[int] = [ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.TIMBER_PROP]

# What build mode can place: the kinds a build slot may hold.
const BUILDABLE: Array[int] = [ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.TIMBER_PROP]

var tools: Array[StringName] = []
var builds: Array[int] = []
var selected_tool: int = 0
var selected_build: int = 0

var _pack: Pack


func _init() -> void:
	tools.resize(SLOTS)
	tools.fill(&"")
	builds.resize(SLOTS)
	builds.fill(ObjectKind.OBJECT.NULL)
	for i in range(STARTING_BUILDS.size()):
		builds[i] = STARTING_BUILDS[i]


# Follows a pack: its tools fill the slots, now and as it changes.
func watch(pack: Pack) -> void:
	if _pack != null and _pack.changed.is_connected(_on_pack_changed):
		_pack.changed.disconnect(_on_pack_changed)
	_pack = pack
	if _pack != null: _pack.changed.connect(_on_pack_changed)
	reconcile()


# --- what's held ---

# The selected tool slot's tool, or bare hands when it's empty.
func tool() -> ToolData:
	var item: Item = ItemRegistry.find(tools[selected_tool])
	return item.tool if item != null and item.is_tool() else BARE_HANDS


# The selected build slot's kind, or NULL when it's empty.
func build() -> int:
	return builds[selected_build]


# --- selecting (1-8, a click, the wheel, LB / RB) ---

func select_tool(slot: int) -> void:
	if slot < 0 or slot >= SLOTS or slot == selected_tool: return
	selected_tool = slot
	changed.emit(self)


func select_build(slot: int) -> void:
	if slot < 0 or slot >= SLOTS or slot == selected_build: return
	selected_build = slot
	changed.emit(self)


# One slot along, wrapping: the bumpers and the wheel.
func step_tool(step: int) -> void:
	select_tool(posmod(selected_tool + step, SLOTS))


func step_build(step: int) -> void:
	select_build(posmod(selected_build + step, SLOTS))


# --- arranging (the inventory, D-172, D-174) ---

# Puts a tool the pack holds into `slot`. Whatever was there moves to
# the slot the tool came from (a swap), or empties when the tool
# wasn't on the bar yet. Returns whether anything changed.
func assign_tool(id: StringName, slot: int) -> bool:
	if slot < 0 or slot >= SLOTS or _pack == null: return false
	var item: Item = ItemRegistry.find(id)
	if item == null or not item.is_tool() or _pack.count_of(id) <= 0: return false
	if tools[slot] == id: return false
	var from: int = tools.find(id)
	var displaced: StringName = tools[slot]
	tools[slot] = id
	if from != -1: tools[from] = displaced
	# A displaced tool with nowhere to go takes the first empty slot
	reconcile(false)
	changed.emit(self)
	return true


# Puts a buildable kind into `slot`, swapping with the slot that held
# it, if any.
func assign_build(kind: int, slot: int) -> bool:
	if slot < 0 or slot >= SLOTS or kind not in BUILDABLE: return false
	if builds[slot] == kind: return false
	var from: int = builds.find(kind)
	var displaced: int = builds[slot]
	builds[slot] = kind
	if from != -1: builds[from] = displaced
	changed.emit(self)
	return true


# The slot holding `id`, or -1.
func slot_of_tool(id: StringName) -> int:
	return tools.find(id)


func slot_of_build(kind: int) -> int:
	return builds.find(kind)


# --- keeping slots and pack agreeing (trap 4) ---

# Every tool the pack holds is on the bar once per unit, and no slot
# points at a tool the pack doesn't hold enough of. Slots are filled
# in the pack's order, first empty first.
func reconcile(announce: bool = true) -> void:
	var before: Array[StringName] = tools.duplicate()
	for slot in range(SLOTS - 1, -1, -1):
		var id: StringName = tools[slot]
		if id == &"": continue
		if _held(id) < _slots_holding(id): tools[slot] = &""
	if _pack != null:
		for key: String in _pack.to_save():
			var id: StringName = StringName(key)
			var item: Item = ItemRegistry.find(id)
			if item == null or not item.is_tool(): continue
			while _slots_holding(id) < _pack.count_of(id):
				var empty: int = tools.find(&"")
				if empty == -1: break
				tools[empty] = id
	if announce and tools != before: changed.emit(self)


func _held(id: StringName) -> int:
	return _pack.count_of(id) if _pack != null else 0


func _slots_holding(id: StringName) -> int:
	return tools.count(id)


func _on_pack_changed(_pack_changed: Pack) -> void:
	reconcile()


# --- saving ---

func to_save() -> Dictionary:
	var saved_tools: Array = []
	for id: StringName in tools: saved_tools.append(String(id))
	return {
		"tools": saved_tools,
		"builds": builds.duplicate(),
		"selected_tool": selected_tool,
		"selected_build": selected_build,
	}


# From a save: anything malformed falls back to the starting layout's
# value, slot by slot, with a warning. The slots are reconciled with
# the pack once it's watched, so a saved tool the pack lacks empties.
static func from_save(data: Variant) -> Hotbar:
	var hotbar: Hotbar = Hotbar.new()
	if not data is Dictionary: return hotbar
	var saved_tools: Variant = data.get("tools")
	if saved_tools is Array and saved_tools.size() == SLOTS:
		for i in range(SLOTS):
			hotbar.tools[i] = StringName(saved_tools[i]) if saved_tools[i] is String else &""
	elif saved_tools != null:
		push_warning("A hotbar's tool slots aren't %d ids; the starting layout is used." % SLOTS)
	var saved_builds: Variant = data.get("builds")
	if saved_builds is Array and saved_builds.size() == SLOTS:
		for i in range(SLOTS):
			var kind: Variant = saved_builds[i]
			var valid: bool = (kind is int or kind is float) and (int(kind) in BUILDABLE \
				or int(kind) == ObjectKind.OBJECT.NULL)
			hotbar.builds[i] = int(kind) if valid else ObjectKind.OBJECT.NULL
	elif saved_builds != null:
		push_warning("A hotbar's build slots aren't %d kinds; the starting layout is used." % SLOTS)
	hotbar.selected_tool = _slot_or_zero(data.get("selected_tool"))
	hotbar.selected_build = _slot_or_zero(data.get("selected_build"))
	return hotbar


static func _slot_or_zero(value: Variant) -> int:
	if not (value is int or value is float): return 0
	var slot: int = int(value)
	return slot if slot >= 0 and slot < SLOTS else 0
