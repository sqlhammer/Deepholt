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
# the last slot pointing at it (D-171). Only a gain fills a slot, so a
# tool moved off the bar stays off it, in the grid (D-176). Two of the
# same tool take two slots. An empty selected slot is bare hands.

signal changed(hotbar: Hotbar)
# The lantern was lit, or burned, with no oil in its tank or the pack
# (D-246): it's dark, and the player is told why.
signal light_dry(hotbar: Hotbar)

const SLOTS: int = 8
const BARE_HANDS: ToolData = preload("res://src/entity/tools/bare_hands.tres")

# The build slots a new hotbar starts with (D-174): ladder, then prop.
const STARTING_BUILDS: Array[int] = [ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.TIMBER_PROP]

# What build mode can place: the build entries a build slot may hold
# (Building), in the order empty slots take them (D-252). There are
# more than slots: the first eight fill a new bar, the BUILD tab
# reaches the rest, and an entry added later takes a saved bar's first
# empty slot.
const BUILDABLE: Array[int] = [ObjectKind.OBJECT.LADDER, ObjectKind.OBJECT.TIMBER_PROP,
	ObjectKind.OBJECT.CHUTE, ObjectKind.OBJECT.WINCH, ObjectKind.OBJECT.WORKBENCH,
	ObjectKind.OBJECT.SMELTER, ObjectKind.OBJECT.STORAGE_CRATE, ObjectKind.OBJECT.BED,
	Building.SMELTER_FROM_TIMBER, ObjectKind.OBJECT.FORGE]

var tools: Array[StringName] = []
var builds: Array[int] = []
var selected_tool: int = 0
var selected_build: int = 0
# The light slot (D-221, D-228), beside the tool slots so the pick
# stays in hand: a light item the pack holds (an item tagged "light"),
# taken by the slot as the pack gains one. `lit` is whether it burns,
# and `light_left` the seconds the one burning has left.
var light: StringName = &""
var lit: bool = false
var light_left: float = 0.0
# The oil lantern's tank (D-246): the oil in it, and the seconds left
# of the oil burning now. Kept apart from a torch's burn, so changing
# lights never gives either a fresh one.
var tank: int = 0
var oil_left: float = 0.0

const LIGHT_TAG: StringName = &"light"
const LANTERN: StringName = &"lantern"
const OIL: StringName = &"lamp_oil"

var _pack: Pack
# What the pack held at the last look, tool id -> count: a rise is a
# gain, which fills slots. A fresh hotbar has seen nothing, so all a
# pack holds is a gain; a saved one has seen what it was saved with.
var _seen: Dictionary[StringName, int] = {}
var _fresh: bool = true


func _init() -> void:
	tools.resize(SLOTS)
	tools.fill(&"")
	builds.resize(SLOTS)
	builds.fill(ObjectKind.OBJECT.NULL)
	for i in range(STARTING_BUILDS.size()):
		builds[i] = STARTING_BUILDS[i]
	_offer_buildables()


# Every buildable kind missing from the build slots takes the first
# empty one, in BUILDABLE's order.
func _offer_buildables() -> void:
	for kind: int in BUILDABLE:
		if builds.has(kind): continue
		var empty: int = builds.find(ObjectKind.OBJECT.NULL)
		if empty == -1: return
		builds[empty] = kind


# Follows a pack: its tools fill the slots, now and as it changes.
func watch(pack: Pack) -> void:
	if _pack != null and _pack.changed.is_connected(_on_pack_changed):
		_pack.changed.disconnect(_on_pack_changed)
	_pack = pack
	if _pack != null: _pack.changed.connect(_on_pack_changed)
	if not _fresh: _seen = _tool_counts()
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


# How many of a tool the pack holds that no slot holds: what the grid
# shows of it (D-176).
func loose(id: StringName) -> int:
	return maxi(_held(id) - _slots_holding(id), 0)


# Puts one loose unit of a tool, from the grid, into `slot`. What was
# there goes to the grid. Returns whether it did.
func place_from_grid(id: StringName, slot: int) -> bool:
	if slot < 0 or slot >= SLOTS or loose(id) <= 0: return false
	var item: Item = ItemRegistry.find(id)
	if item == null or not item.is_tool(): return false
	tools[slot] = id
	changed.emit(self)
	return true


