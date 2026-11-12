extends GutTest

# Items and the pack (D-156, D-157, D-159). Items are .tres resources
# found by id; every actor carries a pack with a running total weight;
# the pack is saved with its actor, and an unknown item is kept and
# reported, never dropped; a new game's first player starts with the
# profile's starting items; the HUD shows the followed actor's load.

const Worlds = preload("res://tests/worlds.gd")
const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/pack"
const SLOT: String = SAVES_ROOT + "/slot-001"


func after_each() -> void:
	SaveDirs.remove_tree(SAVES_ROOT)


# --- items (content-schema §3) ---

func test_the_items_carry_the_appendixs_weights() -> void:
	assert_eq(ItemRegistry.get_item(&"stone").weight_kg, 3.0, "stone 3 kg")
	assert_eq(ItemRegistry.get_item(&"copper_ore").weight_kg, 5.0, "copper ore 5 kg")
	assert_eq(ItemRegistry.get_item(&"timber").weight_kg, 2.0, "timber 2 kg")


func test_every_item_has_the_mandatory_fields() -> void:
	for id: StringName in ItemRegistry.ids():
		var item: Item = ItemRegistry.get_item(id)
		assert_gt(item.weight_kg, 0.0, "%s has a weight" % id)
		assert_gt(item.trade_value, 0.0, "%s has a value (value density, ui-ux §5)" % id)
		assert_gt(item.stack_max, 0, "%s has a stack size" % id)
		assert_ne(item.display_key, "", "%s has a display key" % id)


func test_an_unknown_id_is_null_and_loud() -> void:
	assert_null(ItemRegistry.find(&"mithril"), "quietly, for a caller that reports it")
	assert_null(ItemRegistry.get_item(&"mithril"), "loudly otherwise")
	assert_push_error("No item with id 'mithril'")


# --- the pack ---

func test_the_total_weight_follows_what_is_added_and_taken() -> void:
	var pack: Pack = Pack.new()
	pack.add(&"stone", 4)
	pack.add(&"timber", 10)
	assert_eq(pack.total_weight, 32.0, "4 x 3 + 10 x 2")
	assert_true(pack.remove(&"timber", 4), "taken")
	assert_eq(pack.total_weight, 24.0, "less 8 kg")
	assert_eq(pack.count_of(&"timber"), 6, "six left")


func test_taking_more_than_there_is_changes_nothing() -> void:
	var pack: Pack = Pack.new()
	pack.add(&"timber", 3)
	assert_false(pack.remove(&"timber", 4), "not enough")
	assert_eq(pack.count_of(&"timber"), 3, "untouched")


func test_a_pack_announces_each_change() -> void:
	var pack: Pack = Pack.new()
	watch_signals(pack)
	pack.add(&"stone", 1)
	pack.remove(&"stone", 1)
	assert_signal_emit_count(pack, "changed", 2, "added, then taken")
	assert_true(pack.is_empty(), "and empty again")


func test_a_pack_round_trips_as_plain_types() -> void:
	var pack: Pack = Pack.new()
	pack.add(&"stone", 2)
	pack.add(&"copper_ore", 3)
	var data: Dictionary = pack.to_save()
	assert_eq(data, {"stone": 2, "copper_ore": 3}, "id -> count")
	var back: Pack = Pack.from_save(data)
	assert_eq(back.total_weight, pack.total_weight, "the same weight")


# Trap 5: kept and reported, never dropped.
func test_an_unknown_item_is_kept_weighing_nothing() -> void:
	var pack: Pack = Pack.from_save({"mithril": 2, "stone": 1})
	assert_eq(pack.count_of(&"mithril"), 2, "kept")
	assert_eq(pack.total_weight, 3.0, "weighing nothing")
	assert_eq(pack.unknown_ids(), [&"mithril"] as Array[StringName], "and named")
	assert_eq(pack.to_save().get("mithril"), 2, "so a save keeps it")


func test_a_malformed_entry_is_skipped_with_a_warning() -> void:
	var pack: Pack = Pack.from_save({"stone": "lots", 7: 1, "timber": 2})
	assert_eq(pack.to_save(), {"timber": 2}, "only the good entry")
	assert_push_warning("skipped")


# --- on actors (P5) ---

func _world_with(kind: int) -> Actor:
	var world: World = autofree(Worlds.with_levels([0, 1]))
	world.level_at(0).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Carrier", WorldPos.new(0, 0, 0),
		world.level_at(0), kind)
	world.add_actor(actor)
	return actor


func test_every_actor_has_its_own_pack() -> void:
	var player: Actor = _world_with(ActorKind.ACTOR.PLAYER)
	var npc: Actor = _world_with(ActorKind.ACTOR.NULL)
	player.pack.add(&"stone", 1)
	assert_true(npc.pack.is_empty(), "an NPC has one, and it's its own")


func test_load_ratio_is_against_the_worlds_capacity() -> void:
	var actor: Actor = _world_with(ActorKind.ACTOR.PLAYER)
	actor.pack.add(&"stone", 10)
	assert_almost_eq(actor.load_ratio(), 30.0 / 60.0, 0.0001, "30 of 60 kg")


# --- saving it (D-157) ---

