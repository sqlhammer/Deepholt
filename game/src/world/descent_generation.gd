class_name DescentGeneration
extends RefCounted

# How generation joins one level to the next by a ramp (D-215, D-216,
# D-229). On the upper level: a chamber holding the ramp down, placed
# by the seed a set distance from the landing, and a natural tunnel
# carved from the landing to it. On the lower level: an arrival room
# stamped so its ramp up sits on the down end's (x, y), since levels
# share one origin (world-and-generation §1).


# Places the recipe's descent chamber on `level` and carves the tunnel
# to it from the landing: the first fixed placement's anchor, or the
# axis with none. Returns the chamber's footprint, or an empty rect,
# reported, when no spot in range fits.
static func place_descent(level: Level, recipe: LevelRecipe, rng: RandomNumberGenerator,
		tuning: TuningProfile) -> Rect2i:
	if recipe.descent_prefab == &"": return Rect2i()
	var prefab: TilePrefab = TilePrefabRegistry.get_prefab(recipe.descent_prefab)
	if prefab == null:
		push_error("Depth %d names missing descent prefab '%s'." % [level.depth, recipe.descent_prefab])
		return Rect2i()
	var landing: Vector2i = landing_of(recipe)
	var tiles: LevelTiles = level.level_tiles
	for attempt in range(300):
		var angle: float = rng.randf() * TAU
		var distance: int = rng.randi_range(tuning.descent_distance_min, tuning.descent_distance_max)
		var offset: Vector2 = Vector2.from_angle(angle) * distance
		var anchor: Vector2i = landing + Vector2i(roundi(offset.x), roundi(offset.y))
		var rect: Rect2i = RockGeneration.footprint(prefab, anchor)
		if not RockGeneration.fits(tiles, rect, [], 0): continue
		LevelGridLoader.stamp(tiles, prefab, anchor)
		TunnelCarver.carve(tiles, landing, anchor, rng, tuning.tunnel_width_min,
			tuning.tunnel_width_max)
		return rect
	push_error("No room for the way down within %d to %d of the landing on depth %d." % [
		tuning.descent_distance_min, tuning.descent_distance_max, level.depth])
	return Rect2i()


# Where a level's landing is: its first fixed placement's anchor, or
# the axis for a level with none.
static func landing_of(recipe: LevelRecipe) -> Vector2i:
	if recipe.fixed_placements.is_empty(): return Vector2i.ZERO
	return recipe.fixed_placements[0].anchor


# Stamps the recipe's arrival room under every ramp down on `above`,
# its own ramp up on the down end's tile. Returns the tiles where the
# ramps arrive. A down end the room's ramp doesn't pair with is
# reported and skipped.
static func place_arrivals(level: Level, recipe: LevelRecipe, above: Level,
		fixture_ids: IdAllocator) -> Array[Vector2i]:
	var arrived: Array[Vector2i] = []
	if recipe.arrival_prefab == &"" or above == null: return arrived
	var prefab: TilePrefab = TilePrefabRegistry.get_prefab(recipe.arrival_prefab)
	if prefab == null:
		push_error("Depth %d names missing arrival prefab '%s'." % [level.depth, recipe.arrival_prefab])
		return arrived
	var up_end: Dictionary = _ramp_in(prefab)
	if up_end.is_empty():
		push_error("Arrival prefab '%s' has no ramp up." % recipe.arrival_prefab)
		return arrived
	for down_kind: int in TileKind.RAMPS:
		if not TileKind.RAMPS[down_kind].down: continue
		for tile: Vector2i in LevelGenerator.tiles_with_ground(above.level_tiles, down_kind):
			if TileKind.ramp_pair(down_kind) != up_end.kind:
				push_error("The ramp down at %s on depth %d doesn't pair with '%s'." % [
					tile, above.depth, recipe.arrival_prefab])
				continue
			var anchor: Vector2i = tile - up_end.offset
			if LevelGridLoader.stamp(level.level_tiles, prefab, anchor, level.level_fixtures,
					fixture_ids):
				arrived.append(tile)
	return arrived


# The ramp end in a prefab's ground grid: its kind and its offset from
# the anchor, or empty for a prefab with none.
static func _ramp_in(prefab: TilePrefab) -> Dictionary:
	var ground: Dictionary = LevelGridLoader._to_anchored_tiles(prefab.ground)
	for offset: Vector2i in ground:
		var kind: int = LevelGridLoader.GROUND_CHARS.get(ground[offset], -1)
		if TileKind.is_ramp(kind): return {"kind": kind, "offset": offset}
	return {}
