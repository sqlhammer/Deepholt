extends GutTest

# Letting go (D-160 to D-162): items lying on the ground, dropped from
# a pack through the world, picked up automatically by players up to
# 100%, taken whatever the load with the take key, saved with their
# level, drawn only where sensed or lit, and dropped from the
# inventory overlay.

const Worlds = preload("res://tests/worlds.gd")
const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/drops"
const SLOT: String = SAVES_ROOT + "/slot-001"

var _world: World


# A corridor along y = 0 on -1, with a blank -2 below so arriving on
# -1 never generates the real one (D-143).
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2]))
	for x in range(-10, 11):
		_world.level_at(1).level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	watch_signals(_world)


func after_each() -> void:
	SaveDirs.remove_tree(SAVES_ROOT)


func _actor(x: int = 0, kind: int = ActorKind.ACTOR.PLAYER) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Carrier", WorldPos.new(x, 0, 1),
		_world.level_at(1), kind)
	_world.add_actor(actor)
	return actor


func _drops() -> LevelDrops:
	return _world.level_at(1).level_drops


func _step(actor: Actor, x: int) -> void:
	actor.move_to(WorldPos.new(x, 0, 1))


# --- the store (D-160) ---

func test_the_same_item_merges_on_a_tile() -> void:
	_drops().add(Vector2i(2, 0), &"stone", 2)
	_drops().add(Vector2i(2, 0), &"stone", 3)
	_drops().add(Vector2i(2, 0), &"timber", 1)
	assert_eq(_drops().at(Vector2i(2, 0)), {&"stone": 5, &"timber": 1}, "merged by item")


func test_taking_more_than_lies_there_takes_what_there_is() -> void:
	_drops().add(Vector2i(2, 0), &"stone", 2)
	assert_eq(_drops().take(Vector2i(2, 0), &"stone", 5), 2, "only two")
	assert_true(_drops().is_empty(), "and the tile is clear")


# --- dropping (D-161) ---

func test_a_drop_moves_items_from_the_pack_onto_the_actors_tile() -> void:
	var actor: Actor = _actor()
	actor.pack.add(&"stone", 5)
	_world.drop_requested.emit(actor, &"stone", 2)
	assert_eq(actor.pack.count_of(&"stone"), 3, "three left")
	assert_eq(_drops().at(Vector2i.ZERO), {&"stone": 2}, "two on its tile")
	assert_signal_emitted(_world, "items_dropped")


func test_you_cant_drop_what_you_dont_have() -> void:
	var actor: Actor = _actor()
	actor.pack.add(&"stone", 1)
	_world.drop_requested.emit(actor, &"stone", 4)
	assert_eq(_drops().at(Vector2i.ZERO), {&"stone": 1}, "only the one")
	_world.drop_requested.emit(actor, &"timber", 1)
	assert_eq(_drops().at(Vector2i.ZERO), {&"stone": 1}, "none of what it hasn't")


# --- pickup (D-160) ---

func test_a_player_picks_up_within_reach_as_it_moves() -> void:
	var actor: Actor = _actor()
	_drops().add(Vector2i(3, 0), &"stone", 2)
	_step(actor, 2)
	assert_eq(actor.pack.count_of(&"stone"), 2, "the next tile is in reach")
	assert_true(_drops().is_empty(), "and nothing is left")


func test_out_of_reach_stays_put() -> void:
	var actor: Actor = _actor()
	_drops().add(Vector2i(4, 0), &"stone", 2)
	_step(actor, 2)
	assert_eq(actor.pack.count_of(&"stone"), 0, "two tiles away")


func test_pickup_fills_to_100_percent_and_leaves_the_rest() -> void:
	var actor: Actor = _actor()
	actor.pack.add(&"stone", 18)
	_drops().add(Vector2i(2, 0), &"stone", 5)
	_step(actor, 1)
	assert_eq(actor.pack.count_of(&"stone"), 20, "to 60 of 60 kg")
	assert_eq(_drops().at(Vector2i(2, 0)), {&"stone": 3}, "the rest stays")


func test_an_npc_never_picks_up() -> void:
	var npc: Actor = _actor(0, ActorKind.ACTOR.NULL)
	_drops().add(Vector2i(2, 0), &"stone", 2)
	_step(npc, 1)
	assert_true(npc.pack.is_empty(), "it walks over it")


# Trap 3: what you drop stays down until you step off and back.
func test_what_you_drop_isnt_picked_straight_back_up() -> void:
	var actor: Actor = _actor()
	actor.pack.add(&"stone", 3)
	_world.drop_requested.emit(actor, &"stone", 3)
	_step(actor, 0)
	assert_eq(actor.pack.count_of(&"stone"), 0, "still on the ground")
	_step(actor, 3)
	_step(actor, 1)
	assert_eq(actor.pack.count_of(&"stone"), 3, "picked up once it came back")


# --- the take key (D-160) ---

func test_the_take_key_takes_everything_in_reach_whatever_the_load() -> void:
	var actor: Actor = _actor()
	actor.pack.add(&"stone", 20)
	_drops().add(Vector2i(1, 0), &"stone", 15)
	_drops().add(Vector2i(-1, 0), &"copper_ore", 2)
	_world.take_requested.emit(actor)
	assert_eq(actor.pack.count_of(&"stone"), 35, "past 100%")
	assert_eq(actor.pack.count_of(&"copper_ore"), 2, "and the ore")
	assert_gt(actor.load_ratio(), 1.5, "past 150%, so no ladder now")
	assert_true(_drops().is_empty(), "nothing left in reach")


func test_the_take_key_takes_what_you_just_dropped() -> void:
	var actor: Actor = _actor()
	actor.pack.add(&"stone", 2)
	_world.drop_requested.emit(actor, &"stone", 2)
	_world.take_requested.emit(actor)
	assert_eq(actor.pack.count_of(&"stone"), 2, "it's deliberate")


