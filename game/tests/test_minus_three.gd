extends GutTest

# Level -3, the Old Terraces (D-215 to D-218, D-229): reached by a ramp
# the seed places on -2 at the end of a carved tunnel; caves, iron in
# veins that flint can't dig, and one CRUSHED region of rubble that no
# tool clears, each refusal with its reason.

const Worlds = preload("res://tests/worlds.gd")
const SEEDS: Array[int] = [0, 1, 2, 3, 4, 5]

var _tuning: TuningProfile
# One world down to -3 per seed, built once for the file (trap 8:
# generating -3 is the slow part). Tests only read them.
var _worlds: Dictionary[int, World] = {}


func before_each() -> void:
	_tuning = TuningProfile.default_profile()


func after_all() -> void:
	for world: World in _worlds.values():
		world.free()
	_worlds.clear()


# A generated world down to -3, as a player arriving on -2 grows it.
func _world_to_minus_three(world_seed: int) -> World:
	if _worlds.has(world_seed): return _worlds[world_seed]
	var world: World = LevelGenerator.generate_world(world_seed)
	world.generate_below(1)
	world.generate_below(2)
	# In the tree, so GUT doesn't count it an orphan between tests
	add_child(world)
	_worlds[world_seed] = world
	return world


func _ramps(level: Level, kind: int) -> Array[Vector2i]:
	return LevelGenerator.tiles_with_ground(level.level_tiles, kind)


# --- the way down (D-215, D-229) ---

func test_minus_two_has_one_ramp_down_far_from_its_landing() -> void:
	for world_seed: int in SEEDS:
		var world: World = _world_to_minus_three(world_seed)
		var ramps: Array[Vector2i] = _ramps(world.level_at(2), TileKind.GROUND.RAMP_DOWN_E)
		assert_eq(ramps.size(), 1, "seed %d: one ramp down" % world_seed)
		if ramps.is_empty(): continue
		var landing: Vector2i = DescentGeneration.landing_of(LevelRecipes.TABLE.get_recipe(2))
		# The chamber's anchor is 40 to 60 out; its ramp sits 5 east of it
		var distance: float = Vector2(ramps[0] - landing).length()
		assert_between(distance, _tuning.descent_distance_min - 6.0,
			_tuning.descent_distance_max + 6.0, "seed %d: %.0f tiles out" % [world_seed, distance])


func test_the_ramp_down_is_walked_to_from_the_landing() -> void:
	for world_seed: int in SEEDS:
		var world: World = _world_to_minus_three(world_seed)
		var landing: Vector2i = DescentGeneration.landing_of(LevelRecipes.TABLE.get_recipe(2))
		assert_eq(LevelGenerator.descent_problems(world.level_at(2), landing), [] as Array[String],
			"seed %d: walkable" % world_seed)


# Where the player really arrives on -2 is under -1's hole (14, -2).
func test_the_ramp_down_is_walked_to_from_under_minus_ones_hole() -> void:
	for world_seed: int in SEEDS:
		var world: World = _world_to_minus_three(world_seed)
		assert_eq(LevelGenerator.descent_problems(world.level_at(2), Vector2i(14, -2)),
			[] as Array[String], "seed %d" % world_seed)


func test_the_tunnel_is_natural_so_never_judged() -> void:
	var world: World = _world_to_minus_three(0)
	assert_eq(world.level_at(2).level_tiles.excavated_tiles().size(), 0, "nothing excavated")


func test_minus_three_has_the_ramp_up_on_the_same_tile() -> void:
	for world_seed: int in SEEDS:
		var world: World = _world_to_minus_three(world_seed)
		var down: Array[Vector2i] = _ramps(world.level_at(2), TileKind.GROUND.RAMP_DOWN_E)
		var up: Array[Vector2i] = _ramps(world.level_at(3), TileKind.GROUND.RAMP_UP_E)
		assert_eq(up, down, "seed %d: shared origin" % world_seed)
		assert_eq(LevelGenerator.ramp_problems(world.levels()), [] as Array[String],
			"seed %d: the pair checks clean" % world_seed)


