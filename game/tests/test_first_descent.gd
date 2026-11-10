extends GutTest

# Generation on first descent (D-143). A new world holds the Surface
# and -1. Any actor arriving at a depth makes the world generate the
# level below it, once, where the recipe table has a row. A load
# builds only the levels its save holds, then generates each actor's
# missing level below after the swap.

const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/first_descent"
const SLOT: String = SAVES_ROOT + "/slot-001"
# Open floor on -1, beside the hand-made hole over -2's ladder.
const BESIDE: Vector2i = Vector2i(14, -1)
const HOLE: Vector2i = Vector2i(14, -2)


var BESIDE_HOLE: WorldPos:
	get: return WorldPos.new(BESIDE.x, BESIDE.y, 1)


func after_each() -> void:
	SaveDirs.remove_tree(SAVES_ROOT)


func _world() -> World:
	return autofree(LevelGenerator.generate_world(0))


func _actor(world: World, at: WorldPos, kind: int = ActorKind.ACTOR.PLAYER) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", at,
		world.level_at(at.depth), kind)
	world.add_actor(actor)
	return actor


func _depths(world: World) -> Array[int]:
	var depths: Array[int] = []
	for level: Level in world.levels():
		depths.append(level.depth)
	return depths


# The spawn on the Surface.
func _on_surface(world: World) -> WorldPos:
	return Spawning.world_spawn(world.levels()).tile


# --- arrivals ---

func test_arriving_at_a_depth_generates_the_level_below() -> void:
	var world: World = _world()
	var actor: Actor = _actor(world, _on_surface(world))
	assert_eq(_depths(world), [0, 1] as Array[int], "a new world")
	assert_true(actor.move_to(BESIDE_HOLE), "down to -1")
	assert_eq(_depths(world), [0, 1, 2] as Array[int], "-2 is generated")
	assert_eq(world.level_at(2).world, world, "into this world")


func test_the_level_below_is_generated_once() -> void:
	var world: World = _world()
	var actor: Actor = _actor(world, _on_surface(world))
	actor.move_to(BESIDE_HOLE)
	var minus_two: Level = world.level_at(2)
	watch_signals(world)
	actor.move_to(_on_surface(world))
	actor.move_to(BESIDE_HOLE)
	assert_eq(world.level_at(2), minus_two, "the same -2")
	assert_signal_not_emitted(world, "level_added", "nothing generated again")


# P5: the rule lives in simulation, so it asks nobody who moved.
func test_an_npcs_arrival_generates_too() -> void:
	var world: World = _world()
	var npc: Actor = _actor(world, _on_surface(world), ActorKind.ACTOR.NULL)
	npc.move_to(BESIDE_HOLE)
	assert_not_null(world.level_at(2), "an NPC on -1 grows the world")


# Where an actor starts isn't an arrival, which is what keeps a load
# from generating while it builds.
func test_where_an_actor_starts_generates_nothing() -> void:
	var world: World = _world()
	_actor(world, BESIDE_HOLE)
	assert_null(world.level_at(2), "created on -1, not arrived there")


func test_a_move_within_a_level_generates_nothing() -> void:
	var world: World = _world()
	var actor: Actor = _actor(world, BESIDE_HOLE)
	actor.move_to(WorldPos.new(BESIDE_HOLE.x + 1, BESIDE_HOLE.y, 1))
	assert_null(world.level_at(2), "same depth")


# The deepest recipe row has nothing below it, and that's not an
# error.
func test_arriving_at_the_deepest_level_generates_nothing() -> void:
	var deepest: int = LevelRecipes.TABLE.rows.size() - 1
	var world: World = autofree(World.new())
	for depth: int in [deepest - 1, deepest]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		level.level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
		world.add_level(level)
	var actor: Actor = _actor(world, WorldPos.new(0, 0, deepest - 1))
	assert_true(actor.move_to(WorldPos.new(0, 0, deepest)), "down to the deepest")
	assert_eq(world.levels().size(), 2, "nothing below it to generate")


func test_a_world_outside_the_tree_grows() -> void:
	var world: World = _world()
	assert_false(world.is_inside_tree(), "no game scene, not even the tree")
	_actor(world, _on_surface(world)).move_to(BESIDE_HOLE)
	assert_not_null(world.level_at(2), "it grows all the same")


func test_two_worlds_grow_independently() -> void:
	var first: World = _world()
	var second: World = _world()
	_actor(first, _on_surface(first)).move_to(BESIDE_HOLE)
	assert_not_null(first.level_at(2), "the first grows")
	assert_null(second.level_at(2), "the second doesn't")


