class_name Smelter
extends RefCounted

# One smelter's work (D-238, D-242, D-243): what has been dropped into
# it, in the order it went in, its coal, and how far into the batch
# it's working. What it has made is its fixture's contents, which the
# take key empties.
#
# A rate machine (world-runtime §5): nothing ticks it. It keeps the
# world time it was last worked out, and `advance_to` works out
# everything made since, in one step, whenever it's asked: when a
# player looks, drops in or takes out, while a player is on its level,
# and after a load. So it smelts on a level nobody is on, and across a
# save, exactly as if it had run.

# What each input makes, per batch: what a batch takes of it, and what
# it gives. Copper and tin ingots alloy together (D-242): 3 copper and 1
# tin make 4 bronze. Content, beside Digging's ORE_ITEMS: it moves to
# a resource when there are more.
const BATCHES: Dictionary = {
	&"copper_ore": {"takes": {&"copper_ore": 3}, "gives": {&"copper_ingot": 1}},
	&"tin_ore": {"takes": {&"tin_ore": 3}, "gives": {&"tin_ingot": 1}},
	&"iron_ore": {"takes": {&"iron_ore": 3}, "gives": {&"iron_ingot": 1}},
	&"copper_ingot": {"takes": {&"copper_ingot": 3, &"tin_ingot": 1}, "gives": {&"bronze_ingot": 4}},
	&"tin_ingot": {"takes": {&"copper_ingot": 3, &"tin_ingot": 1}, "gives": {&"bronze_ingot": 4}},
}
const FUEL: StringName = &"coal"
# Every batch burns one coal (D-239)
const FUEL_PER_BATCH: int = 1

# What was dropped in and not yet smelted, oldest first: one
# {"id": StringName, "count": int} per drop, so a smelter works its
# inputs in the order they went in (D-243).
var inputs: Array[Dictionary] = []
var coal: int = 0
# Seconds of work into the batch under way; zero while idle
var progress: float = 0.0
# The world time it was last worked out at
var last_evaluated: float = 0.0


func _init(now: float = 0.0) -> void:
	last_evaluated = now


# Whether the smelter takes an item at all: coal, or something a batch
# is made from.
static func takes(id: StringName) -> bool:
	return id == FUEL or BATCHES.has(id)


# The weight of everything waiting in it, in kg: inputs and coal.
func loaded_weight() -> float:
	var kg: float = _weight_of(FUEL) * coal
	for lot: Dictionary in inputs:
		kg += _weight_of(lot.id) * lot.count
	return kg


static func _weight_of(id: StringName) -> float:
	var item: Item = ItemRegistry.find(id)
	return item.weight_kg if item != null else 0.0


# Puts `count` of `id` in: coal into the fuel, anything else at the end
# of the line. Call `advance_to` first, so what was there is worked out
# before anything new can join it.
func load_items(id: StringName, count: int) -> void:
	if count <= 0: return
	if id == FUEL:
		coal += count
		return
	if not inputs.is_empty() and inputs[-1].id == id:
		inputs[-1].count += count
		return
	inputs.append({"id": id, "count": count})


func count_of(id: StringName) -> int:
	if id == FUEL: return coal
	var total: int = 0
	for lot: Dictionary in inputs:
		if lot.id == id: total += lot.count
	return total


# The batch it would work next, by its input id, or &"" when nothing it
# holds makes one: the oldest input whose batch is whole, with coal.
func next_batch() -> StringName:
	if coal < FUEL_PER_BATCH: return &""
	for lot: Dictionary in inputs:
		if _whole(BATCHES[lot.id].takes): return lot.id
	return &""


func _whole(needs: Dictionary) -> bool:
	for id: StringName in needs:
		if count_of(id) < needs[id]: return false
	return true


func is_working() -> bool:
	return next_batch() != &""


# Works out everything made between the last time and `now`, at
# `speed` (1 working, 0 buried: D-253), and puts it in `output`. A batch takes
# `batch_seconds` of work; between batches, with nothing whole to work,
# it waits and its progress is lost. Returns what was made, id -> count.
func advance_to(now: float, speed: float, batch_seconds: float,
		output: Pack) -> Dictionary[StringName, int]:
	var made: Dictionary[StringName, int] = {}
	var elapsed: float = maxf(now - last_evaluated, 0.0)
	last_evaluated = maxf(now, last_evaluated)
	if batch_seconds <= 0.0: return made
	var work: float = progress + elapsed * speed
	while true:
		var batch: StringName = next_batch()
		if batch == &"":
			progress = 0.0
			break
		if work < batch_seconds:
			progress = work
			break
		work -= batch_seconds
		_make(BATCHES[batch], output, made)
	return made


func _make(batch: Dictionary, output: Pack, made: Dictionary[StringName, int]) -> void:
	coal -= FUEL_PER_BATCH
	for id: StringName in batch.takes:
		_take(id, batch.takes[id])
	for id: StringName in batch.gives:
		output.add(id, batch.gives[id])
		made[id] = made.get(id, 0) + batch.gives[id]


# Takes `count` of `id` from the oldest lots first.
func _take(id: StringName, count: int) -> void:
	var left: int = count
	for lot: Dictionary in inputs:
		if left <= 0: break
		if lot.id != id: continue
		var used: int = mini(lot.count, left)
		lot.count -= used
		left -= used
	inputs = inputs.filter(func(lot: Dictionary) -> bool: return lot.count > 0)


# Everything still waiting in it, id -> count, coal included. The take
# key never takes these, only what's made (D-238).
func waiting() -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	for lot: Dictionary in inputs:
		found[lot.id] = found.get(lot.id, 0) + lot.count
	if coal > 0: found[FUEL] = coal
	return found


# --- saving ---

func to_save() -> Dictionary:
	var saved_inputs: Array = []
	for lot: Dictionary in inputs:
		saved_inputs.append({"id": String(lot.id), "count": lot.count})
	return {"inputs": saved_inputs, "coal": coal, "progress": progress,
		"last_evaluated": last_evaluated}


# From a save: anything malformed is left out, with a warning.
static func from_save(data: Variant) -> Smelter:
	var smelter: Smelter = Smelter.new()
	if not data is Dictionary:
		if data != null: push_warning("A smelter's save isn't a dictionary; it loads empty.")
		return smelter
	var saved_inputs: Variant = data.get("inputs")
	if saved_inputs is Array:
		for lot: Variant in saved_inputs:
			if lot is Dictionary and lot.get("id") is String and _is_number(lot.get("count")) \
					and takes(StringName(lot.id)) and StringName(lot.id) != FUEL:
				smelter.load_items(StringName(lot.id), int(lot.count))
			else:
				push_warning("A smelter's input %s isn't one it takes; it's left out." % [lot])
	if _is_number(data.get("coal")): smelter.coal = maxi(int(data.coal), 0)
	if _is_number(data.get("progress")): smelter.progress = maxf(float(data.progress), 0.0)
	if _is_number(data.get("last_evaluated")): smelter.last_evaluated = float(data.last_evaluated)
	return smelter


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