# Swaps two tool slots.
func move_tool(from_slot: int, to_slot: int) -> bool:
	if from_slot < 0 or from_slot >= SLOTS or to_slot < 0 or to_slot >= SLOTS: return false
	if from_slot == to_slot or tools[from_slot] == &"": return false
	var moving: StringName = tools[from_slot]
	tools[from_slot] = tools[to_slot]
	tools[to_slot] = moving
	changed.emit(self)
	return true


# Swaps two build slots.
func move_build(from_slot: int, to_slot: int) -> bool:
	if from_slot < 0 or from_slot >= SLOTS or to_slot < 0 or to_slot >= SLOTS: return false
	if from_slot == to_slot: return false
	var moving: int = builds[from_slot]
	builds[from_slot] = builds[to_slot]
	builds[to_slot] = moving
	changed.emit(self)
	return true


# Takes the tool out of `slot`, leaving it in the pack, off the bar:
# the grid shows it (D-176). Returns whether there was one.
func unassign_tool(slot: int) -> bool:
	if slot < 0 or slot >= SLOTS or tools[slot] == &"": return false
	tools[slot] = &""
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

# No slot points at a tool the pack doesn't hold enough of, and each
# tool the pack has gained since the last look takes an empty slot
# per unit gained, first empty first, in the pack's order. A tool the
# pack holds but the bar doesn't is in the grid (D-176).
func reconcile(announce: bool = true) -> void:
	var before: Array[StringName] = tools.duplicate()
	for slot in range(SLOTS - 1, -1, -1):
		var id: StringName = tools[slot]
		if id == &"": continue
		if _held(id) < _slots_holding(id): tools[slot] = &""
	var now: Dictionary[StringName, int] = _tool_counts()
	for id: StringName in now:
		var gained: int = now[id] - _seen.get(id, 0)
		while gained > 0 and _slots_holding(id) < now[id]:
			var empty: int = tools.find(&"")
			if empty == -1: break
			tools[empty] = id
			gained -= 1
	_seen = now
	_fresh = false
	var light_changed: bool = _reconcile_light()
	if announce and (tools != before or light_changed): changed.emit(self)


# The light slot follows the pack: emptied, and put out, when the pack
# has none of its light left; filled with the first light the pack
# holds when it's empty. Returns whether it changed.
func _reconcile_light() -> bool:
	var was: StringName = light
	var was_lit: bool = lit
	if light != &"" and _held(light) <= 0:
		var lost: StringName = light
		light = &""
		lit = false
		light_left = 0.0
		# The last lantern gone, what was in its tank goes back in the
		# pack; the oil that was burning is spent
		if lost == LANTERN: _empty_tank()
	if light == &"" and _pack != null:
		for key: String in _pack.to_save():
			var item: Item = ItemRegistry.find(StringName(key))
			if item != null and LIGHT_TAG in item.tags:
				light = StringName(key)
				break
	return light != was or lit != was_lit


# --- the light (D-221, D-246) ---

# Puts a light the pack holds in the light slot (D-247), put out if
# another was burning. Returns whether anything changed.
func assign_light(id: StringName) -> bool:
	var item: Item = ItemRegistry.find(id)
	if item == null or LIGHT_TAG not in item.tags or _held(id) <= 0 or light == id: return false
	light = id
	lit = false
	changed.emit(self)
	return true


# Lights the slot's light, or puts it out. Lighting a fresh torch
# starts its full burn; one put out and lit again goes on where it
# stopped. A lantern burns from its tank, filled from the pack's oil
# when it's empty; with no oil it stays dark and says so. Returns
# whether it's lit now. Nothing to light, nothing changes.
func toggle_light(tuning: TuningProfile) -> bool:
	if lit:
		lit = false
	elif light == LANTERN and _held(light) > 0:
		if oil_left <= 0.0 and not _next_oil(tuning):
			light_dry.emit(self)
			return false
		lit = true
	elif light != &"" and _held(light) > 0:
		lit = true
		if light_left <= 0.0: light_left = tuning.torch_burn_seconds
	changed.emit(self)
	return lit


# The next oil from the tank into the flame, the tank filled from the
# pack first when it's empty. Returns whether there was any.
func _next_oil(tuning: TuningProfile) -> bool:
	if tank <= 0 and _pack != null:
		var poured: int = mini(tuning.lantern_tank, _pack.count_of(OIL))
		if poured > 0:
			tank = poured
			_pack.remove(OIL, poured)
	if tank <= 0: return false
	tank -= 1
	oil_left += tuning.lantern_oil_seconds
	return true


