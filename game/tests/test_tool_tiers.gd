extends GutTest

# Slice 016's things worth carrying: the new items, tools in three
# tiers (D-244), coal on -2 (D-239), the hand recipes for flint tools,
# and -3's floor refused whatever the tool (D-251).

const Worlds = preload("res://tests/worlds.gd")

var _tuning: TuningProfile


func before_each() -> void:
	_tuning = TuningProfile.default_profile()


func _player(world: World, at: WorldPos) -> Actor:
	world.level_at(at.depth).level_tiles.set_top(at.x, at.y, TileKind.TOP.OPEN)
	var actor: Actor = Actor.create(Global.actor_packed_scene, "P", at, world.level_at(at.depth),
		ActorKind.ACTOR.PLAYER)
	world.add_actor(actor)
	return actor


# --- the items (tuning §3) ---

func test_every_new_item_has_its_weight_and_an_icon() -> void:
	var weights: Dictionary = {&"coal": 4.0, &"copper_ingot": 4.0, &"tin_ingot": 4.0,
		&"bronze_ingot": 4.0, &"iron_ingot": 5.0, &"cave_fungus": 0.4, &"lamp_oil": 0.8,
		&"lantern": 2.0}
	for id: StringName in weights:
		var item: Item = ItemRegistry.find(id)
		assert_not_null(item, "%s exists" % id)
		if item == null: continue
		assert_almost_eq(item.weight_kg, weights[id], 0.001, "%s weighs %.1f kg" % [id, weights[id]])
		assert_not_null(item.icon, "%s has an icon" % id)
	assert_true(Hotbar.LIGHT_TAG in ItemRegistry.find(&"lantern").tags, "the lantern is a light")


func test_each_tier_has_a_pick_an_axe_and_a_shovel() -> void:
	var powers: Dictionary = {"flint": 16.0, "bronze": 30.0, "iron": 55.0}
	var classes: Dictionary = {"pickaxe": ToolData.CLASS.PICK, "axe": ToolData.CLASS.AXE,
		"shovel": ToolData.CLASS.SHOVEL}
	for tier: String in powers:
		for kind: String in classes:
			var id: StringName = StringName("%s_%s" % [tier, kind])
			var item: Item = ItemRegistry.find(id)
			assert_not_null(item, "%s exists" % id)
			if item == null: continue
			assert_true(item.is_tool(), "%s is a tool" % id)
			assert_eq(item.tool.power, powers[tier], "%s's power" % id)
			assert_eq(item.tool.tool_class, classes[kind], "%s's class" % id)


# --- the recipes (D-244, D-245, D-246) ---

func test_flint_tools_are_made_by_hand_from_stone_and_timber() -> void:
	for kind: String in ["pickaxe", "axe", "shovel"]:
		var recipe: Recipe = RecipeRegistry.find(StringName("flint_" + kind))
		assert_not_null(recipe, "flint %s" % kind)
		if recipe == null: continue
		assert_eq(recipe.station, Recipe.HAND, "by hand")
		assert_eq(recipe.inputs, {&"stone": 3, &"timber": 1} as Dictionary[StringName, int],
			"3 stone + 1 timber")


func test_bronze_tools_are_made_at_the_workbench_and_iron_at_the_forge() -> void:
	var ingots: Dictionary = {"pickaxe": 4, "axe": 3, "shovel": 2}
	for tier: String in ["bronze", "iron"]:
		for kind: String in ingots:
			var recipe: Recipe = RecipeRegistry.find(StringName("%s_%s" % [tier, kind]))
			assert_not_null(recipe, "%s %s" % [tier, kind])
			if recipe == null: continue
			assert_eq(recipe.station, &"workbench" if tier == "bronze" else &"forge",
				"%s %s's station" % [tier, kind])
			var cost: Dictionary[StringName, int] = {StringName(tier + "_ingot"): ingots[kind],
				&"timber": 1}
			assert_eq(recipe.inputs, cost, "%s %s's cost" % [tier, kind])


func test_the_workbench_presses_oil_and_makes_the_lantern() -> void:
	var oil: Recipe = RecipeRegistry.find(&"lamp_oil")
	assert_eq(oil.station, &"workbench")
	assert_eq(oil.inputs, {&"cave_fungus": 3} as Dictionary[StringName, int], "3 fungus")
	assert_eq(oil.outputs, {&"lamp_oil": 1} as Dictionary[StringName, int], "1 oil")
	var lantern: Recipe = RecipeRegistry.find(&"lantern")
	assert_eq(lantern.station, &"workbench")
	assert_eq(lantern.inputs, {&"copper_ingot": 2, &"timber": 1} as Dictionary[StringName, int])


