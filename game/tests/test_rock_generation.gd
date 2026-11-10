extends GutTest

# What's in the rock below (D-183, D-184, D-187): two or three natural
# caves on each of -1 and -2, sealed in rock, apart from the fixed
# rooms and each other, never judged; copper and tin in small veins on
# -2 only, near the profile's shares; and the art to show tin and the
# Surface's grass.

const Worlds = preload("res://tests/worlds.gd")

var _tuning: TuningProfile


func before_each() -> void:
	_tuning = TuningProfile.default_profile()


func _level(depth: int, world_seed: int = 0) -> Level:
	return autofree(LevelGenerator.generate_level(LevelRecipes.TABLE.get_recipe(depth), world_seed,
		IdAllocator.new()))


func _count_ore(level: Level, kind: int) -> int:
	return level.level_tiles.ore.count(kind)


func _rock(level: Level) -> int:
	var radius: int = level.level_tiles.level_bound.radius
	return RockGeneration._rock_indices(level.level_tiles.top, radius).size()


# --- tin ---

func test_tin_is_an_ore_with_an_item() -> void:
	assert_eq(Digging.ORE_ITEMS[TileKind.ORE.TIN], &"tin_ore", "mined as tin ore")
	var tin: Item = ItemRegistry.get_item(&"tin_ore")
	assert_eq(tin.weight_kg, 5.0, "the appendix's 5 kg")
	assert_eq(tin.trade_value, 6.0, "as copper")
	assert_not_null(tin.icon, "with an icon")
	assert_eq(LevelGridLoader.ORE_CHARS["t"], TileKind.ORE.TIN, "prefabs can hold it")


func test_tin_and_grass_have_art() -> void:
	var renderer: LevelRenderer = autofree(LevelRenderer.new())
	assert_eq(renderer._ore_cells()[TileKind.ORE.TIN], LevelRenderer.AtlasCell.TIN, "tin's cell")
	assert_eq(renderer._ground_cells()[TileKind.GROUND.GRASS], LevelRenderer.AtlasCell.GRASS_FLOOR,
		"grass's cell, not MISSING")
	var atlas: Texture2D = load("res://src/render/tile_atlas.png")
	assert_eq(atlas.get_width(), 16 * LevelRenderer.AtlasCell.size(), "a cell per entry")


# --- caves (D-184) ---

func test_minus_one_and_minus_two_have_two_or_three_sealed_caves() -> void:
	for depth: int in [1, 2]:
		for world_seed: int in [0, 1, 2]:
			var level: Level = _level(depth, world_seed)
			var caves: Array[Rect2i] = _caves(depth, world_seed)
			assert_between(caves.size(), 2, 3, "depth %d seed %d: %d caves" % [
				depth, world_seed, caves.size()])
			for cave: Rect2i in caves:
				assert_true(_ringed_by_rock(level, cave), "depth %d: %s sealed" % [depth, cave])


func test_caves_keep_clear_of_the_fixed_rooms_and_each_other() -> void:
	for depth: int in [1, 2]:
		var recipe: LevelRecipe = LevelRecipes.TABLE.get_recipe(depth)
		var fixed: Rect2i = RockGeneration.footprint(
			TilePrefabRegistry.get_prefab(recipe.fixed_placements[0].prefab_id),
			recipe.fixed_placements[0].anchor)
		var caves: Array[Rect2i] = _caves(depth, 0)
		for i in range(caves.size()):
			assert_false(caves[i].intersects(fixed.grow(_tuning.cave_spacing)),
				"depth %d: cave %d clear of the room" % [depth, i])
			for j in range(i + 1, caves.size()):
				assert_false(caves[i].intersects(caves[j].grow(_tuning.cave_spacing)),
					"depth %d: caves %d and %d apart" % [depth, i, j])


func test_deeper_levels_have_no_caves_yet() -> void:
	assert_eq(LevelRecipes.TABLE.get_recipe(3).cave_prefabs.size(), 0, "-3: none")
	assert_eq(LevelRecipes.TABLE.get_recipe(0).cave_prefabs.size(), 0, "the Surface: none")


func test_caves_are_natural_so_never_judged() -> void:
	var world: World = autofree(LevelGenerator.generate_world(0))
	var level: Level = world.level_at(1)
	assert_eq(level.level_tiles.excavated_tiles(), [] as Array[Vector2i], "nothing marked dug")
	assert_eq(level.support.judged_tiles().size(), 0, "nothing judged")