func _empty_tank() -> void:
	var left: int = tank
	tank = 0
	oil_left = 0.0
	if left > 0 and _pack != null: _pack.add(OIL, left)


# How full the lantern is, 0 to 1: its tank and the oil burning.
func lantern_fuel(tuning: TuningProfile) -> float:
	var full: float = tuning.lantern_tank * tuning.lantern_oil_seconds
	if full <= 0.0: return 0.0
	return clampf((tank * tuning.lantern_oil_seconds + oil_left) / full, 0.0, 1.0)


# Burns the lit light for `delta` seconds. When a torch burns out it
# is used up, and the next lights from the pack with a full burn, or
# the slot goes dark; a lantern goes on to its next oil. Returns
# whether one burned out.
func burn(delta: float, tuning: TuningProfile) -> bool:
	if not lit: return false
	if light == LANTERN: return _burn_oil(delta, tuning)
	var burn_seconds: float = tuning.torch_burn_seconds
	light_left -= delta
	if light_left > 0.0: return false
	var used: StringName = light
	var carried_over: float = light_left
	light_left = 0.0
	_pack.remove(used, 1)
	if lit and light == used: light_left = maxf(burn_seconds + carried_over, 0.0)
	changed.emit(self)
	return true


# The lantern's flame burns its oil; at the end of one, the next, or
# dark when there's none left in the tank or the pack.
func _burn_oil(delta: float, tuning: TuningProfile) -> bool:
	oil_left -= delta
	if oil_left > 0.0: return false
	if _next_oil(tuning) and oil_left > 0.0: return false
	oil_left = 0.0
	lit = false
	changed.emit(self)
	light_dry.emit(self)
	return true


# One light out of the pack, still burning: what dropping it lit takes
# (D-221). The slot lights the next with a full burn, or goes dark.
# Returns the seconds the one taken had left.
func hand_over_light(burn_seconds: float) -> float:
	var left: float = light_left
	var used: StringName = light
	light_left = 0.0
	_pack.remove(used, 1)
	if lit and light == used: light_left = burn_seconds
	changed.emit(self)
	return left


# The pack's tools, id -> count, in the pack's order.
func _tool_counts() -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	if _pack == null: return counts
	for key: String in _pack.to_save():
		var id: StringName = StringName(key)
		var item: Item = ItemRegistry.find(id)
		if item != null and item.is_tool(): counts[id] = _pack.count_of(id)
	return counts


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
		"light": String(light),
		"lit": lit,
		"light_left": light_left,
		"tank": tank,
		"oil_left": oil_left,
	}


# From a save: anything malformed falls back to the starting layout's
# value, slot by slot, with a warning. The slots are reconciled with
# the pack once it's watched, so a saved tool the pack lacks empties.
static func from_save(data: Variant) -> Hotbar:
	var hotbar: Hotbar = Hotbar.new()
	if not data is Dictionary: return hotbar
	# Its slots are as saved: what the pack holds then isn't a gain
	hotbar._fresh = false
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
	hotbar._offer_buildables()
	hotbar.selected_tool = _slot_or_zero(data.get("selected_tool"))
	hotbar.selected_build = _slot_or_zero(data.get("selected_build"))
	# The light slot, from a save that has one; the pack's watch puts it
	# right if the pack no longer holds that light
	if data.get("light") is String: hotbar.light = StringName(data.light)
	if data.get("lit") is bool: hotbar.lit = data.lit
	var left: Variant = data.get("light_left")
	if left is float or left is int: hotbar.light_left = maxf(float(left), 0.0)
	var saved_tank: Variant = data.get("tank")
	if saved_tank is float or saved_tank is int: hotbar.tank = maxi(int(saved_tank), 0)
	var saved_oil: Variant = data.get("oil_left")
	if saved_oil is float or saved_oil is int: hotbar.oil_left = maxf(float(saved_oil), 0.0)
	return hotbar


static func _slot_or_zero(value: Variant) -> int:
	if not (value is int or value is float): return 0
	var slot: int = int(value)
	return slot if slot >= 0 and slot < SLOTS else 0
