class_name LevelDrops
extends RefCounted

# The items lying on one level (D-160, D-161): stacks by tile, the
# same item merging on a tile. Storage only, like LevelFixtures: the
# world decides who drops and picks up, and this announces each
# change. Filed by tile, so a player's pickup reads nine tiles, never
# the whole level (slice 009 trap 2).

signal drops_changed(tile: Vector2i)

# Tile -> item id -> count. A tile with nothing has no key.
var _by_tile: Dictionary[Vector2i, Dictionary] = {}


func add(tile: Vector2i, id: StringName, count: int) -> void:
	if count <= 0: return
	if not _by_tile.has(tile): _by_tile[tile] = {}
	_by_tile[tile][id] = _by_tile[tile].get(id, 0) + count
	drops_changed.emit(tile)


# Takes up to `count` of `id` from a tile, and returns how many it
# took.
func take(tile: Vector2i, id: StringName, count: int) -> int:
	if count <= 0 or not _by_tile.has(tile): return 0
	var here: int = _by_tile[tile].get(id, 0)
	var taken: int = mini(here, count)
	if taken == 0: return 0
	if taken == here: _by_tile[tile].erase(id)
	else: _by_tile[tile][id] = here - taken
	if _by_tile[tile].is_empty(): _by_tile.erase(tile)
	drops_changed.emit(tile)
	return taken


# What lies on a tile, item id -> count. A copy: changing it changes
# nothing.
func at(tile: Vector2i) -> Dictionary:
	return _by_tile.get(tile, {}).duplicate()


func tiles() -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	found.assign(_by_tile.keys())
	return found


func is_empty() -> bool:
	return _by_tile.is_empty()


# For a save: one entry per stack, as plain types (D-109).
func to_save() -> Array:
	var data: Array = []
	for tile: Vector2i in _by_tile:
		for id: StringName in _by_tile[tile]:
			data.append({"item": String(id), "count": _by_tile[tile][id], "x": tile.x, "y": tile.y})
	return data
