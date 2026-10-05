extends GutTest


func _actor() -> Actor:
	var actor: Actor = Global.actor_packed_scene.instantiate()
	autofree(actor)
	return actor


func _actor_at(position: Vector2, depth: int) -> Actor:
	var actor: Actor = _actor()
	actor.depth = depth
	actor.position = position
	return actor


func test_the_actor_scene_is_an_actor() -> void:
	var node: Node = Global.actor_packed_scene.instantiate()
	autofree(node)
	assert_true(node is Actor, "actor.tscn's root carries actor.gd")


func test_create_places_the_actor_on_the_tile_center() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, WorldPos.new(3, -2, 1))
	autofree(actor)
	assert_eq(actor.position, Vector2(56, -24),
		"tile (3, -2) is centered at (56, -24)")


func test_create_records_the_world_pos() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, WorldPos.new(3, -2, 1))
	autofree(actor)
	assert_true(actor.current_WorldPos.equals(WorldPos.new(3, -2, 1)),
		"current_WorldPos is the tile it was created on, depth included")


func test_setup_returns_the_actor_for_chaining() -> void:
	var actor: Actor = _actor()
	assert_eq(actor.setup(WorldPos.new(0, 0, 0)), actor,
		"setup returns self so instantiate().setup() chains")


# Pixel -> tile must floor, never truncate: int(-5 / 16) is 0, but
# the tile is -1 (D-067). The negative rows are the ones that catch
# a truncating conversion.
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
		var actor: Actor = _actor_at(case[0], 0)
		var pos: WorldPos = actor.get_current_WorldPos()
		assert_eq(Vector2i(pos.x, pos.y), case[1],
			"%s: %s should be tile %s" % [case[2], case[0], case[1]])


func test_world_pos_keeps_the_actors_depth() -> void:
	var actor: Actor = _actor_at(Vector2(8, 8), 4)
	assert_eq(actor.get_current_WorldPos().depth, 4,
		"pixels say nothing about depth; it comes from the actor")


func test_moving_within_a_tile_does_not_change_world_pos() -> void:
	var actor: Actor = _actor_at(Vector2(8, 8), 0)
	actor.current_WorldPos = actor.get_current_WorldPos()
	watch_signals(actor)
	actor.position = Vector2(12, 3)
	actor._update_WorldPos()
	assert_signal_not_emitted(actor, "actor_worldpos_changed",
		"no tile boundary was crossed")
	assert_true(actor.current_WorldPos.equals(WorldPos.new(0, 0, 0)),
		"still on tile (0, 0)")


func test_crossing_a_tile_boundary_updates_world_pos() -> void:
	var actor: Actor = _actor_at(Vector2(8, 8), 0)
	actor.current_WorldPos = actor.get_current_WorldPos()
	actor.position = Vector2(-0.5, 8)
	actor._update_WorldPos()
	assert_true(actor.current_WorldPos.equals(WorldPos.new(-1, 0, 0)),
		"stepping left of the origin lands on tile (-1, 0)")


# The signal is declared with two parameters, (old_pos, new_pos), and
# listeners will be written against that.
func test_crossing_a_tile_boundary_emits_old_and_new() -> void:
	var actor: Actor = _actor_at(Vector2(8, 8), 0)
	actor.current_WorldPos = actor.get_current_WorldPos()
	watch_signals(actor)
	actor.position = Vector2(24, 8)
	actor._update_WorldPos()
	assert_signal_emitted(actor, "actor_worldpos_changed",
		"crossing into tile (1, 0) is announced")
	var params: Array = get_signal_parameters(
		actor, "actor_worldpos_changed")
	assert_eq(params.size(), 3,
		"emitted as three arguments, not one array holding all args")
	if params.size() == 3:
		assert_is(params[0], Actor, "the first arg is an Actor")
		assert_true(params[1].equals(WorldPos.new(0, 0, 0)),
			"the second argument is where it was")
		assert_true(params[2].equals(WorldPos.new(1, 0, 0)),
			"the third argument is where it is now")


# _ready recomputes current_WorldPos from position. After setup the
# two already agree, so entering the tree must change nothing.
func test_entering_the_tree_keeps_the_spawn_tile() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, WorldPos.new(3, -2, 1))
	add_child_autofree(actor)
	assert_true(actor.current_WorldPos.equals(WorldPos.new(3, -2, 1)),
		"still on tile (3, -2) at depth 1 after _ready")


func test_entering_the_tree_does_not_move_the_actor() -> void:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, WorldPos.new(3, -2, 1))
	add_child_autofree(actor)
	assert_eq(actor.position, Vector2(56, -24),
		"_ready leaves the spawn position alone")