func test_the_hand_list_is_in_id_order() -> void:
	var ids: Array = RecipeRegistry.at_station(Recipe.HAND).map(
		func(r: Recipe) -> String: return String(r.id))
	var sorted: Array = ids.duplicate()
	sorted.sort()
	assert_eq(ids, sorted, "alphabetical")


func test_a_flint_pick_is_made_from_the_starting_timber() -> void:
	var world: World = autofree(Worlds.with_levels([0]))
	var actor: Actor = _player(world, WorldPos.new(0, 0, 0))
	actor.pack.add(&"timber", 2)
	actor.pack.add(&"stone", 6)
	world.craft_requested.emit(actor, &"flint_axe")
	world.craft_requested.emit(actor, &"flint_pickaxe")
	assert_eq(actor.pack.count_of(&"flint_axe"), 1, "an axe")
	assert_eq(actor.pack.count_of(&"flint_pickaxe"), 1, "a pick")
	assert_eq(actor.pack.count_of(&"timber"), 0, "both timber used")
	assert_eq(actor.pack.count_of(&"stone"), 0, "and the stone")
	assert_eq(actor.tool(), ItemRegistry.find(&"flint_axe").tool, "the first tool made is in hand")


# --- the gates (D-217, tuning §4) ---

func test_bronze_digs_iron_and_flint_does_not() -> void:
	var iron: int = TileKind.ORE.IRON
	assert_false(Digging.digs_ore(_tuning, ItemRegistry.find(&"flint_pickaxe").tool, iron), "flint")
	assert_true(Digging.digs_ore(_tuning, ItemRegistry.find(&"bronze_pickaxe").tool, iron), "bronze")
	assert_true(Digging.digs_ore(_tuning, ItemRegistry.find(&"iron_pickaxe").tool, iron), "iron")


func test_each_tier_digs_faster() -> void:
	var rock: int = TileKind.TOP.MINABLE_ROCK
	var flint: float = Digging.dig_power(_tuning, ItemRegistry.find(&"flint_pickaxe").tool, rock)
	var bronze: float = Digging.dig_power(_tuning, ItemRegistry.find(&"bronze_pickaxe").tool, rock)
	var iron: float = Digging.dig_power(_tuning, ItemRegistry.find(&"iron_pickaxe").tool, rock)
	assert_true(flint < bronze and bronze < iron, "%.0f < %.0f < %.0f" % [flint, bronze, iron])


func test_bronze_breaches_minus_twos_floor_and_flint_does_not() -> void:
	var floor_hardness: float = Digging.floor_hardness(_tuning, 2)
	assert_false(Digging.can_breach(_tuning, floor_hardness, 16.0), "flint")
	assert_true(Digging.can_breach(_tuning, floor_hardness, 30.0), "bronze")


func test_minus_threes_floor_is_refused_whatever_the_tool() -> void:
	var world: World = autofree(Worlds.with_levels([3, 4]))
	var tile: WorldPos = WorldPos.new(0, 0, 3)
	world.level_at(3).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	world.level_at(4).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	assert_eq(world.breach_problem(tile, 1000.0), World.BREACH_REFUSAL.TOO_DEEP, "too deep")
	assert_true(RefusalNotice.BREACH_REASONS.has(World.BREACH_REFUSAL.TOO_DEEP), "and says why")


func test_minus_twos_floor_is_not_too_deep() -> void:
	var world: World = autofree(Worlds.with_levels([2, 3]))
	world.level_at(2).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	world.level_at(3).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	assert_eq(world.breach_problem(WorldPos.new(0, 0, 2), 30.0), World.BREACH_REFUSAL.NONE,
		"bronze opens it")


# --- coal (D-239) ---

func test_coal_is_on_minus_two_and_nowhere_above() -> void:
	var world: World = autofree(Worlds.generated(3))
	world.generate_below(1)
	var counts: Dictionary[int, int] = {}
	for depth: int in [0, 1, 2]:
		var tiles: LevelTiles = world.level_at(depth).level_tiles
		var found: int = 0
		var radius: int = tiles.level_bound.radius
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if tiles.get_ore(x, y) == TileKind.ORE.COAL: found += 1
		counts[depth] = found
	assert_eq(counts[0], 0, "none on the Surface")
	assert_eq(counts[1], 0, "none on -1")
	assert_gt(counts[2], 20, "veins on -2")


func test_mining_coal_yields_coal() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var found: Dictionary[StringName, int] = Digging.yield_of(_tuning, TileKind.TOP.MINABLE_ROCK,
		TileKind.ORE.COAL, rng)
	assert_true(found.has(&"coal"), "coal")
	assert_between(found.get(&"coal", 0), _tuning.ore_yield_min, _tuning.ore_yield_max)