func _saved_player_with(items: Dictionary) -> Actor:
	var world: World = autofree(LevelGenerator.generate_world(3))
	var spawn: WorldPos = Spawning.world_spawn(world.levels()).tile
	var player: Actor = Actor.create(Global.actor_packed_scene, "P", spawn,
		world.level_at(spawn.depth), ActorKind.ACTOR.PLAYER)
	world.add_actor(player)
	for id: StringName in items:
		player.pack.add(id, items[id])
	DirAccess.make_dir_recursive_absolute(SLOT)
	assert_eq(SaveGame.save_game(SLOT, world, SaveSession.new(player.actor_id), SAVES_ROOT),
		SaveGame.REFUSAL_REASON.NONE, "saved")
	return player


func test_a_pack_round_trips_through_a_save() -> void:
	var player: Actor = _saved_player_with({&"stone": 4, &"timber": 6})
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(SLOT)
	if loaded == null:
		fail_test("refused")
		return
	var back: Actor = loaded.world.players()[0]
	assert_eq(back.pack.to_save(), player.pack.to_save(), "the same pack")
	loaded.free_world()


func test_an_unknown_item_in_a_save_is_a_load_problem() -> void:
	_saved_player_with({&"mithril": 1})
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(SLOT)
	if loaded == null:
		fail_test("refused")
		return
	assert_eq(loaded.problems.size(), 1, "one problem: %s" % [loaded.problems])
	assert_push_warning("mithril")
	assert_eq(loaded.world.players()[0].pack.count_of(&"mithril"), 1, "and it's still carried")
	loaded.free_world()


func test_a_save_from_before_packs_loads_an_empty_pack() -> void:
	var data: Dictionary = {"actor_kind": ActorKind.ACTOR.PLAYER, "actor_name": "Old",
		"worldpos": {"x": 0, "y": 0, "depth": 0}, "facing": {"x": 0, "y": 1}}
	var world: World = autofree(Worlds.with_levels([0]))
	world.level_at(0).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	var actor: Actor = SaveGame._deserialize_actor(data, 1, world)
	autofree(actor)
	assert_eq(actor.pack.count_of(&"timber"), 0, "no pack entry, nothing saved")
	assert_eq(actor.pack.to_save().keys(), ["flint_axe", "flint_pickaxe", "flint_shovel"],
		"only the tools a player saved before tools is given")


# --- a new game (trap 6) ---

func _game() -> Node:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.saves_root = SAVES_ROOT
	add_child_autofree(game)
	return game


# D-244: two timber and no tools; the first job is making a flint
# axe and pick by hand.
func test_a_new_games_player_starts_with_two_timber_and_no_tools() -> void:
	var game: Node = _game()
	assert_eq(game.active_actor.pack.count_of(&"timber"), 2, "two timber")
	assert_eq(game.active_actor.pack.count_of(&"flint_axe"), 0, "no axe")
	assert_eq(game.active_actor.pack.count_of(&"flint_pickaxe"), 0, "no pick")
	assert_eq(game.active_actor.pack.total_weight, 4.0, "2 x 2 kg")
	assert_eq(game.active_actor.tool(), Hotbar.BARE_HANDS, "bare hands")


func test_a_second_player_starts_empty() -> void:
	var game: Node = _game()
	game._spawn_player("Second")
	var second: Actor = game.world.players()[1]
	assert_true(second.pack.is_empty(), "only the new game's first player")


func test_a_load_restores_the_pack_and_adds_nothing() -> void:
	var game: Node = _game()
	game.active_actor.pack.add(&"timber", 6)
	assert_true(game.save_game(), "saved")
	assert_eq(game.load_game(), game.REFUSAL_REASON.NONE, "loaded")
	assert_eq(game.active_actor.pack.count_of(&"timber"), 8, "what was saved, nothing more")


# --- the HUD (D-159) ---

func test_the_hud_shows_the_followed_actors_load() -> void:
	var game: Node = _game()
	var hud: CarryHud = game.get_node("CarryHud")
	assert_eq(hud.text, "4 / 60 kg", "a new game")
	game.active_actor.pack.add(&"stone", 5)
	assert_eq(hud.text, "19 / 60 kg", "follows the pack")
	await get_tree().process_frame


func test_the_hud_colors_follow_the_load_curves_bands() -> void:
	assert_eq(CarryHud.color_for(0.4), CarryHud.LIGHT, "light")
	assert_eq(CarryHud.color_for(0.7), CarryHud.LOADED, "past half")
	assert_eq(CarryHud.color_for(1.2), CarryHud.HEAVY, "past full")
	assert_eq(CarryHud.color_for(1.6), CarryHud.OVER, "past 150%")


# A broken item file is loud at startup, never a silent null later
# (content-schema §1).
func test_a_broken_item_file_is_loud() -> void:
	ItemRegistry._register(null, "not_an_item.tres")
	assert_push_error("is not an item")
	ItemRegistry._register(Item.new(), "no_id.tres")
	assert_push_error("has no id")
	var twin: Item = Item.new()
	twin.id = &"stone"
	ItemRegistry._register(twin, "stone_again.tres")
	assert_push_error("Duplicate item id 'stone'")
	assert_eq(ItemRegistry.get_item(&"stone").weight_kg, 3.0, "the first stone stays")


func test_the_hud_hatches_past_150_percent() -> void:
	var game: Node = _game()
	var hud: CarryHud = game.get_node("CarryHud")
	game.active_actor.pack.add(&"stone", 30)
	assert_gt(hud.ratio, 1.5, "over 150%: 110 of 60 kg")
	await get_tree().process_frame