# --- saving (trap 4, trap 5) ---

func _saved_world_with_drops() -> void:
	var world: World = autofree(LevelGenerator.generate_world(3))
	var spawn: WorldPos = Spawning.world_spawn(world.levels()).tile
	var player: Actor = Actor.create(Global.actor_packed_scene, "P", spawn,
		world.level_at(spawn.depth), ActorKind.ACTOR.PLAYER)
	world.add_actor(player)
	world.level_at(spawn.depth).level_drops.add(Vector2i(spawn.x + 1, spawn.y), &"stone", 4)
	world.level_at(spawn.depth).level_drops.add(Vector2i(spawn.x + 1, spawn.y), &"mithril", 1)
	DirAccess.make_dir_recursive_absolute(SLOT)
	assert_eq(SaveGame.save_game(SLOT, world, SaveSession.new(player.actor_id), SAVES_ROOT),
		SaveGame.REFUSAL_REASON.NONE, "saved")


func test_drops_round_trip_and_an_unknown_one_is_reported() -> void:
	_saved_world_with_drops()
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(SLOT)
	if loaded == null:
		fail_test("refused")
		return
	var spawn: WorldPos = Spawning.world_spawn(loaded.world.levels()).tile
	var lying: Dictionary = loaded.world.level_at(spawn.depth).level_drops.at(
		Vector2i(spawn.x + 1, spawn.y))
	assert_eq(lying.get(&"stone"), 4, "the stone is still there")
	assert_eq(lying.get(&"mithril"), 1, "the unknown item is kept")
	assert_push_warning("mithril")
	assert_eq(loaded.problems.size(), 1, "and reported: %s" % [loaded.problems])
	# Trap 4: the loaded player stands beside them and took nothing
	assert_true(loaded.world.players()[0].pack.is_empty(), "nothing picked up during the load")
	loaded.free_world()


func test_a_malformed_or_outside_drop_is_skipped_with_a_warning() -> void:
	var level: Level = _world.level_at(1)
	SaveGame._deserialize_drops([{"item": "stone", "count": "two", "x": 0, "y": 0},
		{"item": "stone", "count": 1, "x": 500, "y": 0}], level)
	assert_true(level.level_drops.is_empty(), "neither loaded")
	assert_push_warning("isn't an item stack")
	assert_push_warning("outside the level")


# --- drawing (D-161) ---

func test_drops_show_only_where_sensed_or_lit() -> void:
	var view: View = add_child_autofree(View.new())
	var vis: Visibility = add_child_autofree(Visibility.new())
	vis.watch(view)
	var renderer: DropRenderer = add_child_autofree(DropRenderer.new())
	renderer.watch(view)
	renderer.watch_visibility(vis)
	view.follow(_actor())
	_drops().add(Vector2i(10, 0), &"stone", 1)
	_drops().add(Vector2i(2, 0), &"stone", 1)
	_drops().add(Vector2i(2, 0), &"mithril", 1)
	assert_true(renderer.shows(Vector2i(2, 0)), "in the ring")
	assert_false(renderer.shows(Vector2i(10, 0)), "past it, in the dark")
	await get_tree().process_frame


# --- the inventory overlay (D-162) ---

func _overlay(actor: Actor) -> InventoryOverlay:
	var overlay: InventoryOverlay = add_child_autofree(InventoryOverlay.new())
	overlay.actor = actor
	overlay.set_open(true)
	return overlay


func test_it_lists_by_value_density() -> void:
	var actor: Actor = _actor()
	actor.pack.add(&"stone", 1)
	actor.pack.add(&"timber", 1)
	actor.pack.add(&"copper_ore", 1)
	var overlay: InventoryOverlay = _overlay(actor)
	assert_eq(overlay.rows(), [&"copper_ore", &"timber", &"stone"] as Array[StringName],
		"1.2, 1.0, 0.33 per kg")
	assert_string_contains(overlay.text(), "1 Copper ore  5 kg", "with each weight")


func test_it_drops_one_or_the_stack() -> void:
	var actor: Actor = _actor()
	actor.pack.add(&"stone", 5)
	var overlay: InventoryOverlay = _overlay(actor)
	overlay.drop_one()
	assert_eq(actor.pack.count_of(&"stone"), 4, "one")
	overlay.drop_stack()
	assert_eq(actor.pack.count_of(&"stone"), 0, "then the rest")
	assert_eq(_drops().at(Vector2i.ZERO), {&"stone": 5}, "all on its tile")


func test_selection_wraps_and_a_closed_overlay_drops_nothing() -> void:
	var actor: Actor = _actor()
	actor.pack.add(&"stone", 1)
	actor.pack.add(&"timber", 1)
	var overlay: InventoryOverlay = _overlay(actor)
	overlay.move_focus(1)
	overlay.move_focus(1)
	assert_eq(overlay.focus, 0, "wrapped round")
	overlay.toggle()
	overlay.drop_one()
	assert_eq(actor.pack.count_of(&"timber"), 1, "closed: nothing dropped")


# Trap 6: while it's open, the drop keys don't dig, breach or build.
func test_while_open_nothing_digs_or_breaches() -> void:
	var actor: Actor = _actor()
	var handler: InputHandler = add_child_autofree(InputHandler.new())
	handler.setup(actor, func() -> Vector2: return Vector2.ZERO)
	handler.inventory = _overlay(actor)
	actor.primary_action(true)
	actor.breach(true)
	handler._inventory_mode(Vector2.ZERO)
	assert_false(actor.action_intent, "no digging")
	assert_false(actor.breach_intent, "no breaching")
