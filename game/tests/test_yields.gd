extends GutTest

# What digging yields (D-156, D-158): a rock wall 1 stone, a dirt wall
# nothing, an ore vein 2-4 of its ore, into the digging actor's own
# pack, with no cap. A dig with no actor yields nothing.

const Worlds = preload("res://tests/worlds.gd")

var _world: World


# A blank level (solid rock) with the digger standing at the origin.
func before_each() -> void:
	_world = autofree(Worlds.with_levels([1], 42))
	_world.level_at(1).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)


func _digger(kind: int = ActorKind.ACTOR.PLAYER) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Digger", WorldPos.new(0, 0, 1),
		_world.level_at(1), kind)
	_world.add_actor(actor)
	return actor


func _dig(actor: Actor, x: int, y: int = 1) -> void:
	_world.dig_requested.emit(actor, WorldPos.new(x, y, 1))


func test_a_rock_wall_yields_one_stone() -> void:
	var actor: Actor = _digger()
	_dig(actor, 0)
	assert_eq(actor.pack.count_of(&"stone"), 1, "one stone")
	assert_eq(actor.pack.total_weight, 3.0, "3 kg")


func test_a_dirt_wall_yields_nothing() -> void:
	_world.level_at(1).level_tiles.set_top(0, 1, TileKind.TOP.MINABLE_DIRT)
	var actor: Actor = _digger()
	_dig(actor, 0)
	assert_true(actor.pack.is_empty(), "dirt gives nothing")


func test_an_ore_vein_yields_two_to_four_ore_and_no_stone() -> void:
	var actor: Actor = _digger()
	var seen: Dictionary = {}
	for x in range(-20, 21):
		_world.level_at(1).level_tiles.set_ore(x, 1, TileKind.ORE.COPPER)
		var before: int = actor.pack.count_of(&"copper_ore")
		_dig(actor, x)
		# Into the pack while it fits, onto the dug tile after (D-160)
		var dropped: int = _world.level_at(1).level_drops.at(Vector2i(x, 1)).get(&"copper_ore", 0)
		var got: int = actor.pack.count_of(&"copper_ore") - before + dropped
		assert_between(got, 2, 4, "2-4 at x = %d" % x)
		seen[got] = true
	assert_eq(actor.pack.count_of(&"stone"), 0, "ore, not stone")
	assert_eq(seen.size(), 3, "every count from 2 to 4 comes up: %s" % [seen.keys()])


# D-160 replaced D-158's "no cap": a yield fills the pack to 100%, and
# the rest drops on the dug tile.
func test_a_full_packs_yield_drops_on_the_dug_tile() -> void:
	var actor: Actor = _digger()
	actor.pack.add(&"stone", 20)
	_dig(actor, 0)
	assert_eq(actor.pack.count_of(&"stone"), 20, "full: nothing more goes in")
	assert_eq(_world.level_at(1).level_drops.at(Vector2i(0, 1)), {&"stone": 1},
		"it lies where it was dug")


func test_a_yield_that_partly_fits_is_split() -> void:
	var actor: Actor = _digger()
	actor.pack.add(&"stone", 18)
	_world.level_at(1).level_tiles.set_ore(0, 1, TileKind.ORE.COPPER)
	_dig(actor, 0)
	var dropped: int = _world.level_at(1).level_drops.at(Vector2i(0, 1)).get(&"copper_ore", 0)
	assert_eq(actor.pack.count_of(&"copper_ore"), 1, "one 5 kg ore fits in 6 kg of room")
	assert_between(dropped, 1, 3, "the rest dropped")


# P5: the rule asks nobody who dug.
func test_an_npc_digs_into_its_own_pack() -> void:
	var player: Actor = _digger()
	var npc: Actor = _digger(ActorKind.ACTOR.NULL)
	_dig(npc, 0)
	assert_eq(npc.pack.count_of(&"stone"), 1, "the NPC's")
	assert_true(player.pack.is_empty(), "not the player's")


func test_a_dig_with_no_actor_yields_nothing_and_errors_nothing() -> void:
	_dig(null, 0)
	assert_eq(_world.level_at(1).level_tiles.get_top(0, 1), TileKind.TOP.OPEN, "dug all the same")


func test_the_same_seed_yields_the_same_ore() -> void:
	var counts: Array = []
	for i in range(2):
		var world: World = autofree(Worlds.with_levels([1], 7))
		world.level_at(1).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
		var actor: Actor = Actor.create(Global.actor_packed_scene, "D", WorldPos.new(0, 0, 1),
			world.level_at(1), ActorKind.ACTOR.PLAYER)
		world.add_actor(actor)
		for x in range(-5, 6):
			world.level_at(1).level_tiles.set_ore(x, 1, TileKind.ORE.COPPER)
			world.dig_requested.emit(actor, WorldPos.new(x, 1, 1))
		counts.append(actor.pack.count_of(&"copper_ore"))
	assert_eq(counts[0], counts[1], "repeatable")


func test_a_second_world_is_untouched() -> void:
	var other: World = autofree(Worlds.with_levels([1]))
	_dig(_digger(), 0)
	assert_eq(other.level_at(1).level_tiles.get_top(0, 1), TileKind.TOP.MINABLE_ROCK,
		"the other world's rock")
