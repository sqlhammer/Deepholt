extends GutTest

# Holes (D-089, D-101): ground HOLE under an open top is a dead tile.
# An actor can't stand on it or walk onto it from any side; it is
# authored as 'h' on the ground grid, only under an open top.


# --- passability: one owner, TileKind.is_passable ---

func test_open_floor_is_passable() -> void:
	assert_true(TileKind.is_passable(TileKind.TOP.OPEN, TileKind.GROUND.ROCK), "open over rock")
	assert_true(TileKind.is_passable(TileKind.TOP.OPEN, TileKind.GROUND.DIRT), "open over dirt")
	assert_true(TileKind.is_passable(TileKind.TOP.OPEN, TileKind.GROUND.RAMP_DOWN_E),
		"open over a ramp (its sides are an edge rule, D-099)")


func test_a_hole_is_not_passable() -> void:
	assert_false(TileKind.is_passable(TileKind.TOP.OPEN, TileKind.GROUND.HOLE), "open over a hole")


func test_solid_tops_are_not_passable() -> void:
	for top: int in [TileKind.TOP.MINABLE_ROCK, TileKind.TOP.MINABLE_DIRT,
			TileKind.TOP.IMPENETRABLE_ROCK, TileKind.TOP.NULL]:
		assert_false(TileKind.is_passable(top, TileKind.GROUND.ROCK), "top %d" % top)


func test_outside_the_level_is_not_passable() -> void:
	for sentinel: int in [TileKind.SENTINEL_OUT_OF_BOUNDS, TileKind.SENTINEL_OUT_OF_ARRAY]:
		assert_false(TileKind.is_passable(sentinel, sentinel), "sentinel %d" % sentinel)
		assert_false(TileKind.is_passable(TileKind.TOP.OPEN, sentinel), "open over sentinel %d" % sentinel)


# --- walking into a hole ---

# A small level, all open floor, with a hole at the origin.
func _open_tiles_with_hole() -> LevelTiles:
	var tiles: LevelTiles = LevelTiles.new(LevelBound.new(1, "Unit Test", 4))
	for y in range(-4, 5):
		for x in range(-4, 5):
			tiles.set_top(x, y, TileKind.TOP.OPEN)
	tiles.set_ground(0, 0, TileKind.GROUND.HOLE)
	return tiles


# A 10 x 6 box centered in `tile`, moved 12 px toward the hole at the
# origin, from each side. It stops flush at the hole's edge.
func test_a_box_cant_move_onto_a_hole_from_any_side() -> void:
	var tiles: LevelTiles = _open_tiles_with_hole()
	var size: Vector2 = Vector2(10, 6)
	var cases: Array = [
		# [start tile, motion, the coordinate it must stop at, which axis]
		[Vector2i(1, 0), Vector2(-12, 0), 16.0, "x"],   # from the east, left edge at x 16
		[Vector2i(-1, 0), Vector2(12, 0), 0.0 - size.x, "x"],   # from the west, right edge at x 0
		[Vector2i(0, 1), Vector2(0, -12), 16.0, "y"],   # from the south, top edge at y 16
		[Vector2i(0, -1), Vector2(0, 12), 0.0 - size.y, "y"],   # from the north, bottom edge at y 0
	]
	for case in cases:
		var start: Vector2 = TileSpace.tile_center(case[0]) - size / 2.0
		var moved: Rect2 = TileCollision.move_box(tiles, Rect2(start, size), case[1])
		var stopped_at: float = moved.position.x if case[3] == "x" else moved.position.y
		assert_eq(stopped_at, case[2], "from %s: stopped flush at the hole" % case[0])


func test_a_box_cant_be_placed_on_a_hole() -> void:
	var tiles: LevelTiles = _open_tiles_with_hole()
	var on_hole: Rect2 = Rect2(TileSpace.tile_center(Vector2i.ZERO) - Vector2(5, 3), Vector2(10, 6))
	assert_false(TileCollision.fits(tiles, on_hole), "nothing can stand on a hole")


func test_an_actor_walking_at_a_hole_stops_beside_it() -> void:
	for depth in [0]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		add_child_autofree(level)
		for y in range(-3, 4):
			for x in range(-3, 4):
				level.level_tiles.set_top(x, y, TileKind.TOP.OPEN)
		level.level_tiles.set_ground(0, 0, TileKind.GROUND.HOLE)
	for side: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		var actor: Actor = Actor.create(Global.actor_packed_scene, "Test", WorldPos.new(side.x, side.y, 0), World.get_level_by_depth(0))
		add_child_autofree(actor)
		var toward: Vector2 = Vector2(-side) / 2.0 * 1.4
		for i in 40:
			actor._move(toward)
		var tile: Vector2i = Vector2i(actor.current_WorldPos.x, actor.current_WorldPos.y)
		assert_eq(tile, side / 2, "from %s the actor stops on the tile next to the hole" % side)


# --- authoring ---

func _stamp(ground: String, top: String, ore: String) -> Array:
	var tiles: LevelTiles = LevelTiles.new(LevelBound.new(0, "Unit Test", 4))
	var ok: bool = LevelGridLoader.stamp(tiles, TilePrefab.from_grids(&"test_holes", ground, top, ore), Vector2i.ZERO)
	return [ok, tiles]


func test_h_loads_as_a_hole_under_an_open_top() -> void:
	var result: Array = _stamp("h0", ".0", ".0")
	assert_true(result[0], "a hole under open floor loads")
	assert_eq(result[1].get_ground(-1, 0), TileKind.GROUND.HOLE, "'h' is a hole")
	assert_eq(result[1].get_top(-1, 0), TileKind.TOP.OPEN, "under an open top")


func test_h_under_a_solid_top_fails_to_load() -> void:
	var result: Array = _stamp("h0", "#0", ".0")
	assert_false(result[0], "a hole under rock is rejected")
	assert_eq(result[1].get_ground(-1, 0), TileKind.GROUND.ROCK, "and nothing was written")


# A hole the top grid doesn't cover is half-described, so the prefab
# fails to load before the hole is even checked (D-102).
func test_h_under_a_top_the_grid_never_mentions_fails_to_load() -> void:
	var result: Array = _stamp("h0", "0", ".0")
	assert_false(result[0], "a hole under the default rock is rejected")
	assert_eq(result[1].get_ground(-1, 0), TileKind.GROUND.ROCK, "and nothing was written")


# --- seeing it ---

func test_f3_names_a_hole() -> void:
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(0)
	add_child_autofree(level)
	level.level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	level.level_tiles.set_ground(0, 0, TileKind.GROUND.HOLE)
	var overlay: CanvasLayer = preload("res://src/debug/debug_overlay.tscn").instantiate()
	add_child_autofree(overlay)
	assert_string_contains(overlay._tile_readout(WorldPos.new(0, 0, 0)), "ground HOLE",
		"the readout names the hole")


func test_a_hole_draws_with_its_own_cell() -> void:
	var renderer: LevelRenderer = LevelRenderer.new()
	autofree(renderer)
	assert_eq(renderer._ground_cells()[TileKind.GROUND.HOLE], LevelRenderer.AtlasCell.HOLE,
		"ground HOLE draws the hole cell, not MISSING")
