class_name Pack
extends RefCounted

# What one actor carries (D-013, D-157): a count per item id, and the
# total weight, kept current as the pack changes. Speed is read every
# tick, so the total is never summed there (slice 008 trap 3). Every
# actor has one, NPCs included (P5). There is no cap: a pack can be
# loaded past its capacity, and the load curve says what that costs
# (D-158).
#
# An id this build doesn't know is kept, weighing nothing, and
# reported: never dropped, so a save keeps it (trap 5).

signal changed(pack: Pack)

var total_weight: float = 0.0

var _counts: Dictionary[StringName, int] = {}


func count_of(id: StringName) -> int:
	return _counts.get(id, 0)


func has(id: StringName, count: int) -> bool:
	return count_of(id) >= count


func is_empty() -> bool:
	return _counts.is_empty()


func add(id: StringName, count: int) -> void:
	if count <= 0: return
	_counts[id] = count_of(id) + count
	total_weight += _weight_of(id) * count
	changed.emit(self)


# Takes `count` of `id`, if the pack has that many. Returns whether it
# did; a pack without enough is left as it was.
func remove(id: StringName, count: int) -> bool:
	if count <= 0: return true
	if not has(id, count): return false
	_counts[id] = count_of(id) - count
	if _counts[id] == 0: _counts.erase(id)
	total_weight = maxf(total_weight - _weight_of(id) * count, 0.0)
	changed.emit(self)
	return true


# The ids this build has no item for.
func unknown_ids() -> Array[StringName]:
	var unknown: Array[StringName] = []
	for id: StringName in _counts:
		if ItemRegistry.find(id) == null: unknown.append(id)
	return unknown


# For a save: id -> count, as plain types (D-109).
func to_save() -> Dictionary:
	var data: Dictionary = {}
	for id: StringName in _counts:
		data[String(id)] = _counts[id]
	return data


# From a save: entries that aren't a String id and a positive int are
# skipped, with a warning. Unknown ids are kept (see above).
static func from_save(data: Variant) -> Pack:
	var pack: Pack = Pack.new()
	if not data is Dictionary: return pack
	for key: Variant in data:
		var count: Variant = data[key]
		if not key is String or not count is int or count <= 0:
			push_warning("A pack entry %s: %s isn't an item id and a count; skipped." % [key, count])
			continue
		pack.add(StringName(key), count)
	return pack


static func _weight_of(id: StringName) -> float:
	var item: Item = ItemRegistry.find(id)
	return item.weight_kg if item != null else 0.0
