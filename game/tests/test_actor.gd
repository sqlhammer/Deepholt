extends GutTest

# Actor: spawning onto a tile, finding its level, and turning its
# position back into a WorldPos. The actor's tile is the one under
# the center of its feet box, not under its origin, so collision,
# the overlay and digging all agree on where it stands.
#
# Setting an actor's depth looks its level up in the "levels" group,
# so the levels these tests use are put in the tree first.

# A known feet box, so the pixel cases below don't depend on the
# scene's default. Its center sits 4 px below the actor's origin.
const FEET: Rect2 = Rect2(-5, 1, 10, 6)


func before_each() -> void:
	for depth in [0, 1]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		add_child_autofree(level)


func _actor() -> Actor:
	var actor: Actor = Global.actor_packed_scene.instantiate()
	autofree(actor)
	return actor


# An actor whose feet-box center is exactly on `feet_center`.
func _actor_with_feet_at(feet_center: Vector2, depth: int) -> Actor:
	var actor: Actor = _actor()
	actor.feet_box = FEET
	actor.depth = depth
	actor.position = feet_center - FEET.get_center()
	return actor


func _move_feet_to(actor: Actor, feet_center: Vector2) -> void:
	actor.position = feet_center - FEET.get_center()


func test_the_actor_scene_is_an_actor() -> void:
	var node: Node = Global.actor_packed_scene.instantiate()
	autofree(node)
	assert_true(node is Actor, "actor.tscn's root carries actor.gd")


# --- spawning ---

func test_create_places_the_actor_on_the_tile_center() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(3, -2, 1))
	autofree(actor)
	assert_eq(actor.position, Vector2(56, -24),
		"tile (3, -2) is centered at (56, -24)")


# The feet box sits below the origin, so this also checks that the
# scene's default box still fits inside the spawn tile.
func test_create_records_the_world_pos() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(3, -2, 1))
	autofree(actor)
	assert_true(actor.current_WorldPos.equals(WorldPos.new(3, -2, 1)),
		"current_WorldPos is the tile it was created on, depth included")


func test_setup_returns_the_actor_for_chaining() -> void:
	var actor: Actor = _actor()
	assert_eq(actor.setup("TestPlayer", WorldPos.new(0, 0, 0)), actor,
		"setup returns self so instantiate().setup() chains")


func test_setting_depth_finds_that_level() -> void:
	var actor: Actor = _actor()
	actor.depth = 1
	assert_not_null(actor.current_level, "a level is resident at depth 1")
	if actor.current_level:
		assert_eq(actor.current_level.depth, 1, "and it is depth 1's level")


# --- position -> WorldPos ---

func test_world_pos_is_under_the_feet_not_the_origin() -> void:
	var actor: Actor = _actor()
	actor.feet_box = FEET
	actor.depth = 0
	# Origin in tile (0, 0); feet center 4 px lower, in tile (0, 1).
	actor.position = Vector2(8, 14)
	var pos: WorldPos = actor.get_current_WorldPos()
	assert_eq(Vector2i(pos.x, pos.y), Vector2i(0, 1),
		"the tile is the one the feet stand on")


# Pixel -> tile must floor, never truncate: int(-5 / 16) is 0, but
# the tile is -1 (D-067). The negative rows are the ones that catch
# a truncating conversion. Pixels here are the feet-box center.
func test_world_pos_floors_pixels_into_tiles() -> void:
	var cases: Array = [
		[Vector2(8, 8), Vector2i(0, 0), "center of the origin tile"],
		[Vector2(0, 0), Vector2i(0, 0), "a tile's top-left edge is in it"],
		[Vector2(15.9, 15.9), Vector2i(0, 0), "just inside the far edge"],
		[Vector2(16, 0), Vector2i(1, 0), "x = 16 starts the next tile"],
		[Vector2(-0.5, -0.5), Vector2i(-1, -1), "just left of origin"],
		[Vector2(-16, 0), Vector2i(-1, 0), "x = -16 is tile -1's edge"],
		[Vector2(-16.5, 0), Vector2i(-2, 0), "past it is tile -2"],
	]
	for case: Array in cases:
		var actor: Actor = _actor_with_feet_at(case[0], 0)
		var pos: WorldPos = actor.get_current_WorldPos()
		assert_eq(Vector2i(pos.x, pos.y), case[1],
			"%s: feet at %s should be tile %s" % [case[2], case[0], case[1]])


func test_world_pos_keeps_the_actors_depth() -> void:
	var actor: Actor = _actor_with_feet_at(Vector2(8, 8), 1)
	assert_eq(actor.get_current_WorldPos().depth, 1,
		"pixels say nothing about depth; it comes from the actor's level")


# --- tracking ---

func test_moving_within_a_tile_does_not_change_world_pos() -> void:
	var actor: Actor = _actor_with_feet_at(Vector2(8, 8), 0)
	actor.current_WorldPos = actor.get_current_WorldPos()
	watch_signals(actor)
	_move_feet_to(actor, Vector2(12, 3))
	actor._update_WorldPos()
	assert_signal_not_emitted(actor, "actor_worldpos_changed",
		"no tile boundary was crossed")
	assert_true(actor.current_WorldPos.equals(WorldPos.new(0, 0, 0)),
		"still on tile (0, 0)")


