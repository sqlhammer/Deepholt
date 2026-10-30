extends GutTest

# Ramps (D-095 to D-098): a directional pair of ground kinds at the
# same (x, y) on two levels. Walking onto the down end moving downhill
# takes you down; walking onto the up end moving uphill takes you up.
# Movement decides, not facing, and only its dominant axis counts.

const RAMP_TILE: Vector2i = Vector2i(6, 0)


# --- kinds ---

func test_every_ramp_has_a_pair_going_the_same_way() -> void:
	for kind: int in TileKind.RAMPS:
		var pair: int = TileKind.ramp_pair(kind)
		assert_true(TileKind.is_ramp(pair), "%d has a pair" % kind)
		assert_eq(TileKind.RAMPS[pair].downhill, TileKind.RAMPS[kind].downhill, "same direction")
		assert_ne(TileKind.RAMPS[pair].down, TileKind.RAMPS[kind].down, "opposite end")
		assert_eq(TileKind.ramp_pair(pair), kind, "and the pair of the pair is itself")


func test_floor_is_not_a_ramp() -> void:
	assert_false(TileKind.is_ramp(TileKind.GROUND.DIRT), "dirt isn't")
	assert_eq(TileKind.ramp_pair(TileKind.GROUND.DIRT), -1, "so it has no pair")


func test_ramp_letters_load_as_ramps() -> void:
	var tiles: LevelTiles = LevelTiles.new(LevelBound.new(0, "Unit Test", 9))
	var prefab: TilePrefab = TilePrefab.from_grids(&"test_ramps", "nNeEsSwW0", "........0", "........0")
	assert_true(LevelGridLoader.stamp(tiles, prefab, Vector2i.ZERO), "ramp letters are valid ground")
	var expected: Array[int] = [
		TileKind.GROUND.RAMP_DOWN_N, TileKind.GROUND.RAMP_UP_N,
		TileKind.GROUND.RAMP_DOWN_E, TileKind.GROUND.RAMP_UP_E,
		TileKind.GROUND.RAMP_DOWN_S, TileKind.GROUND.RAMP_UP_S,
		TileKind.GROUND.RAMP_DOWN_W, TileKind.GROUND.RAMP_UP_W]
	for i in expected.size():
		assert_eq(tiles.get_ground(i - 8, 0), expected[i], "letter %d" % i)


# --- the rule ---

func _tiles_with(kind: int) -> LevelTiles:
	var tiles: LevelTiles = LevelTiles.new(LevelBound.new(1, "Unit Test", 4))
	tiles.set_ground(0, 0, kind)
	return tiles


func test_moving_downhill_onto_the_down_end_goes_down() -> void:
	var target: WorldPos = Ramp.target_for(
		_tiles_with(TileKind.GROUND.RAMP_DOWN_E), WorldPos.new(0, 0, 1), Vector2(1.4, 0))
	assert_not_null(target, "takes the ramp")
	if target: assert_true(target.equals(WorldPos.new(0, 0, 2)), "one level down, same tile")


func test_moving_uphill_onto_the_up_end_goes_up() -> void:
	var target: WorldPos = Ramp.target_for(
		_tiles_with(TileKind.GROUND.RAMP_UP_E), WorldPos.new(0, 0, 1), Vector2(-1.4, 0))
	assert_not_null(target, "takes the ramp")
	if target: assert_true(target.equals(WorldPos.new(0, 0, 0)), "one level up, same tile")


func test_the_other_directions_are_plain_floor() -> void:
	var down_e: LevelTiles = _tiles_with(TileKind.GROUND.RAMP_DOWN_E)
	for motion: Vector2 in [Vector2(-1.4, 0), Vector2(0, 1.4), Vector2(0, -1.4)]:
		assert_null(Ramp.target_for(down_e, WorldPos.new(0, 0, 1), motion),
			"moving %s onto a down-east ramp" % motion)
	assert_null(Ramp.target_for(_tiles_with(TileKind.GROUND.RAMP_UP_E), WorldPos.new(0, 0, 1),
		Vector2(1.4, 0)), "moving downhill onto the up end doesn't send you back (no bounce)")


func test_only_the_dominant_axis_counts() -> void:
	var down_w: LevelTiles = _tiles_with(TileKind.GROUND.RAMP_DOWN_W)
	assert_not_null(Ramp.target_for(down_w, WorldPos.new(0, 0, 1), Vector2(-1.2, 0.5)),
		"mostly west onto a west ramp")
	assert_null(Ramp.target_for(down_w, WorldPos.new(0, 0, 1), Vector2(-0.5, 1.2)),
		"mostly south passes over it")
	assert_null(Ramp.target_for(down_w, WorldPos.new(0, 0, 1), Vector2(-1, 1)),
		"an exact diagonal has no dominant axis")


