class_name RegionGeneration
extends RefCounted

# Places a level's tagged regions (D-218): for now, CRUSHED ones. A
# region is a blob, the union of a few discs around a center the seed
# picks, kept a set distance from the level's landings. Only its
# minable rock is filled with crushed rubble, so a region never walls
# in open floor; those tiles become the region.


# Places the recipe's CRUSHED regions on `level`, keeping each center
# the profile's distance from every tile in `keep_clear`. A region
# that can't be placed is reported.
static func place_crushed(level: Level, recipe: LevelRecipe, rng: RandomNumberGenerator,
		tuning: TuningProfile, keep_clear: Array[Vector2i]) -> void:
	var tiles: LevelTiles = level.level_tiles
	# Room for the blob's whole reach inside the level
	var reach: int = 2 * tuning.crushed_radius_max
	var inner: int = tiles.level_bound.radius - reach
	for n in range(recipe.crushed_regions):
		var placed: bool = false
		for attempt in range(200):
			var center: Vector2i = Vector2i(rng.randi_range(-inner, inner), rng.randi_range(-inner, inner))
			if center.x * center.x + center.y * center.y > inner * inner: continue
			if _too_close(center, keep_clear, tuning.crushed_distance_min): continue
			var filled: Array[Vector2i] = _fill(tiles, _blob(center, rng, tuning))
			if filled.is_empty(): continue
			level.level_regions.add(LevelRegions.ACCESS.CRUSHED, filled)
			placed = true
			break
		if not placed:
			push_error("No room for a crushed region on depth %d." % level.depth)


static func _too_close(center: Vector2i, keep_clear: Array[Vector2i], distance: int) -> bool:
	for tile: Vector2i in keep_clear:
		if (tile - center).length_squared() < distance * distance: return true
	return false


# The tiles of a blob: a disc at the center and more around it, each
# with its own radius, every one within the largest radius of the
# center. Sorted, so the same seed gives the same order.
static func _blob(center: Vector2i, rng: RandomNumberGenerator,
		tuning: TuningProfile) -> Array[Vector2i]:
	var found: Dictionary[Vector2i, bool] = {}
	for lobe in range(maxi(tuning.crushed_lobes, 1)):
		var offset: Vector2i = Vector2i.ZERO
		if lobe > 0:
			offset = Vector2i(rng.randi_range(-tuning.crushed_radius_max, tuning.crushed_radius_max),
				rng.randi_range(-tuning.crushed_radius_max, tuning.crushed_radius_max))
		var radius: int = rng.randi_range(tuning.crushed_radius_min, tuning.crushed_radius_max)
		var middle: Vector2i = center + offset
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy <= radius * radius: found[middle + Vector2i(dx, dy)] = true
	var tiles: Array[Vector2i] = []
	tiles.assign(found.keys())
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return tiles


# Fills the blob's minable rock with crushed rubble, clearing its ore.
# Returns the tiles filled.
static func _fill(tiles: LevelTiles, blob: Array[Vector2i]) -> Array[Vector2i]:
	var filled: Array[Vector2i] = []
	for tile: Vector2i in blob:
		if tiles.get_top(tile.x, tile.y) != TileKind.TOP.MINABLE_ROCK: continue
		tiles.set_top(tile.x, tile.y, TileKind.TOP.CRUSHED, true)
		tiles.set_ore(tile.x, tile.y, TileKind.ORE.NONE, true)
		filled.append(tile)
	return filled
