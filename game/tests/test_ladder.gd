extends GutTest

# Ladder -- where interact takes an actor (D-089, D-101). Down: facing
# a hole with a ladder under it. Up: standing on a ladder, arriving
# beside the hole on the faced side if open, else north, east, south,
# west.

# The shaft: a hole on the Surface at (0, 0), a ladder under it on -1.
const SHAFT: Vector2i = Vector2i.ZERO

var _world: World
var _surface: Level
var _below: Level


func before_each() -> void:
	_world = autofree(World.new())
	_surface = _level(0)
	_below = _level(1)
	for y in range(-2, 3):
		for x in range(-2, 3):
			_surface.level_tiles.set_top(x, y, TileKind.TOP.OPEN)
			_below.level_tiles.set_top(x, y, TileKind.TOP.OPEN)
	_surface.level_tiles.set_ground(SHAFT.x, SHAFT.y, TileKind.GROUND.HOLE)
	_below.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(SHAFT.x, SHAFT.y, 1), 1))


func _level(depth: int) -> Level:
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(depth)
	_world.add_level(level)
	return level


func _target(x: int, y: int, depth: int, facing: Vector2i) -> WorldPos:
	return Ladder.target_for(_world.level_at(depth), WorldPos.new(x, y, depth), facing)


func _assert_at(target: WorldPos, expected: WorldPos, message: String) -> void:
	assert_not_null(target, message)
	if target: assert_true(target.equals(expected), "%s: got %s" % [message, target])


# --- down ---

func test_facing_a_hole_with_a_ladder_below_goes_down_onto_it() -> void:
	_assert_at(_target(0, 1, 0, Vector2i(0, -1)), WorldPos.new(0, 0, 1), "from the south, facing north")
	_assert_at(_target(-1, 0, 0, Vector2i(1, 0)), WorldPos.new(0, 0, 1), "from the west, facing east")


func test_a_bare_hole_goes_nowhere() -> void:
	_below.level_fixtures.remove(1)
	assert_null(_target(0, 1, 0, Vector2i(0, -1)), "no ladder under it (D-089)")


func test_not_facing_the_hole_goes_nowhere() -> void:
	assert_null(_target(0, 1, 0, Vector2i(0, 1)), "facing away")
	assert_null(_target(1, 1, 0, Vector2i(0, -1)), "facing open floor beside it")


func test_a_hole_on_the_deepest_level_goes_nowhere() -> void:
	_below.level_tiles.set_ground(1, 1, TileKind.GROUND.HOLE)
	assert_null(_target(1, 2, 1, Vector2i(0, -1)), "no level 2 here, so no ladder below")


# --- up ---

func test_on_the_ladder_facing_open_floor_arrives_on_that_side() -> void:
	_assert_at(_target(0, 0, 1, Vector2i(0, 1)), WorldPos.new(0, 1, 0), "facing south")
	_assert_at(_target(0, 0, 1, Vector2i(-1, 0)), WorldPos.new(-1, 0, 0), "facing west")


func test_a_blocked_faced_side_falls_back_to_north_east_south_west() -> void:
	_surface.level_tiles.set_top(0, 1, TileKind.TOP.MINABLE_ROCK)
	_assert_at(_target(0, 0, 1, Vector2i(0, 1)), WorldPos.new(0, -1, 0), "south is rock: north")
	_surface.level_tiles.set_top(0, -1, TileKind.TOP.MINABLE_ROCK)
	_assert_at(_target(0, 0, 1, Vector2i(0, 1)), WorldPos.new(1, 0, 0), "north too: east")


func test_arrival_skips_holes_and_ramps() -> void:
	_surface.level_tiles.set_ground(0, -1, TileKind.GROUND.HOLE)
	_surface.level_tiles.set_ground(1, 0, TileKind.GROUND.RAMP_DOWN_E)
	_assert_at(_target(0, 0, 1, Vector2i.ZERO), WorldPos.new(0, 1, 0), "north is a hole, east a ramp: south")


func test_every_side_blocked_goes_nowhere() -> void:
	for side: Vector2i in Ladder.ARRIVAL_ORDER:
		_surface.level_tiles.set_top(side.x, side.y, TileKind.TOP.MINABLE_ROCK)
	assert_null(_target(0, 0, 1, Vector2i(0, 1)), "nowhere to stand")


func test_a_ladder_with_its_hole_filled_goes_nowhere() -> void:
	_surface.level_tiles.set_ground(SHAFT.x, SHAFT.y, TileKind.GROUND.DIRT)
	assert_null(_target(0, 0, 1, Vector2i(0, 1)), "no hole above")


func test_standing_next_to_the_ladder_doesnt_climb() -> void:
	assert_null(_target(1, 0, 1, Vector2i(-1, 0)), "facing the ladder isn't standing on it (D-101)")


# --- the hand-made shaft ---

func test_the_worked_example_from_the_lesson() -> void:
	# Real levels: hole on -1 at (14, -2), ladder on -2 under it.
	_world = autofree(LevelGenerator.generate_world(0))
	_assert_at(_target(14, -1, 1, Vector2i(0, -1)), WorldPos.new(14, -2, 2), "down from (14, -1) facing north")
	_assert_at(_target(14, -2, 2, Vector2i(0, -1)), WorldPos.new(15, -2, 1),
		"still facing north, (14, -3) is rock: up at (15, -2), east")
	_assert_at(_target(14, -2, 2, Vector2i(0, 1)), WorldPos.new(14, -1, 1), "facing south: back where you started")



# D-139: on the ladder up from -1, facing a neighboring hole with a
# ladder down to -2 under it. Facing the hole goes down; turning away
# climbs.
func _neighboring_shafts() -> Vector2i:
	var deeper: Level = _level(2)
	for y in range(-2, 3):
		for x in range(-2, 3):
			deeper.level_tiles.set_top(x, y, TileKind.TOP.OPEN)
	var shaft: Vector2i = SHAFT + Vector2i(1, 0)
	_below.level_tiles.set_ground(shaft.x, shaft.y, TileKind.GROUND.HOLE)
	deeper.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.LADDER,
		WorldPos.new(shaft.x, shaft.y, 2), 2))
	return shaft


func test_on_a_ladder_facing_a_usable_hole_goes_down() -> void:
	var shaft: Vector2i = _neighboring_shafts()
	_assert_at(_target(SHAFT.x, SHAFT.y, 1, Vector2i(1, 0)),
		WorldPos.new(shaft.x, shaft.y, 2), "facing the other shaft: down it")


func test_on_a_ladder_turned_away_from_the_hole_climbs() -> void:
	_neighboring_shafts()
	_assert_at(_target(SHAFT.x, SHAFT.y, 1, Vector2i(-1, 0)),
		WorldPos.new(SHAFT.x - 1, SHAFT.y, 0), "facing west: up, arriving west")


func test_a_level_in_no_world_has_no_ladder_target() -> void:
	var loose: Level = autofree(Global.level_packed_scene.instantiate())
	loose.setup(1)
	assert_null(Ladder.target_for(loose, WorldPos.new(0, 0, 1), Vector2i(0, -1)), "no target")
	assert_push_error("is in no world")