func test_a_tile_that_isnt_a_ramp_goes_nowhere() -> void:
	assert_null(Ramp.target_for(_tiles_with(TileKind.GROUND.DIRT), WorldPos.new(0, 0, 1),
		Vector2(1.4, 0)), "plain floor")


# --- load checks (trap 4) ---

func _levels(depths: Array[int]) -> Array[Level]:
	var levels: Array[Level] = []
	for depth in depths:
		var level: Level = Global.level_packed_scene.instantiate()
		autofree(level)
		level.setup(depth)
		level.level_tiles.set_top(RAMP_TILE.x, RAMP_TILE.y, TileKind.TOP.OPEN)
		levels.append(level)
	return levels


func test_the_hand_made_levels_have_no_ramp_problems() -> void:
	var levels: Array[Level] = LevelGenerator.generate_levels(World.level_recipes)
	for level in levels: autofree(level)
	assert_eq(LevelGenerator.ramp_problems(levels), [] as Array[String], "every ramp has its pair")


func test_a_matched_pair_is_fine() -> void:
	var levels: Array[Level] = _levels([0, 1])
	levels[0].level_tiles.set_ground(RAMP_TILE.x, RAMP_TILE.y, TileKind.GROUND.RAMP_DOWN_E)
	levels[1].level_tiles.set_ground(RAMP_TILE.x, RAMP_TILE.y, TileKind.GROUND.RAMP_UP_E)
	assert_eq(LevelGenerator.ramp_problems(levels).size(), 0, "no problems")


func test_a_ramp_without_its_pair_is_reported() -> void:
	var levels: Array[Level] = _levels([0, 1])
	levels[0].level_tiles.set_ground(RAMP_TILE.x, RAMP_TILE.y, TileKind.GROUND.RAMP_DOWN_E)
	var problems: Array[String] = LevelGenerator.ramp_problems(levels)
	assert_eq(problems.size(), 1, "one problem")
	if problems.size() == 1:
		assert_string_contains(problems[0], "has no RAMP_UP_E")


func test_a_pair_facing_different_ways_is_reported() -> void:
	var levels: Array[Level] = _levels([0, 1])
	levels[0].level_tiles.set_ground(RAMP_TILE.x, RAMP_TILE.y, TileKind.GROUND.RAMP_DOWN_E)
	levels[1].level_tiles.set_ground(RAMP_TILE.x, RAMP_TILE.y, TileKind.GROUND.RAMP_UP_W)
	assert_eq(LevelGenerator.ramp_problems(levels).size(), 2, "each end misses its pair")


func test_a_ramp_under_a_solid_top_is_reported() -> void:
	var levels: Array[Level] = _levels([0, 1])
	levels[0].level_tiles.set_ground(RAMP_TILE.x, RAMP_TILE.y, TileKind.GROUND.RAMP_DOWN_E)
	levels[1].level_tiles.set_ground(RAMP_TILE.x, RAMP_TILE.y, TileKind.GROUND.RAMP_UP_E)
	levels[1].level_tiles.set_top(RAMP_TILE.x, RAMP_TILE.y, TileKind.TOP.MINABLE_ROCK)
	var problems: Array[String] = LevelGenerator.ramp_problems(levels)
	assert_eq(problems.size(), 1, "the covered end")
	if problems.size() == 1:
		assert_string_contains(problems[0], "under a solid top")


func test_a_ramp_leading_to_no_level_is_reported() -> void:
	var levels: Array[Level] = _levels([0])
	levels[0].level_tiles.set_ground(RAMP_TILE.x, RAMP_TILE.y, TileKind.GROUND.RAMP_DOWN_E)
	var problems: Array[String] = LevelGenerator.ramp_problems(levels)
	assert_eq(problems.size(), 1, "nowhere to go")
	if problems.size() == 1:
		assert_string_contains(problems[0], "which has no level")


func test_a_ramp_outside_the_other_levels_bounds_is_reported() -> void:
	# -1 is radius 64; (70, 0) is inside the Surface (90) but not -1.
	var levels: Array[Level] = _levels([0, 1])
	levels[0].level_tiles.set_top(70, 0, TileKind.TOP.OPEN)
	levels[0].level_tiles.set_ground(70, 0, TileKind.GROUND.RAMP_DOWN_E)
	assert_eq(LevelGenerator.ramp_problems(levels).size(), 1, "no other end outside -1")


# --- the hand-made pair, walked ---