func test_a_generation_is_announced_and_timed() -> void:
	var world: World = _world()
	assert_eq(world.last_generation_msec, -1.0, "nothing generated on arrival yet")
	watch_signals(world)
	_actor(world, _on_surface(world)).move_to(BESIDE_HOLE)
	assert_eq(get_signal_parameters(world, "level_added"), [world.level_at(2)], "announced")
	assert_gte(world.last_generation_msec, 0.0, "and timed")


# The new pair is checked once both levels exist. Generating the real
# -2 under the real -1 is clean.
func test_the_real_levels_generate_without_problems() -> void:
	var world: World = _world()
	_actor(world, _on_surface(world)).move_to(BESIDE_HOLE)
	assert_eq(LevelGenerator.problems_between(world.level_at(1), world.level_at(2)),
		[] as Array[String], "-1 and -2 fit")


func test_a_ladder_with_no_hole_above_it_is_a_problem_between_levels() -> void:
	var world: World = _world()
	var lower: Level = LevelGenerator.generate_into(world, 2)
	preload("res://tests/worlds.gd").place_ladder(world, 2, HOLE)
	world.level_at(1).level_tiles.set_ground(HOLE.x, HOLE.y, TileKind.GROUND.ROCK)
	var problems: Array[String] = LevelGenerator.problems_between(world.level_at(1), lower)
	assert_eq(problems.size(), 1, "the ladder under the filled hole: %s" % [problems])


# --- loads ---

# A save of the Surface and -1, with its player on -1. The player is
# created there, not moved, so the world never generates -2.
func _save_without_minus_two() -> void:
	DirAccess.make_dir_recursive_absolute(SLOT)
	var world: World = _world()
	var player: Actor = _actor(world, BESIDE_HOLE)
	assert_eq(SaveGame.save_game(SLOT, world, SaveSession.new(player.actor_id), SAVES_ROOT),
		SaveGame.REFUSAL_REASON.NONE, "saved")


func test_a_save_missing_levels_loads_and_generates_nothing() -> void:
	_save_without_minus_two()
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(SLOT)
	if loaded == null:
		fail_test("the load was refused")
		return
	assert_eq(_depths(loaded.world), [0, 1] as Array[int], "only what the save holds")
	assert_eq(loaded.problems, [] as Array[String], "and -1's way down isn't a problem")
	loaded.free_world()


func test_a_load_generates_each_actors_level_below_after_the_swap() -> void:
	_save_without_minus_two()
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.saves_root = SAVES_ROOT
	add_child_autofree(game)
	assert_eq(game.load_source, SaveGame.SOURCE.SAVE, "the launch loaded the save")
	assert_not_null(game.world.level_at(2), "-2, under the player on -1")
	assert_true(game.world.level_at(2).is_inside_tree(), "in the swapped-in world")


func test_generate_below_actors_covers_every_actor() -> void:
	var world: World = _world()
	_actor(world, BESIDE_HOLE)
	world.generate_below_actors()
	assert_not_null(world.level_at(2), "below the actor on -1")


# --- F3 and the renderer ---

func test_f3_lists_the_generated_depths_and_the_last_time() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.saves_root = SAVES_ROOT
	add_child_autofree(game)
	var overlay: Node = game.get_node("DebugOverlay")
	assert_eq(overlay.levels_text(), "Surface, -1", "a new game")
	game.active_actor.move_to(BESIDE_HOLE)
	assert_string_starts_with(overlay.levels_text(), "Surface, -1, -2  (last ", "-2 and its time")


# -1 is shown before -2 exists; once -2 arrives the renderer listens
# to it, so a ladder built there shows its top in -1's hole (the
# lesson's trap: the renderer listened to nothing). Generation places
# no ladder itself (D-185).
func test_ladder_tops_appear_when_the_level_below_arrives() -> void:
	var world: World = add_child_autofree(LevelGenerator.generate_world(0))
	var actor: Actor = _actor(world, BESIDE_HOLE)
	var view: View = add_child_autofree(View.new())
	view.follow(actor)
	var renderer: FixtureRenderer = add_child_autofree(FixtureRenderer.new())
	renderer.watch(view)
	assert_eq(renderer._top_sprites.size(), 0, "no -2, so no ladder under the hole yet")
	world.generate_below(1)
	assert_eq(renderer._top_sprites.size(), 0, "-2 arrives with no ladder (D-185)")
	var ladder: Fixture = preload("res://tests/worlds.gd").place_ladder(world, 2, HOLE)
	assert_not_null(renderer.top_sprite_for(ladder.id), "one built there shows its top")
