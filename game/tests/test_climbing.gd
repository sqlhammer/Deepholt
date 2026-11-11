extends GutTest

# Climbing, end to end (D-101, D-106): the interact button, polled on
# the physics tick, asks the Ladder rule where to go, and the actor
# moves itself (D-093). Uses the hand-made levels: the hole on -1 and
# the ladder on -2, both at (14, -2).

const Worlds = preload("res://tests/worlds.gd")
const BESIDE_HOLE: Vector2i = Vector2i(14, -1)
const LADDER: Vector2i = Vector2i(14, -2)


var _world: World


func before_each() -> void:
	_world = add_child_autofree(LevelGenerator.generate_world(0))
	# A new world starts with the Surface and -1 only (D-143). The
	# ladder is on -2, so it's built here rather than by an arrival.
	LevelGenerator.generate_into(_world, 2)
	# Generation places no ladder (D-185): one built under -1's hole
	Worlds.place_ladder(_world, 2)


func after_each() -> void:
	Input.action_release(&"interact")


func _actor_at(tile: Vector2i, depth: int, facing: Vector2i) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", WorldPos.new(tile.x, tile.y, depth), _world.level_at(depth), ActorKind.ACTOR.PLAYER)
	_world.add_actor(actor)
	actor.facing = facing
	return actor


func _at(actor: Actor) -> WorldPos:
	return actor.current_WorldPos


# Long enough for any climb to end (D-233).
func _climbed(actor: Actor) -> void:
	actor._physics_process(20.0)


func test_interact_facing_the_hole_climbs_down_onto_the_ladder() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	assert_true(actor.interact(), "something happened")
	_climbed(actor)
	assert_true(_at(actor).equals(WorldPos.new(LADDER.x, LADDER.y, 2)), "on the ladder, on -2: %s" % _at(actor))
	assert_eq(actor.position, TileSpace.tile_center(LADDER), "at the ladder tile's center")


func test_interact_on_the_ladder_climbs_up_beside_the_hole() -> void:
	var actor: Actor = _actor_at(LADDER, 2, Vector2i(0, 1))
	assert_true(actor.interact(), "something happened")
	_climbed(actor)
	assert_true(_at(actor).equals(WorldPos.new(BESIDE_HOLE.x, BESIDE_HOLE.y, 1)),
		"facing south: back beside the hole on -1, %s" % _at(actor))


func test_down_and_up_without_turning_comes_up_east_of_the_hole() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	actor.interact()
	_climbed(actor)
	actor.interact()
	_climbed(actor)
	assert_true(_at(actor).equals(WorldPos.new(15, -2, 1)),
		"facing north, (14, -3) is rock, so east: %s" % _at(actor))


func test_interact_away_from_any_ladder_does_nothing() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, 1))
	assert_false(actor.interact(), "facing away from the hole")
	assert_true(_at(actor).equals(WorldPos.new(BESIDE_HOLE.x, BESIDE_HOLE.y, 1)), "not moved")


func test_a_landing_closed_since_load_refuses_the_climb() -> void:
	_world.level_at(2).level_tiles.set_top(LADDER.x, LADDER.y, TileKind.TOP.MINABLE_ROCK)
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	assert_false(actor.interact(), "the ladder's tile is rock now")
	assert_eq(actor.depth, 1, "still on -1")


# --- the climb's time (D-233) ---

func test_a_climb_takes_five_seconds_unloaded() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	assert_true(actor.interact(), "the climb begins")
	assert_true(actor.is_climbing(), "on the ladder")
	actor._physics_process(4.9)
	assert_eq(actor.depth, 1, "still climbing at 4.9 s")
	assert_almost_eq(actor.climb_progress(), 0.98, 0.01, "nearly there")
	actor._physics_process(0.1)
	assert_eq(actor.depth, 2, "down at 5 s")
	assert_false(actor.is_climbing(), "and off the ladder")


func test_a_load_slows_the_climb_as_the_appendix_says() -> void:
	var tuning: TuningProfile = _world.tuning
	assert_eq(Ladder.climb_seconds(tuning, 0.5), 5.0, "half full: 5 s")
	assert_eq(Ladder.climb_seconds(tuning, 0.8), 5.0, "80%: still 5 s")
	assert_almost_eq(Ladder.climb_seconds(tuning, 0.9), 8.0, 0.001, "past 80%: x1.6")
	assert_almost_eq(Ladder.climb_seconds(tuning, 1.2), 10.0, 0.001, "past 100%: x2")