func _real_levels() -> void:
	for level: Level in LevelGenerator.generate_levels(World.level_recipes):
		add_child_autofree(level)


func _actor_at(tile: Vector2i, depth: int) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", WorldPos.new(tile.x, tile.y, depth), World.get_level_by_depth(depth), ActorKind.ACTOR.PLAYER)
	add_child_autofree(actor)
	return actor


# Walks in small steps, like _physics_process, until the actor changes
# depth or `steps` run out.
func _walk(actor: Actor, motion: Vector2, steps: int = 20) -> void:
	var start_depth: int = actor.depth
	for i in steps:
		actor._move(motion)
		if actor.depth != start_depth: return


func test_the_surface_start_room_has_the_down_end_and_minus_one_the_up_end() -> void:
	_real_levels()
	assert_eq(World.get_level_by_depth(0).level_tiles.get_ground(6, 0), TileKind.GROUND.RAMP_DOWN_E,
		"Surface (6, 0)")
	assert_eq(World.get_level_by_depth(1).level_tiles.get_ground(6, 0), TileKind.GROUND.RAMP_UP_E,
		"-1 (6, 0)")


func test_walking_east_from_the_spawn_takes_the_ramp_down() -> void:
	_real_levels()
	var actor: Actor = _actor_at(Vector2i(5, 0), 0)
	_walk(actor, Vector2(1.4, 0), 12)
	assert_eq(actor.depth, 1, "down on -1")
	assert_eq(Vector2i(actor.current_WorldPos.x, actor.current_WorldPos.y), RAMP_TILE,
		"on the up end, same (x, y)")


func test_arriving_doesnt_bounce_and_walking_on_continues() -> void:
	_real_levels()
	var actor: Actor = _actor_at(Vector2i(5, 0), 0)
	_walk(actor, Vector2(1.4, 0), 30)
	_walk(actor, Vector2(1.4, 0), 30)
	assert_eq(actor.depth, 1, "still on -1 after walking on")
	assert_gt(actor.current_WorldPos.x, RAMP_TILE.x, "and past the ramp, into the home cave")


func test_walking_west_onto_the_up_end_takes_it_up() -> void:
	_real_levels()
	var actor: Actor = _actor_at(Vector2i(7, 0), 1)
	_walk(actor, Vector2(-1.4, 0), 12)
	assert_eq(actor.depth, 0, "back on the Surface")
	assert_eq(Vector2i(actor.current_WorldPos.x, actor.current_WorldPos.y), RAMP_TILE, "on the down end")


func test_walking_into_the_ramp_from_the_side_is_stopped() -> void:
	_real_levels()
	var actor: Actor = _actor_at(Vector2i(6, -1), 0)
	_walk(actor, Vector2(0, 1.4), 12)
	assert_eq(actor.depth, 0, "moving south at an east ramp: still on the Surface")
	assert_eq(Vector2i(actor.current_WorldPos.x, actor.current_WorldPos.y), Vector2i(6, -1),
		"stopped at its north side, like a wall (D-099)")


func test_walking_backwards_still_takes_the_ramp() -> void:
	_real_levels()
	var actor: Actor = _actor_at(Vector2i(5, 0), 0)
	actor.facing = Vector2i(-1, 0)
	_walk(actor, Vector2(1.4, 0), 12)
	assert_eq(actor.depth, 1, "facing west, moving east: down (facing plays no part)")


func test_a_closed_landing_leaves_the_actor_on_the_ramp() -> void:
	_real_levels()
	World.get_level_by_depth(1).level_tiles.set_top(6, 0, TileKind.TOP.MINABLE_ROCK)
	var actor: Actor = _actor_at(Vector2i(5, 0), 0)
	_walk(actor, Vector2(1.4, 0), 12)
	assert_eq(actor.depth, 0, "refused: still on the Surface")


# Arriving on a ramp always puts the actor at its center, so its feet
# never straddle a closed side (D-099).
func test_arriving_on_the_surface_ramp_stands_at_its_center() -> void:
	_real_levels()
	var actor: Actor = _actor_at(Vector2i(7, 0), 1)
	_walk(actor, Vector2(-1.4, 0), 12)
	assert_eq(actor.depth, 0, "up on the Surface")
	assert_eq(actor.position, TileSpace.tile_center(RAMP_TILE), "at the ramp tile's center")


func test_arriving_on_the_minus_one_ramp_stands_at_its_center() -> void:
	_real_levels()
	var actor: Actor = _actor_at(Vector2i(5, 0), 0)
	_walk(actor, Vector2(1.4, 0), 12)
	assert_eq(actor.depth, 1, "went down")
	assert_eq(actor.position, TileSpace.tile_center(RAMP_TILE), "at the up end's center")


