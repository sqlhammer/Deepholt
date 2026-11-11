class_name LevelRegions
extends RefCounted

# A level's tagged regions (D-012, D-218): areas generation marked with
# an access class, kept with the level and saved. Only CRUSHED exists
# in 015; UNSTABLE and SEALED build on the same tag later. A tile not
# in any region is OPEN.
#
# Generation fills the store; nothing at runtime changes it yet. When
# clearing a region arrives, the change goes through the world, like
# every other change to a level.

# The access classes of world-and-generation §3. Values are saved:
# never reorder or reuse them.
enum ACCESS {
	OPEN = 0,
	UNSTABLE = 1,
	SEALED = 2,
	CRUSHED = 3,
}

# Each region: its access class and its tiles, in the order added.
var _regions: Array[Dictionary] = []
# Every region tile -> the index of its region, for a quick lookup
var _by_tile: Dictionary[Vector2i, int] = {}


# Adds a region of `tiles` under `access`. A tile already in a region
# stays in the first one.
func add(access: ACCESS, tiles: Array[Vector2i]) -> void:
	var index: int = _regions.size()
	var kept: Array[Vector2i] = []
	for tile: Vector2i in tiles:
		if _by_tile.has(tile): continue
		_by_tile[tile] = index
		kept.append(tile)
	_regions.append({"access": access, "tiles": kept})


# The access class of the region holding `tile`, or OPEN.
func access_at(tile: Vector2i) -> ACCESS:
	if not _by_tile.has(tile): return ACCESS.OPEN
	return _regions[_by_tile[tile]].access


func count() -> int:
	return _regions.size()


# The tiles of every region with this access class.
func tiles_of(access: ACCESS) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for region: Dictionary in _regions:
		if region.access == access: found.append_array(region.tiles)
	return found


# Plain data for a save: one entry per region, its tiles as a flat
# list of x, y pairs.
func to_save() -> Array:
	var data: Array = []
	for region: Dictionary in _regions:
		var flat: Array[int] = []
		for tile: Vector2i in region.tiles:
			flat.append(tile.x)
			flat.append(tile.y)
		data.append({"access": int(region.access), "tiles": flat})
	return data


# The store a save describes. An entry that isn't a region, or names an
# access class this build doesn't know, is skipped with a warning.
static func from_save(data: Variant, depth: int) -> LevelRegions:
	var regions: LevelRegions = LevelRegions.new()
	if not data is Array: return regions
	for entry: Variant in data:
		if not entry is Dictionary or not entry.get("access") is int \
				or not entry.get("tiles") is Array or entry.tiles.size() % 2 != 0 \
				or not ACCESS.values().has(entry.access):
			push_warning("A region on depth %d isn't one; skipped." % depth)
			continue
		var tiles: Array[Vector2i] = []
		for i in range(0, entry.tiles.size(), 2):
			tiles.append(Vector2i(int(entry.tiles[i]), int(entry.tiles[i + 1])))
		regions.add(entry.access, tiles)
	return regions
