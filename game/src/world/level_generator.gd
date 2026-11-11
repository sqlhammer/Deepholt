class_name LevelGenerator
extends RefCounted

# Builds a world from its recipes (D-084, D-127): fixed placements
# first, then -- once they exist -- rules, then validation. Returns a
# World not yet in the tree; the caller decides where it lives.
#
# Anything random in generation draws from the level's own generator,
# never the global randi(), and never depends on node or dictionary
# iteration order, so the same world seed always builds the same world
# (NOW.md trap 8). Fixed placements use no randomness.


# A new world for a seed, with a level per recipe and its own fresh
# id counters, so the same seed gives the same fixture ids however
# many worlds one process builds (D-104, D-118).
static func generate_world(world_seed: int, tuning: TuningProfile = null) -> World:
	var world: World = World.new(tuning)
	world.world_seed = world_seed
	
	if not tuning: tuning = TuningProfile.default_profile()
	for depth in tuning.levels_to_generate_on_new_game:
		generate_into(world, depth)
	
	var levels: Array[Level] = world.levels()
	for problem: String in ramp_problems(levels) + ladder_problems(levels):
		push_error(problem)
	return world


# Every ladder needs a hole directly above it, on the level one depth
# up (D-089). A hole with no ladder is legal. Checked once every level
# is built, since the two ends are in different prefabs. A ladder
# outside the upper level's bounds reads a sentinel there, not a hole,
# so it is reported the same way.
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


# The cross-level problems between two adjacent levels, for a level
# generated below one that exists (D-143): ramps between them, and the
# lower level's ladders against the upper level's holes. Ladders on
# the upper level answer to the level above it, checked when the
# upper level was itself generated.
static func problems_between(upper: Level, lower: Level) -> Array[String]:
	var problems: Array[String] = ramp_problems([upper, lower] as Array[Level])
	for ladder: Fixture in lower.level_fixtures.of_kind(ObjectKind.OBJECT.LADDER):
		if upper.level_tiles.get_ground(ladder.tile.x, ladder.tile.y) != TileKind.GROUND.HOLE:
			problems.append("Ladder at (%d, %d) depth %d has no hole above it at depth %d." % [
				ladder.tile.x, ladder.tile.y, lower.depth, upper.depth])
	return problems


# Every ramp end needs its other end at the same (x, y) one level
# away, both under open tops (D-095). Checked on world tiles after
# every level is stamped, since a pair spans two prefabs (NOW.md
# trap 4). A ramp outside the other level's bounds has no other end
# there, so it is reported the same way. A ramp whose other level
# isn't among `levels` is skipped: levels are generated one ahead of
# arrival (D-143), so the deepest one's way down leads to a level that
# doesn't exist yet. The pair is checked when that level arrives.
static func ramp_problems(levels: Array[Level]) -> Array[String]:
	var by_depth: Dictionary[int, Level] = {}
	for level: Level in levels:
		by_depth[level.depth] = level

	var problems: Array[String] = []
	for level: Level in levels:
		for kind: int in TileKind.RAMPS:
			for tile: Vector2i in tiles_with_ground(level.level_tiles, kind):
				var problem: String = _ramp_problem(by_depth, level.depth, tile, kind)
				if problem != "": problems.append(problem)
	return problems


static func _ramp_problem(by_depth: Dictionary[int, Level], depth: int, tile: Vector2i, kind: int) -> String:
	var name: String = "%s at (%d, %d) depth %d" % [
		TileKind.GROUND.find_key(kind), tile.x, tile.y, depth]
	if by_depth[depth].level_tiles.get_top(tile.x, tile.y) != TileKind.TOP.OPEN:
		return "%s is under a solid top." % name

	var other_depth: int = depth + 1 if TileKind.RAMPS[kind].down else depth - 1
	if not by_depth.has(other_depth): return ""
	var pair: int = TileKind.ramp_pair(kind)
	if by_depth[other_depth].level_tiles.get_ground(tile.x, tile.y) != pair:
		return "%s has no %s at depth %d." % [
			name, TileKind.GROUND.find_key(pair), other_depth]
	return ""


# Generation guarantee 2 (world-and-generation §3, D-229): every ramp
# down on a level can be walked to from its landing. A ramp counts as
# reached when the tile on its open side is. One problem per ramp that
# can't be.
static func descent_problems(level: Level, landing: Vector2i) -> Array[String]:
	var problems: Array[String] = []
	var reached: Dictionary[Vector2i, bool] = walkable_from(level.level_tiles, landing)
	for kind: int in TileKind.RAMPS:
		if not TileKind.RAMPS[kind].down: continue
		for tile: Vector2i in tiles_with_ground(level.level_tiles, kind):
			if not reached.has(tile + TileKind.ramp_open_side(kind)):
				problems.append("The ramp down at (%d, %d) depth %d can't be walked to from %s." % [
					tile.x, tile.y, level.depth, landing])
	return problems