func test_after_arriving_the_up_end_only_lets_you_out_downhill() -> void:
	_real_levels()
	var actor: Actor = _actor_at(Vector2i(5, 0), 0)
	_walk(actor, Vector2(1.4, 0), 12)
	for motion: Vector2 in [Vector2(-1.4, 0), Vector2(0, -1.4), Vector2(0, 1.4)]:
		var before: Vector2 = actor.position
		_walk(actor, motion, 12)
		assert_eq(Vector2i(actor.current_WorldPos.x, actor.current_WorldPos.y), RAMP_TILE,
			"moving %s: still on the ramp" % motion)
		actor.position = before
	_walk(actor, Vector2(1.4, 0), 12)
	assert_eq(actor.current_WorldPos.x, RAMP_TILE.x + 1, "moving east: off it, into the cave")


func test_f3_prints_a_ramp_as_its_letter() -> void:
	_real_levels()
	var overlay: CanvasLayer = preload("res://src/debug/debug_overlay.tscn").instantiate()
	add_child_autofree(overlay)
	var tiles: LevelTiles = World.get_level_by_depth(0).level_tiles
	assert_eq(overlay._tile_char(tiles, 6, 0, WorldPos.new(0, 0, 0)), "e", "the down-east end")


# --- closed sides, edge by edge (D-099) ---

# A small level, all open floor, with one ramp at the origin.
func _open_tiles_with_ramp(kind: int) -> LevelTiles:
	var tiles: LevelTiles = LevelTiles.new(LevelBound.new(1, "Unit Test", 4))
	for y in range(-4, 5):
		for x in range(-4, 5):
			tiles.set_top(x, y, TileKind.TOP.OPEN)
	tiles.set_ground(0, 0, kind)
	return tiles


func test_a_down_end_opens_only_on_its_uphill_side() -> void:
	var tiles: LevelTiles = _open_tiles_with_ramp(TileKind.GROUND.RAMP_DOWN_E)
	var ramp: Vector2i = Vector2i.ZERO
	assert_true(TileCollision.edge_open(tiles, Vector2i(-1, 0), ramp), "in from the west (uphill)")
	assert_true(TileCollision.edge_open(tiles, ramp, Vector2i(-1, 0)), "and back out west")
	for side: Vector2i in [Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		assert_false(TileCollision.edge_open(tiles, side, ramp), "not in from %s" % side)
		assert_false(TileCollision.edge_open(tiles, ramp, side), "not out to %s" % side)


func test_an_up_end_opens_only_on_its_downhill_side() -> void:
	var tiles: LevelTiles = _open_tiles_with_ramp(TileKind.GROUND.RAMP_UP_E)
	var ramp: Vector2i = Vector2i.ZERO
	assert_true(TileCollision.edge_open(tiles, Vector2i(1, 0), ramp), "in from the east (downhill)")
	assert_true(TileCollision.edge_open(tiles, ramp, Vector2i(1, 0)), "and back out east")
	for side: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		assert_false(TileCollision.edge_open(tiles, side, ramp), "not in from %s" % side)
		assert_false(TileCollision.edge_open(tiles, ramp, side), "not out to %s" % side)


func test_edges_between_plain_floor_are_open() -> void:
	var tiles: LevelTiles = _open_tiles_with_ramp(TileKind.GROUND.RAMP_DOWN_E)
	assert_true(TileCollision.edge_open(tiles, Vector2i(2, 2), Vector2i(3, 2)), "away from the ramp")


func test_a_box_is_stopped_flush_at_a_closed_side() -> void:
	var tiles: LevelTiles = _open_tiles_with_ramp(TileKind.GROUND.RAMP_DOWN_E)
	# A 10 x 6 box in tile (1, 0), moving west into the ramp's closed east side.
	var box: Rect2 = Rect2(Vector2(19, 5), Vector2(10, 6))
	var moved: Rect2 = TileCollision.move_box(tiles, box, Vector2(-8, 0))
	assert_eq(moved.position.x, 16.0, "flush against the ramp's east edge")


func test_a_box_passes_through_the_open_side() -> void:
	var tiles: LevelTiles = _open_tiles_with_ramp(TileKind.GROUND.RAMP_DOWN_E)
	# A box in tile (-1, 0), moving east into the ramp's open west side.
	var box: Rect2 = Rect2(Vector2(-13, 5), Vector2(10, 6))
	var moved: Rect2 = TileCollision.move_box(tiles, box, Vector2(8, 0))
	assert_eq(moved.position.x, -5.0, "moved the full 8 px")