func test_the_arrival_room_is_open_with_a_brazier() -> void:
	var world: World = _world_to_minus_three(0)
	var level: Level = world.level_at(3)
	var up: Vector2i = _ramps(level, TileKind.GROUND.RAMP_UP_E)[0]
	var room: Dictionary[Vector2i, bool] = LevelGenerator.walkable_from(level.level_tiles,
		up + TileKind.ramp_open_side(TileKind.GROUND.RAMP_UP_E))
	assert_gt(room.size(), 20, "a room to stand in")
	assert_eq(level.level_fixtures.of_kind(ObjectKind.OBJECT.BRAZIER).size(), 1, "lit on arrival")


# Trap 1: the slice's first step by hand. A fresh world's player can
# reach the Surface's ramp and a tree (four timber is a ladder), -1's
# hole over -2, and -2's ramp; and walking onto it lands on -3.
func test_a_fresh_world_reaches_minus_three() -> void:
	var world: World = add_child_autofree(LevelGenerator.generate_world(0))
	var surface: Level = world.level_at(0)
	var spawn: Fixture = surface.level_fixtures.of_kind(ObjectKind.OBJECT.WORLD_SPAWN)[0]
	var on_surface: Dictionary[Vector2i, bool] = LevelGenerator.walkable_from(surface.level_tiles,
		Vector2i(spawn.tile.x, spawn.tile.y))
	assert_eq(LevelGenerator.descent_problems(surface, Vector2i(spawn.tile.x, spawn.tile.y)),
		[] as Array[String], "the spawn walks to the Surface's ramp")
	var trees: Array[Fixture] = surface.level_fixtures.of_kind(ObjectKind.OBJECT.TREE)
	assert_true(trees.any(func(tree: Fixture) -> bool: return _beside_any(tree, on_surface)),
		"a tree in reach for timber")

	var minus_one: Level = world.level_at(1)
	var home: Dictionary[Vector2i, bool] = LevelGenerator.walkable_from(minus_one.level_tiles,
		Vector2i(7, 0))
	assert_true([Vector2i(13, -2), Vector2i(15, -2), Vector2i(14, -1), Vector2i(14, -3)].any(
		func(tile: Vector2i) -> bool: return home.has(tile)), "-1's hole is walked to")

	world.generate_below(1)
	world.generate_below(2)
	assert_eq(LevelGenerator.descent_problems(world.level_at(2), Vector2i(14, -2)),
		[] as Array[String], "-2's ramp is walked to from under the hole")
	var ramp: Vector2i = _ramps(world.level_at(2), TileKind.GROUND.RAMP_DOWN_E)[0]
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Walker",
		WorldPos.new(ramp.x - 1, ramp.y, 2), world.level_at(2), ActorKind.ACTOR.PLAYER)
	world.add_actor(actor)
	for i in 20:
		actor._move(Vector2(1.4, 0))
		if actor.depth != 2: break
	assert_eq(actor.depth, 3, "walking east onto the ramp goes down to -3")


func _beside_any(fixture: Fixture, reached: Dictionary[Vector2i, bool]) -> bool:
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if reached.has(Vector2i(fixture.tile.x, fixture.tile.y) + step): return true
	return false


# --- iron (D-216, D-217) ---

func test_iron_is_on_minus_three_only() -> void:
	var world: World = _world_to_minus_three(0)
	for depth: int in [0, 1, 2]:
		assert_eq(world.level_at(depth).level_tiles.ore.count(TileKind.ORE.IRON), 0,
			"no iron on %d" % depth)
	var iron: int = world.level_at(3).level_tiles.ore.count(TileKind.ORE.IRON)
	assert_gt(iron, 100, "-3 holds iron in veins")


func test_iron_is_an_ore_with_an_item() -> void:
	assert_eq(Digging.ORE_ITEMS[TileKind.ORE.IRON], &"iron_ore", "mined as iron ore")
	var item: Item = ItemRegistry.get_item(&"iron_ore")
	assert_gt(item.weight_kg, ItemRegistry.get_item(&"copper_ore").weight_kg, "heavier than copper")
	assert_not_null(item.icon, "with an icon")
	assert_eq(LevelGridLoader.ORE_CHARS["i"], TileKind.ORE.IRON, "prefabs can hold it")


