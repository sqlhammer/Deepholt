class_name LevelGenerator
extends RefCounted

# Builds the levels from their recipes (D-084): fixed placements first,
# then -- once they exist -- rules, then validation. Returns levels not
# yet in the tree; the caller decides where they live.
#
# Anything random in generation draws from the level's own generator,
# never the global randi(), and never depends on node or dictionary
# iteration order, so the same world seed always builds the same world
# (NOW.md trap 8). Fixed placements use no randomness.


static func generate_levels(recipes: LevelRecipeTable) -> Array[Level]:
	# A new world: fixture ids start again, so the same seed gives the
	# same ids even when one process builds several worlds (D-104).
	Objects.reset_ids()
	var levels: Array[Level] = []
	for recipe: LevelRecipe in recipes.rows:
		levels.append(generate_level(recipe))
	for problem: String in ramp_problems(levels) + ladder_problems(levels):
		push_error(problem)
	return levels


# Every ladder needs a hole directly above it, on the level one depth up
# (D-089). A hole with no ladder is legal. Checked once every level is
# built, since the two ends are in different prefabs. A ladder outside
# the upper level's bounds reads a sentinel there, not a hole, so it is
# reported the same way.
static func ladder_problems(levels: Array[Level]) -> Array[String]:
	var by_depth: Dictionary[int, Level] = {}
	for level: Level in levels:
		by_depth[level.depth] = level

	var problems: Array[String] = []
	for level: Level in levels:
		for ladder: Fixture in level.level_fixtures.of_kind(ObjectKind.OBJECT.LADDER):
			var where: String = "Ladder at (%d, %d) depth %d" % [ladder.tile.x, ladder.tile.y, level.depth]
			var above: int = level.depth - 1
			if not by_depth.has(above):
				problems.append("%s has no level above it." % where)
			elif by_depth[above].level_tiles.get_ground(ladder.tile.x, ladder.tile.y) != TileKind.GROUND.HOLE:
				problems.append("%s has no hole above it at depth %d." % [where, above])
	return problems


# Every ramp end needs its other end at the same (x, y) one level
# away, both under open tops (D-095). Checked on world tiles after
# every level is stamped, since a pair spans two prefabs (NOW.md
# trap 4). A ramp outside the other level's bounds has no other end
# there, so it is reported the same way.
static func ramp_problems(levels: Array[Level]) -> Array[String]:
	var by_depth: Dictionary[int, Level] = {}
	for level: Level in levels:
		by_depth[level.depth] = level

	var problems: Array[String] = []
	for level: Level in levels:
		for kind: int in TileKind.RAMPS:
			for tile: Vector2i in _tiles_with_ground(level.level_tiles, kind):
				var problem: String = _ramp_problem(by_depth, level.depth, tile, kind)
				if problem != "": problems.append(problem)
	return problems


static func _ramp_problem(by_depth: Dictionary[int, Level], depth: int, tile: Vector2i, kind: int) -> String:
	var name: String = "%s at (%d, %d) depth %d" % [
		TileKind.GROUND.find_key(kind), tile.x, tile.y, depth]
	if by_depth[depth].level_tiles.get_top(tile.x, tile.y) != TileKind.TOP.OPEN:
		return "%s is under a solid top." % name

	var other_depth: int = depth + 1 if TileKind.RAMPS[kind].down else depth - 1
	if not by_depth.has(other_depth):
		return "%s leads to depth %d, which has no level." % [name, other_depth]
	var pair: int = TileKind.ramp_pair(kind)
	if by_depth[other_depth].level_tiles.get_ground(tile.x, tile.y) != pair:
		return "%s has no %s at depth %d." % [
			name, TileKind.GROUND.find_key(pair), other_depth]
	return ""


# Tiles whose ground is `kind`, found with the array's own find so
# scanning every level stays fast.
static func _tiles_with_ground(tiles: LevelTiles, kind: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var radius: int = tiles.level_bound.radius
	var width: int = 2 * radius + 1
	var index: int = tiles.ground.find(kind)
	while index != -1:
		found.append(Vector2i(index % width - radius, index / width - radius))
		index = tiles.ground.find(kind, index + 1)
	return found


# The level's one source of randomness is made here, once, and handed
# to each step that needs it in a fixed order. Two steps each calling
# rng_for() would get the same sequence and correlated results.
static func generate_level(recipe: LevelRecipe) -> Level:
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(recipe.bound.depth)
	var rng: RandomNumberGenerator = rng_for(level)
	apply_fixed_placements(level, recipe)
	place_world_spawns(level, recipe, rng)
	return level


# For a placement with a spawn radius, places the world's default spawn
# (D-091, D-105): a random tile within the radius (a disc, like the
# level bounds) of the placement's anchor, where an actor could stand,
# that isn't a ramp, and that the fixture rules allow. Candidates are
# gathered row by row, then column, so the same seed picks the same
# tile. No candidate is reported, and nothing is placed.
static func place_world_spawns(level: Level, recipe: LevelRecipe, rng: RandomNumberGenerator) -> void:
	for placement: PrefabPlacement in recipe.fixed_placements:
		if placement.spawn_radius <= 0: continue
		var candidates: Array[Vector2i] = spawn_candidates(level, placement.anchor, placement.spawn_radius)
		if candidates.is_empty():
			push_error("No tile for the world spawn within %d of %s at depth %d." % [
				placement.spawn_radius, placement.anchor, level.depth])
			continue
		var tile: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		level.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.WORLD_SPAWN,
			WorldPos.new(tile.x, tile.y, level.depth), Objects.next_id()))


static func spawn_candidates(level: Level, center: Vector2i, radius: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var tiles: LevelTiles = level.level_tiles
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius: continue
			var tile: Vector2i = center + Vector2i(dx, dy)
			if TileKind.is_ramp(tiles.get_ground(tile.x, tile.y)): continue
			# Generation has no level above at hand; a world spawn
			# doesn't need one.
			var problem: int = Objects.placement_problem(ObjectKind.OBJECT.WORLD_SPAWN,
				tile, tiles, level.level_fixtures, null)
			if problem == Objects.REFUSAL_REASON.NONE:
				candidates.append(tile)
	return candidates


# Stamps each of the recipe's fixed prefabs. A recipe naming a prefab
# that doesn't exist, or one that fails to stamp, is an authoring
# error: it is reported, and the rest of the recipe still applies.
# Returns false if any placement failed.
static func apply_fixed_placements(level: Level, recipe: LevelRecipe) -> bool:
	var all_placed: bool = true
	for placement: PrefabPlacement in recipe.fixed_placements:
		var prefab: TilePrefab = TilePrefabRegistry.get_prefab(placement.prefab_id)
		if prefab == null:
			push_error("Recipe for depth %d names missing prefab '%s'." % [
				recipe.bound.depth, placement.prefab_id])
			all_placed = false
			continue
		if not LevelGridLoader.stamp(level.level_tiles, prefab, placement.anchor, level.level_fixtures):
			push_error("Prefab '%s' failed to stamp at depth %d." % [
				placement.prefab_id, recipe.bound.depth])
			all_placed = false
	return all_placed


# The only source of randomness for generating this level: seeded from
# the level's own seed, so each depth gets its own repeatable sequence.
static func rng_for(level: Level) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = level.level_seed
	return rng
