# Every tile reached on foot from `start`, edge to edge, through
# passable tiles.
static func walkable_from(tiles: LevelTiles, start: Vector2i) -> Dictionary[Vector2i, bool]:
	var reached: Dictionary[Vector2i, bool] = {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var at: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + step
			if reached.has(next): continue
			if not TileKind.is_passable(tiles.get_top(next.x, next.y), tiles.get_ground(next.x, next.y)):
				continue
			reached[next] = true
			frontier.append(next)
	return reached


# Tiles whose ground is `kind`, found with the array's own find so
# scanning every level stays fast.
static func tiles_with_ground(tiles: LevelTiles, kind: int) -> Array[Vector2i]:
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
# `fixture_ids` is the counter of the world the level is built for.
# `tuning` is the profile of the world it's for; the default without
# one. `above` is the level one depth up, where there is one: a level
# reached by a ramp stamps its arrival under the ramp's down end
# (D-216).
static func generate_level(recipe: LevelRecipe, world_seed: int, fixture_ids: IdAllocator,
		tuning: TuningProfile = null, above: Level = null) -> Level:
	if tuning == null: tuning = TuningProfile.default_profile()
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(recipe.bound.depth, world_seed, recipe.bound)
	var rng: RandomNumberGenerator = rng_for(level)
	var surface: SurfaceGeneration.Layout = null
	if recipe.generator == &"surface": surface = SurfaceGeneration.before(level, rng, tuning)
	apply_fixed_placements(level, recipe, fixture_ids)
	if surface != null: SurfaceGeneration.after(level, surface, rng, tuning, fixture_ids)
	# The ways in and down before anything natural, so caves, regions
	# and ore keep to the rock around them
	var landings: Array[Vector2i] = DescentGeneration.place_arrivals(level, recipe, above, fixture_ids)
	if not recipe.fixed_placements.is_empty(): landings.append(DescentGeneration.landing_of(recipe))
	var chamber: Rect2i = DescentGeneration.place_descent(level, recipe, rng, tuning)
	if chamber.has_area():
		landings.append(chamber.get_center())
		for problem: String in descent_problems(level, DescentGeneration.landing_of(recipe)):
			push_error(problem)
	RegionGeneration.place_crushed(level, recipe, rng, tuning, landings)
	# Caves before ore, so veins run in the rock around them (trap 4)
	RockGeneration.place_caves(level, recipe, rng, tuning)
	RockGeneration.place_veins(level, rng, tuning)
	place_world_spawns(level, recipe, rng, fixture_ids)
	return level


# "already there" and "nothing below the deepest" are normal.
# Their checks need handling by the caller, not here.
# Only crash protection has been implemented
static func generate_into(world: World, depth: int) -> Level:
	if not world: return null
	
	var recipe: LevelRecipe = LevelRecipes.TABLE.get_recipe(depth)
	if not recipe: return null
	
	var level: Level = generate_level(recipe, world.world_seed, world.fixture_ids, world.tuning,
		world.level_at(depth - 1))
	world.add_level(level)
	
	return level


# For a placement with a spawn radius, places the world's default
# spawn (D-091, D-105): a random tile within the radius (a disc, like
# the level bounds) of the placement's anchor, where an actor could
# stand, that isn't a ramp, and that the fixture rules allow.
# Candidates are gathered row by row, then column, so the same seed
# picks the same tile. No candidate is reported, and nothing is
# placed.
static func place_world_spawns(level: Level, recipe: LevelRecipe, rng: RandomNumberGenerator,
		fixture_ids: IdAllocator) -> void:
	for placement: PrefabPlacement in recipe.fixed_placements:
		if placement.spawn_radius <= 0: continue
		var candidates: Array[Vector2i] = spawn_candidates(level, placement.anchor, placement.spawn_radius)
		if candidates.is_empty():
			push_error("No tile for the world spawn within %d of %s at depth %d." % [
				placement.spawn_radius, placement.anchor, level.depth])
			continue
		var tile: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		level.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.WORLD_SPAWN,
			WorldPos.new(tile.x, tile.y, level.depth), fixture_ids.allocate()))


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
			var problem: World.FIXTURE_REFUSAL = FixturePlacement.problem(
				ObjectKind.OBJECT.WORLD_SPAWN, tile, tiles, level.level_fixtures, null)
			if problem == World.FIXTURE_REFUSAL.NONE:
				candidates.append(tile)
	return candidates


# Stamps each of the recipe's fixed prefabs. A recipe naming a prefab
# that doesn't exist, or one that fails to stamp, is an authoring
# error: it is reported, and the rest of the recipe still applies.
# Returns false if any placement failed.
static func apply_fixed_placements(level: Level, recipe: LevelRecipe,
		fixture_ids: IdAllocator) -> bool:
	var all_placed: bool = true
	for placement: PrefabPlacement in recipe.fixed_placements:
		var prefab: TilePrefab = TilePrefabRegistry.get_prefab(placement.prefab_id)
		if prefab == null:
			push_error("Recipe for depth %d names missing prefab '%s'." % [
				recipe.bound.depth, placement.prefab_id])
			all_placed = false
			continue
		if not LevelGridLoader.stamp(level.level_tiles, prefab, placement.anchor,
				level.level_fixtures, fixture_ids):
			push_error("Prefab '%s' failed to stamp at depth %d." % [
				placement.prefab_id, recipe.bound.depth])
			all_placed = false
	return all_placed


# The only source of randomness for generating this level: seeded from
# the level's own seed, so each depth gets its own repeatable
# sequence.
static func rng_for(level: Level) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = level.level_seed
	return rng