func test_crossing_a_tile_boundary_updates_world_pos() -> void:
	var actor: Actor = _actor_with_feet_at(Vector2(8, 8), 0)
	actor.current_WorldPos = actor.get_current_WorldPos()
	_move_feet_to(actor, Vector2(-0.5, 8))
	actor._update_WorldPos()
	assert_true(actor.current_WorldPos.equals(WorldPos.new(-1, 0, 0)),
		"stepping left of the origin lands on tile (-1, 0)")


# The signal is declared as (actor, old_pos, new_pos), and listeners
# will be written against that.
func test_crossing_a_tile_boundary_emits_actor_old_and_new() -> void:
	var actor: Actor = _actor_with_feet_at(Vector2(8, 8), 0)
	actor.current_WorldPos = actor.get_current_WorldPos()
	watch_signals(actor)
	_move_feet_to(actor, Vector2(24, 8))
	actor._update_WorldPos()
	assert_signal_emitted(actor, "actor_worldpos_changed",
		"crossing into tile (1, 0) is announced")
	var params: Array = get_signal_parameters(
		actor, "actor_worldpos_changed")
	assert_eq(params.size(), 3,
		"emitted as three arguments, not one array holding all args")
	if params.size() == 3:
		assert_eq(params[0], actor, "the first arg is the actor itself")
		assert_true(params[1].equals(WorldPos.new(0, 0, 0)),
			"the second argument is where it was")
		assert_true(params[2].equals(WorldPos.new(1, 0, 0)),
			"the third argument is where it is now")


# --- entering the tree ---

# _ready recomputes current_WorldPos from position. After setup the
# two already agree, so entering the tree must change nothing.
func test_entering_the_tree_keeps_the_spawn_tile() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(3, -2, 1))
	add_child_autofree(actor)
	assert_true(actor.current_WorldPos.equals(WorldPos.new(3, -2, 1)),
		"still on tile (3, -2) at depth 1 after _ready")


func test_entering_the_tree_does_not_move_the_actor() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "TestPlayer", WorldPos.new(3, -2, 1))
	add_child_autofree(actor)
	assert_eq(actor.position, Vector2(56, -24),
		"_ready leaves the spawn position alone")


# --- facing (D-075, D-076) ---

func test_a_new_actor_faces_down() -> void:
	assert_eq(_actor().facing, Vector2i(0, 1), "spawned actors face down")


func test_aim_sets_facing() -> void:
	var actor: Actor = _actor_with_feet_at(Vector2(8, 8), 0)
	actor.aim(Vector2.RIGHT, Vector2.ZERO)
	assert_eq(actor.facing, Vector2i(1, 0), "aiming right faces right")


func test_aim_outranks_movement() -> void:
	var actor: Actor = _actor_with_feet_at(Vector2(8, 8), 0)
	actor.aim(Vector2.RIGHT, Vector2.UP)
	assert_eq(actor.facing, Vector2i(1, 0),
		"aiming right while walking up faces right")


func test_movement_sets_facing_when_there_is_no_aim() -> void:
	var actor: Actor = _actor_with_feet_at(Vector2(8, 8), 0)
	actor.aim(Vector2.ZERO, Vector2.LEFT)
	assert_eq(actor.facing, Vector2i(-1, 0),
		"with no aim, walking left faces left")


func test_no_aim_and_no_movement_keeps_facing() -> void:
	var actor: Actor = _actor_with_feet_at(Vector2(8, 8), 0)
	actor.aim(Vector2.RIGHT, Vector2.ZERO)
	actor.aim(Vector2.ZERO, Vector2.ZERO)
	assert_eq(actor.facing, Vector2i(1, 0), "nothing held keeps facing right")


# An aim inside the hysteresis band keeps the current facing, but it
# is still the aim's choice: movement must not take over just because
# facing didn't change.
func test_aim_inside_the_band_is_not_overridden_by_movement() -> void:
	var actor: Actor = _actor_with_feet_at(Vector2(8, 8), 0)
	actor.aim(Vector2.RIGHT, Vector2.ZERO)
	var near_diagonal: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(50))
	actor.aim(near_diagonal, Vector2.UP)
	assert_eq(actor.facing, Vector2i(1, 0),
		"aiming 50° while walking up still faces right, not up")


# --- the dig target ---

# The target is the feet tile plus facing, never facing on its own:
# facing down from (3, -2) digs (3, -1), not tile (0, 1).
func test_target_tile_is_the_feet_tile_plus_facing() -> void:
	var actor: Actor = _actor_with_feet_at(
		TileSpace.tile_center(Vector2i(3, -2)), 1)
	actor.current_WorldPos = actor.get_current_WorldPos()
	var expected: Dictionary = {
		Vector2i(0, 1): Vector2i(3, -1),
		Vector2i(0, -1): Vector2i(3, -3),
		Vector2i(-1, 0): Vector2i(2, -2),
		Vector2i(1, 0): Vector2i(4, -2),
	}
	for facing: Vector2i in expected:
		actor.facing = facing
		var target: WorldPos = actor._get_target_tile()
		assert_eq(Vector2i(target.x, target.y), expected[facing],
			"facing %s from (3, -2) targets %s" % [facing, expected[facing]])
		assert_eq(target.depth, 1, "on the actor's own depth")
