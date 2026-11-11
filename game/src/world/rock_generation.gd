class_name RockGeneration
extends RefCounted

# What generation puts in a level's rock (D-183, D-184, D-187): natural
# caves, stamped from hand-made prefabs at places the seed picks, and
# veins of ore, at the profile's share of the rock for each ore and
# depth. Both draw from the level's one generator, after its fixed
# placements, caves before ore so veins run in the rock around them.
# Caves are natural: never marked excavated, so never judged (D-164).


# --- caves (D-184) ---

# Between the profile's minimum and maximum of the recipe's cave
# prefabs, each at a random spot whose whole footprint is in the
# level, still solid rock, and the profile's spacing from the fixed
# placements and every cave before it. Returns where each went. Fewer
# than the minimum is reported: the level is too crowded or too small.
static func place_caves(level: Level, recipe: LevelRecipe, rng: RandomNumberGenerator,
		tuning: TuningProfile) -> Array[Rect2i]:
	var placed: Array[Rect2i] = []
	if recipe.cave_prefabs.is_empty(): return placed
	var taken: Array[Rect2i] = []
	for placement: PrefabPlacement in recipe.fixed_placements:
		var prefab: TilePrefab = TilePrefabRegistry.get_prefab(placement.prefab_id)
		if prefab != null: taken.append(footprint(prefab, placement.anchor))
	var count: int = rng.randi_range(tuning.cave_count_min, tuning.cave_count_max)
	var radius: int = level.level_tiles.level_bound.radius
	for i in range(count):
		var cave_id: StringName = recipe.cave_prefabs[rng.randi_range(0, recipe.cave_prefabs.size() - 1)]
		var prefab: TilePrefab = TilePrefabRegistry.get_prefab(cave_id)
		if prefab == null:
			push_error("Depth %d names missing cave prefab '%s'." % [level.depth, cave_id])
			continue
		for attempt in range(200):
			var anchor: Vector2i = Vector2i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius))
			var rect: Rect2i = footprint(prefab, anchor)
			if not fits(level.level_tiles, rect, taken, tuning.cave_spacing): continue
			LevelGridLoader.stamp(level.level_tiles, prefab, anchor)
			taken.append(rect)
			placed.append(rect)
			break
	if placed.size() < tuning.cave_count_min:
		push_error("Only %d of at least %d caves fit on depth %d." % [
			placed.size(), tuning.cave_count_min, level.depth])
	return placed


# The tiles a prefab covers when stamped at `anchor`.
static func footprint(prefab: TilePrefab, anchor: Vector2i) -> Rect2i:
	var tiles: Dictionary = LevelGridLoader._to_anchored_tiles(prefab.top)
	var rect: Rect2i = Rect2i(anchor, Vector2i.ONE)
	for tile: Vector2i in tiles:
		rect = rect.expand(anchor + tile).expand(anchor + tile + Vector2i.ONE)
	return rect


# Inside the level's disc, solid rock throughout (so sealed), and the
# spacing clear of everything taken. The way down's chamber is placed
# by the same test (D-229).
static func fits(tiles: LevelTiles, rect: Rect2i, taken: Array[Rect2i], spacing: int) -> bool:
	var radius: int = tiles.level_bound.radius
	for corner: Vector2i in [rect.position, rect.end - Vector2i.ONE,
			Vector2i(rect.position.x, rect.end.y - 1), Vector2i(rect.end.x - 1, rect.position.y)]:
		if corner.x * corner.x + corner.y * corner.y > radius * radius: return false
	for other: Rect2i in taken:
		if rect.intersects(other.grow(spacing)): return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if tiles.get_top(x, y) != TileKind.TOP.MINABLE_ROCK: return false
	return true


# --- veins (D-183, D-187) ---

# For each ore with a share at this depth, veins of the profile's
# sizes until that share of the level's minable rock holds it. A vein
# starts on a random rock tile and grows to its neighbors, edge to
# edge, through rock with no ore yet. Ores are taken in id order, so
# the same seed lays the same veins.
static func place_veins(level: Level, rng: RandomNumberGenerator, tuning: TuningProfile) -> void:
	var ores: Array = tuning.ore_shares.keys()
	ores.sort()
	var tiles: LevelTiles = level.level_tiles
	var radius: int = tiles.level_bound.radius
	var width: int = 2 * radius + 1
	var top: PackedByteArray = tiles.top
	var ore: PackedByteArray = tiles.ore
	var rock: PackedInt32Array = _rock_indices(top, radius)
	if rock.is_empty(): return
	var changed: bool = false
	for kind: int in ores:
		var shares: Array = tuning.ore_shares[kind]
		var share: float = float(shares[level.depth]) if level.depth < shares.size() else 0.0
		var target: int = roundi(rock.size() * share)
		var laid: int = 0
		var guard: int = 0
		while laid < target and guard < target * 20:
			guard += 1
			var start: int = rock[rng.randi_range(0, rock.size() - 1)]
			if ore[start] != TileKind.ORE.NONE: continue
			var size: int = mini(rng.randi_range(tuning.vein_size_min, tuning.vein_size_max), target - laid)
			for index: int in _vein(top, ore, start, size, width, radius, rng):
				ore[index] = kind
				laid += 1
				changed = true
	if changed: tiles.bulk_load_tile_arrays({"ore": ore})


# Indices of the minable rock inside the level's disc, in order.
static func _rock_indices(top: PackedByteArray, radius: int) -> PackedInt32Array:
	var found: PackedInt32Array = []
	var width: int = 2 * radius + 1
	var index: int = top.find(TileKind.TOP.MINABLE_ROCK)
	while index != -1:
		var x: int = index % width - radius
		var y: int = index / width - radius
		if x * x + y * y <= radius * radius: found.append(index)
		index = top.find(TileKind.TOP.MINABLE_ROCK, index + 1)
	return found


# A vein of up to `size` tiles grown from `start`: each step takes a
# random tile of the vein and adds a random neighbor that's rock with
# no ore, inside the disc.
static func _vein(top: PackedByteArray, ore: PackedByteArray, start: int, size: int,
		width: int, radius: int, rng: RandomNumberGenerator) -> Array[int]:
	var vein: Array[int] = [start]
	var tries: int = 0
	while vein.size() < size and tries < size * 12:
		tries += 1
		var from: int = vein[rng.randi_range(0, vein.size() - 1)]
		var step: int = [1, -1, width, -width][rng.randi_range(0, 3)]
		var next: int = from + step
		if next < 0 or next >= top.size() or vein.has(next): continue
		# A step off the row's end would wrap to the next row
		if absi(step) == 1 and next / width != from / width: continue
		var x: int = next % width - radius
		var y: int = next / width - radius
		if x * x + y * y > radius * radius: continue
		if top[next] != TileKind.TOP.MINABLE_ROCK or ore[next] != TileKind.ORE.NONE: continue
		vein.append(next)
	return vein