func test_flint_is_too_weak_for_iron_and_a_stronger_pick_digs_it() -> void:
	var flint: ToolData = ItemRegistry.get_item(&"flint_pickaxe").tool
	assert_false(Digging.digs_ore(_tuning, flint, TileKind.ORE.IRON), "flint can't")
	var bronze: ToolData = flint.duplicate()
	bronze.power = _tuning.ore_tool_power_needed[TileKind.ORE.IRON]
	assert_true(Digging.digs_ore(_tuning, bronze, TileKind.ORE.IRON), "a pick that strong can")
	assert_true(Digging.digs_ore(_tuning, flint, TileKind.ORE.COPPER), "copper needs nothing more")
	assert_true(Digging.digs_ore(_tuning, null, TileKind.ORE.NONE), "plain rock needs no tool here")


# A world with one iron tile at (1, 0) on -3, and a player beside it
# holding a flint pick.
func _iron_beside_a_player() -> Array:
	var world: World = add_child_autofree(Worlds.with_levels([2, 3, 4]))
	var tiles: LevelTiles = world.level_at(3).level_tiles
	tiles.set_top(0, 0, TileKind.TOP.OPEN)
	tiles.set_ore(1, 0, TileKind.ORE.IRON)
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Miner", WorldPos.new(0, 0, 3),
		world.level_at(3), ActorKind.ACTOR.PLAYER)
	world.add_actor(actor)
	actor.pack.add(&"flint_pickaxe", 1)
	actor.hotbar.assign_tool(&"flint_pickaxe", 0)
	actor.hotbar.select_tool(0)
	return [world, actor]


func test_a_flint_pick_on_iron_is_refused_with_its_reason() -> void:
	var made: Array = _iron_beside_a_player()
	var world: World = made[0]
	var actor: Actor = made[1]
	watch_signals(world)
	world.dig_requested.emit(actor, WorldPos.new(1, 0, 3))
	var heard: Array = get_signal_parameters(world, "dig_refused")
	assert_eq(heard[0], actor, "the miner's")
	assert_true(heard[1].equals(WorldPos.new(1, 0, 3)), "the iron tile")
	assert_eq(heard[2], World.DIG_REFUSAL.TOOL_TOO_WEAK, "too weak")
	assert_eq(world.level_at(3).level_tiles.get_top(1, 0), TileKind.TOP.MINABLE_ROCK, "still there")


func test_digging_iron_with_flint_says_why_once_per_tile() -> void:
	var made: Array = _iron_beside_a_player()
	var world: World = made[0]
	var actor: Actor = made[1]
	var dig: CapabilityDig = Global.get_capability_packedscene(Global.CAPABILITY.DIG).instantiate()
	dig.actor = actor
	actor.get_node("Capabilities").add_child(dig)
	watch_signals(world)
	for i in 30:
		dig.dig(0.1, actor.tool(), WorldPos.new(1, 0, 3), world.level_at(3))
	assert_signal_emit_count(world, "dig_refused", 1, "said once, not every tick")
	assert_eq(dig.progress, 0.0, "no work done")


# --- the crushed region (D-218) ---

func test_minus_three_has_one_crushed_region_of_rubble() -> void:
	for world_seed: int in SEEDS:
		var level: Level = _world_to_minus_three(world_seed).level_at(3)
		assert_eq(level.level_regions.count(), 1, "seed %d: one region" % world_seed)
		var tiles: Array[Vector2i] = level.level_regions.tiles_of(LevelRegions.ACCESS.CRUSHED)
		assert_gt(tiles.size(), 50, "seed %d: a real area" % world_seed)
		for tile: Vector2i in tiles:
			if level.level_tiles.get_top(tile.x, tile.y) != TileKind.TOP.CRUSHED:
				fail_test("seed %d: %s isn't rubble" % [world_seed, tile])
				break
		assert_eq(level.level_tiles.top.count(TileKind.TOP.CRUSHED), tiles.size(),
			"seed %d: every rubble tile is the region's" % world_seed)


