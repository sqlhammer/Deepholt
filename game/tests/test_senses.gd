extends GutTest

# The sense flood (D-145), also light's (D-149): breadth-first through
# open tiles up to the radius in steps, plus the rock faces bordering
# what it reaches. Rock behind a face is never reached.

const Worlds = preload("res://tests/worlds.gd")

var _tiles: LevelTiles


# A blank level: solid minable rock, with open tiles cut into it.
func before_each() -> void:
	var world: World = autofree(Worlds.with_levels([1]))
	_tiles = world.level_at(1).level_tiles


func _open(tiles: Array[Vector2i]) -> void:
	for tile: Vector2i in tiles:
		_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)


func _row(from_x: int, to_x: int, y: int) -> Array[Vector2i]:
	var row: Array[Vector2i] = []
	for x in range(from_x, to_x + 1):
		row.append(Vector2i(x, y))
	return row


func _flood(from: Vector2i, radius: int) -> Array[Vector2i]:
	return Senses.flood(_tiles, from, radius)


func test_a_corridor_is_reached_to_the_radius_with_its_walls() -> void:
	_open(_row(-10, 10, 0))
	var reached: Array[Vector2i] = _flood(Vector2i.ZERO, 3)
	for x in range(-3, 4):
		assert_has(reached, Vector2i(x, 0), "open (%d, 0)" % x)
		assert_has(reached, Vector2i(x, -1), "its north wall")
		assert_has(reached, Vector2i(x, 1), "its south wall")
	assert_does_not_have(reached, Vector2i(4, 0), "past the radius, east")
	assert_does_not_have(reached, Vector2i(-4, 0), "and west")


func test_the_start_comes_first() -> void:
	_open(_row(-2, 2, 0))
	assert_eq(_flood(Vector2i.ZERO, 2)[0], Vector2i.ZERO, "the actor's own tile")


func test_rock_behind_a_wall_is_never_reached() -> void:
	_open(_row(-3, 3, 0))
	var reached: Array[Vector2i] = _flood(Vector2i.ZERO, 7)
	assert_has(reached, Vector2i(0, -1), "the wall's face")
	assert_does_not_have(reached, Vector2i(0, -2), "the rock behind it")


func test_it_reaches_round_a_corner_within_the_radius() -> void:
	var path: Array[Vector2i] = _row(0, 3, 0)
	path.append_array([Vector2i(3, -1), Vector2i(3, -2), Vector2i(3, -3)])
	_open(path)
	var reached: Array[Vector2i] = _flood(Vector2i.ZERO, 5)
	assert_has(reached, Vector2i(3, -2), "five steps, round the bend")
	assert_does_not_have(reached, Vector2i(3, -3), "six steps is too far")


# You can sense across a shaft you can't walk over.
func test_a_hole_is_crossed() -> void:
	_open(_row(0, 3, 0))
	_tiles.set_ground(1, 0, TileKind.GROUND.HOLE)
	assert_has(_flood(Vector2i.ZERO, 3), Vector2i(3, 0), "past the hole")


func test_radius_zero_is_the_tile_and_its_faces() -> void:
	_open([Vector2i.ZERO])
	var reached: Array[Vector2i] = _flood(Vector2i.ZERO, 0)
	assert_eq(reached.size(), 5, "the tile and four walls: %s" % [reached])


func test_a_flood_from_rock_reaches_only_its_tile() -> void:
	assert_eq(_flood(Vector2i.ZERO, 7), [Vector2i.ZERO] as Array[Vector2i], "nowhere to spread")


func test_each_tile_is_reached_once() -> void:
	for y in range(-2, 3):
		_open(_row(-2, 2, y))
	var reached: Array[Vector2i] = _flood(Vector2i.ZERO, 7)
	var seen: Dictionary = {}
	for tile: Vector2i in reached:
		assert_false(seen.has(tile), "%s once" % tile)
		seen[tile] = true


# The level's edge is a sentinel: neither open nor a face.
func test_the_edge_of_the_level_stops_it() -> void:
	var radius: int = _tiles.level_bound.radius
	_open(_row(radius - 2, radius, 0))
	var reached: Array[Vector2i] = _flood(Vector2i(radius, 0), 5)
	assert_does_not_have(reached, Vector2i(radius + 1, 0), "past the edge")