func test_nothing_else_happens_on_the_ladder() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	actor.interact()
	var at: Vector2 = actor.position
	actor.move(Vector2(1, 0))
	actor._physics_process(1.0)
	assert_eq(actor.position, at, "no walking off mid-climb")
	assert_false(actor.interact(), "and no second climb")
	assert_true(actor.has_interaction(), "pad A doesn't take from the ground mid-climb")


func test_a_climb_announces_itself() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	watch_signals(_world)
	actor.interact()
	assert_eq(get_signal_parameters(_world, "climb_started")[2], 5.0, "with its seconds")


func test_a_way_closed_mid_climb_leaves_the_climber_where_they_were() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	actor.interact()
	_world.level_at(2).level_tiles.set_top(LADDER.x, LADDER.y, TileKind.TOP.MINABLE_ROCK)
	_climbed(actor)
	assert_eq(actor.depth, 1, "the landing is rock now: still on -1")


func test_you_cant_walk_onto_the_hole_on_minus_one() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	for i in 20:
		actor._move(Vector2(0, -1.4))
	assert_true(_at(actor).equals(WorldPos.new(BESIDE_HOLE.x, BESIDE_HOLE.y, 1)), "stopped beside it")


func test_you_can_stand_on_the_ladder_on_minus_two() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 2, Vector2i(0, -1))
	for i in 20:
		actor._move(Vector2(0, -1.4))
	assert_true(_at(actor).equals(WorldPos.new(LADDER.x, LADDER.y, 2)), "walked onto it (D-101)")


# --- through the input handler (D-106) ---

func test_the_interact_button_climbs_once_per_press() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	var handler: InputHandler = InputHandler.new()
	add_child_autofree(handler)
	handler.setup(actor, func() -> Vector2: return Vector2.ZERO)
	handler.set_physics_process(false)  # driven by hand below

	Input.action_press(&"interact")
	handler._physics_process(0.0)
	_climbed(actor)
	assert_eq(actor.depth, 2, "the press climbed down")

	# Still held on the next tick: not a new press, so no climb back up.
	await wait_physics_frames(2)
	handler._physics_process(0.0)
	assert_eq(actor.depth, 2, "holding the button doesn't climb again")


# --- pad A: interact first, take otherwise (D-167, trap 5) ---

func _pad_a(actor: Actor) -> void:
	var handler: InputHandler = add_child_autofree(InputHandler.new())
	handler.setup(actor, func() -> Vector2: return Vector2.ZERO)
	handler.set_physics_process(false)
	handler.interact_or_take()


func test_pad_a_at_a_ladder_climbs_and_leaves_the_ground_alone() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	_world.level_at(1).level_drops.add(BESIDE_HOLE, &"stone", 2)
	_pad_a(actor)
	_climbed(actor)
	assert_eq(actor.depth, 2, "it climbed")
	assert_eq(actor.pack.count_of(&"stone"), 0, "and took nothing")


func test_pad_a_away_from_a_ladder_takes_and_says_so() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, 1))
	_world.level_at(1).level_drops.add(BESIDE_HOLE, &"stone", 2)
	watch_signals(_world)
	_pad_a(actor)
	assert_eq(actor.depth, 1, "no climb")
	assert_eq(actor.pack.count_of(&"stone"), 2, "it took the stone")
	assert_signal_emitted_with_parameters(_world, "took", [actor, {&"stone": 2}])


func test_pad_a_at_a_ladder_too_heavy_to_climb_refuses_rather_than_takes() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	actor.pack.add(&"stone", 40)
	_world.level_at(1).level_drops.add(BESIDE_HOLE, &"stone", 2)
	watch_signals(_world)
	_pad_a(actor)
	assert_signal_emitted(_world, "climb_refused", "too heavy")
	assert_eq(actor.pack.count_of(&"stone"), 40, "nothing taken")


# The keyboard keeps both keys apart; only the pad's A does both.
func test_only_pad_a_both_interacts_and_takes() -> void:
	assert_eq(_buttons(&"interact_or_take"), [JOY_BUTTON_A], "pad A")
	assert_eq(_buttons(&"interact"), [], "E only: no pad button")
	assert_eq(_buttons(&"take"), [], "T only: LB went to the hotbar")
	assert_eq(_buttons(&"hotbar_prev"), [JOY_BUTTON_LEFT_SHOULDER], "LB")
	assert_eq(_buttons(&"hotbar_next"), [JOY_BUTTON_RIGHT_SHOULDER], "RB")
	assert_eq(_buttons(&"breach"), [JOY_BUTTON_X], "X stays breach (D-171)")
	assert_eq(_buttons(&"inventory_pick"), [JOY_BUTTON_A], "A picks up in the inventory")


func _buttons(action: StringName) -> Array:
	var found: Array = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton: found.append(event.button_index)
	return found