func test_the_crushed_region_keeps_clear_of_the_arrival() -> void:
	for world_seed: int in SEEDS:
		var level: Level = _world_to_minus_three(world_seed).level_at(3)
		var up: Vector2i = _ramps(level, TileKind.GROUND.RAMP_UP_E)[0]
		var nearest: float = INF
		for tile: Vector2i in level.level_regions.tiles_of(LevelRegions.ACCESS.CRUSHED):
			nearest = minf(nearest, Vector2(tile - up).length())
		assert_gt(nearest, 5.0, "seed %d: %.0f tiles from the ramp up" % [world_seed, nearest])


func test_rubble_is_refused_by_every_tool_with_its_reason() -> void:
	var made: Array = _iron_beside_a_player()
	var world: World = made[0]
	var actor: Actor = made[1]
	world.level_at(3).level_tiles.set_top(0, 1, TileKind.TOP.CRUSHED)
	assert_eq(world.dig_problem(WorldPos.new(0, 1, 3), actor), World.DIG_REFUSAL.CRUSHED, "the pick")
	assert_eq(world.dig_problem(WorldPos.new(0, 1, 3)), World.DIG_REFUSAL.CRUSHED, "and no tool")
	assert_false(TileKind.is_diggable(TileKind.TOP.CRUSHED), "not diggable")
	assert_true(TileKind.is_supporting(TileKind.TOP.CRUSHED), "but solid: it holds a ceiling")


func test_the_refusal_notice_says_why() -> void:
	assert_string_contains(RefusalNotice.DIG_REASONS[World.DIG_REFUSAL.CRUSHED], "shoring")
	assert_string_contains(RefusalNotice.DIG_REASONS[World.DIG_REFUSAL.TOOL_TOO_WEAK], "too hard")


func test_crushed_rubble_and_iron_have_art() -> void:
	var renderer: LevelRenderer = autofree(LevelRenderer.new())
	assert_eq(renderer._top_cells()[TileKind.TOP.CRUSHED], LevelRenderer.AtlasCell.CRUSHED,
		"rubble's cell")
	assert_eq(renderer._ore_cells()[TileKind.ORE.IRON], LevelRenderer.AtlasCell.IRON, "iron's cell")
	assert_true(LevelRenderer.DEPTH_TINTS.has(3), "-3 has its own look")


# --- regions are saved (D-218) ---

func test_regions_round_trip_through_save_data() -> void:
	var regions: LevelRegions = LevelRegions.new()
	regions.add(LevelRegions.ACCESS.CRUSHED, [Vector2i(1, 2), Vector2i(-3, 4)] as Array[Vector2i])
	var back: LevelRegions = LevelRegions.from_save(regions.to_save(), 3)
	assert_eq(back.count(), 1, "one region")
	assert_eq(back.access_at(Vector2i(-3, 4)), LevelRegions.ACCESS.CRUSHED, "its tile")
	assert_eq(back.access_at(Vector2i(0, 0)), LevelRegions.ACCESS.OPEN, "elsewhere open")


func test_a_region_that_isnt_one_is_skipped_with_a_warning() -> void:
	var back: LevelRegions = LevelRegions.from_save([{"access": 99, "tiles": [0, 0]},
		{"access": LevelRegions.ACCESS.CRUSHED, "tiles": [1]}], 3)
	assert_eq(back.count(), 0, "both skipped")
	assert_push_warning("isn't one")


func test_a_saved_level_keeps_its_region() -> void:
	var world: World = _world_to_minus_three(0)
	var level: Level = world.level_at(3)
	var saved: Dictionary = SaveGame._serialize_level(level)
	assert_true(saved.has("regions"), "written")
	var loaded: World = autofree(World.new())
	var back: Level = autofree(SaveGame._deserialize_level(3, saved, loaded))
	assert_eq(back.level_regions.tiles_of(LevelRegions.ACCESS.CRUSHED),
		level.level_regions.tiles_of(LevelRegions.ACCESS.CRUSHED), "the same tiles")
