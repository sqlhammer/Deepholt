extends GutTest

# Climbing, end to end (D-101, D-106): the interact button, polled on
# the physics tick, asks the Ladder rule where to go, and the actor
# moves itself (D-093). Uses the hand-made levels: the hole on -1 and
# the ladder on -2, both at (14, -2).

const BESIDE_HOLE: Vector2i = Vector2i(14, -1)
const LADDER: Vector2i = Vector2i(14, -2)


func before_each() -> void:
	for level: Level in LevelGenerator.generate_levels(World.level_recipes):
		add_child_autofree(level)


func after_each() -> void:
	Input.action_release(&"interact")


func _actor_at(tile: Vector2i, depth: int, facing: Vector2i) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", WorldPos.new(tile.x, tile.y, depth))
	add_child_autofree(actor)
	actor.facing = facing
	return actor


func _at(actor: Actor) -> WorldPos:
	return actor.current_WorldPos


func test_interact_facing_the_hole_climbs_down_onto_the_ladder() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	assert_true(actor.interact(), "something happened")
	assert_true(_at(actor).equals(WorldPos.new(LADDER.x, LADDER.y, 2)), "on the ladder, on -2: %s" % _at(actor))
	assert_eq(actor.position, TileSpace.tile_center(LADDER), "at the ladder tile's center")


func test_interact_on_the_ladder_climbs_up_beside_the_hole() -> void:
	var actor: Actor = _actor_at(LADDER, 2, Vector2i(0, 1))
	assert_true(actor.interact(), "something happened")
	assert_true(_at(actor).equals(WorldPos.new(BESIDE_HOLE.x, BESIDE_HOLE.y, 1)),
		"facing south: back beside the hole on -1, %s" % _at(actor))


func test_down_and_up_without_turning_comes_up_east_of_the_hole() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	actor.interact()
	actor.interact()
	assert_true(_at(actor).equals(WorldPos.new(15, -2, 1)),
		"facing north, (14, -3) is rock, so east: %s" % _at(actor))


func test_interact_away_from_any_ladder_does_nothing() -> void:
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, 1))
	assert_false(actor.interact(), "facing away from the hole")
	assert_true(_at(actor).equals(WorldPos.new(BESIDE_HOLE.x, BESIDE_HOLE.y, 1)), "not moved")


func test_a_landing_closed_since_load_refuses_the_climb() -> void:
	World.get_level_by_depth(2).level_tiles.set_top(LADDER.x, LADDER.y, TileKind.TOP.MINABLE_ROCK)
	var actor: Actor = _actor_at(BESIDE_HOLE, 1, Vector2i(0, -1))
	assert_false(actor.interact(), "the ladder's tile is rock now")
	assert_eq(actor.depth, 1, "still on -1")


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
	assert_eq(actor.depth, 2, "the press climbed down")

	# Still held on the next tick: not a new press, so no climb back up.
	await wait_physics_frames(2)
	handler._physics_process(0.0)
	assert_eq(actor.depth, 2, "holding the button doesn't climb again")