# A fresh generation's cave rects, for a depth and seed.
func _caves(depth: int, world_seed: int) -> Array[Rect2i]:
	var recipe: LevelRecipe = LevelRecipes.TABLE.get_recipe(depth)
	var level: Level = autofree(Global.level_packed_scene.instantiate())
	level.setup(depth, world_seed, recipe.bound)
	var rng: RandomNumberGenerator = LevelGenerator.rng_for(level)
	LevelGenerator.apply_fixed_placements(level, recipe, IdAllocator.new())
	return RockGeneration.place_caves(level, recipe, rng, _tuning)


# Every tile on the rect's edge is rock: the open hollow inside can't
# be walked into without digging.
func _ringed_by_rock(level: Level, rect: Rect2i) -> bool:
	for x in range(rect.position.x, rect.end.x):
		for y: int in [rect.position.y, rect.end.y - 1]:
			if level.level_tiles.get_top(x, y) != TileKind.TOP.MINABLE_ROCK: return false
	for y in range(rect.position.y, rect.end.y):
		for x: int in [rect.position.x, rect.end.x - 1]:
			if level.level_tiles.get_top(x, y) != TileKind.TOP.MINABLE_ROCK: return false
	return true


# --- ore (D-183, D-187) ---

func test_minus_one_has_no_metal_ore() -> void:
	for world_seed: int in [0, 1, 2]:
		var level: Level = _level(1, world_seed)
		assert_eq(_count_ore(level, TileKind.ORE.COPPER), 0, "no copper, seed %d" % world_seed)
		assert_eq(_count_ore(level, TileKind.ORE.TIN), 0, "no tin, seed %d" % world_seed)


func test_minus_two_has_copper_and_tin_near_the_profiles_shares() -> void:
	var level: Level = _level(2)
	var rock: int = _rock(level)
	var copper: float = float(_count_ore(level, TileKind.ORE.COPPER)) / rock
	var tin: float = float(_count_ore(level, TileKind.ORE.TIN)) / rock
	assert_almost_eq(copper, 0.03, 0.005, "about 3%% copper: %.4f" % copper)
	assert_almost_eq(tin, 0.02, 0.005, "about 2%% tin: %.4f" % tin)


func test_ore_lies_only_in_minable_rock_and_comes_in_veins() -> void:
	var level: Level = _level(2)
	var tiles: LevelTiles = level.level_tiles
	var ore: PackedByteArray = tiles.ore
	var top: PackedByteArray = tiles.top
	var radius: int = tiles.level_bound.radius
	var width: int = 2 * radius + 1
	var outside: int = 0
	var alone: int = 0
	var total: int = 0
	for index in range(ore.size()):
		var kind: int = ore[index]
		if kind != TileKind.ORE.COPPER and kind != TileKind.ORE.TIN: continue
		total += 1
		if top[index] != TileKind.TOP.MINABLE_ROCK: outside += 1
		var neighbors: int = 0
		for step: int in [1, -1, width, -width]:
			var next: int = index + step
			if next >= 0 and next < ore.size() and ore[next] == kind: neighbors += 1
		if neighbors == 0: alone += 1
	assert_eq(outside, 0, "ore only in minable rock")
	assert_lt(float(alone) / total, 0.15, "nearly every ore tile has its kind beside it: veins")


func test_the_same_seed_lays_the_same_ore() -> void:
	assert_true(_level(2, 5).level_tiles.ore == _level(2, 5).level_tiles.ore, "same seed")
	assert_false(_level(2, 5).level_tiles.ore == _level(2, 6).level_tiles.ore, "another seed")


func test_digging_tin_yields_tin_ore() -> void:
	var world: World = autofree(Worlds.with_levels([2], 3))
	world.level_at(2).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	world.level_at(2).level_tiles.set_ore(0, 1, TileKind.ORE.TIN)
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Miner", WorldPos.new(0, 0, 2),
		world.level_at(2), ActorKind.ACTOR.PLAYER)
	world.add_actor(actor)
	world.dig_requested.emit(actor, WorldPos.new(0, 1, 2))
	assert_between(actor.pack.count_of(&"tin_ore"), 2, 4, "2-4 tin ore")
