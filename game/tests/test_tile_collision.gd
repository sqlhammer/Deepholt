extends GutTest

# TileCollision.move_box: per-axis movement against tile data, with
# the blocked axis snapped flush to the wall. Every level starts as
# solid rock, so each test carves out only the open tiles it needs.
# Pixel = 16 * tile: tile 2 starts at pixel 32.

const NEAR: Vector2 = Vector2(0.0001, 0.0001)

var _tiles: LevelTiles


func before_each() -> void:
	_tiles = LevelTiles.new(World.level_bounds.rows[0])


# Opens every tile from `from` to `to`, inclusive.
func _open(from: Vector2i, to: Vector2i) -> void:
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			_tiles.set_top(x, y, TileKind.TOP.OPEN)


func _move(box: Rect2, motion: Vector2) -> Rect2:
	return TileCollision.move_box(_tiles, box, motion)


# --- sliding ---

# A two-wide corridor running down, rock from column 2 (pixel 32).
# The box starts flush against that wall, so X has nowhere to go.
func test_diagonal_into_a_wall_on_the_right_slides_down_it() -> void:
	_open(Vector2i(0, -3), Vector2i(1, 3))
	var box: Rect2 = Rect2(22, 4, 10, 6)
	var moved: Rect2 = _move(box, Vector2(1.4, 1.4))
	assert_almost_eq(moved.position.x, 22.0, NEAR.x,
		"X is blocked by the wall and stays flush")
	assert_almost_eq(moved.position.y, 5.4, NEAR.y,
		"Y is free and moves the full motion.y")


# A 2 x 2 room; the box sits flush in its bottom-right corner.
func test_diagonal_into_an_inside_corner_does_not_move() -> void:
	_open(Vector2i(0, 0), Vector2i(1, 1))
	var box: Rect2 = Rect2(22, 26, 10, 6)
	var moved: Rect2 = _move(box, Vector2(1.4, 1.4))
	assert_almost_eq(moved.position, box.position, NEAR,
		"walls right and below block both axes")


# Everything open except tile (1, 1), diagonally down-right of the
# box. Moving only along X misses it, and so does moving only along
# Y from the start -- only the combined diagonal enters it. This is
# the test that fails if both axes are tested from the original box.
func test_diagonal_past_an_outer_corner_does_not_clip_it() -> void:
	_open(Vector2i(-1, -1), Vector2i(2, 2))
	_tiles.set_top(1, 1, TileKind.TOP.MINABLE_ROCK)
	var box: Rect2 = Rect2(5, 10, 10, 6)
	var moved: Rect2 = _move(box, Vector2(1.4, 1.4))
	var rock: Rect2 = Rect2(16, 16, 16, 16)
	assert_false(moved.intersects(rock),
		"the result does not overlap the corner tile")
	assert_almost_eq(moved.position.x, 6.4, NEAR.x, "X moves")
	assert_almost_eq(moved.position.y, 10.0, NEAR.y,
		"Y is held, so it moves along one axis only")


# --- snapping flush, one per direction ---

# A 2 x 2 room spanning pixels 0..32 on both axes.

func test_moving_right_into_a_wall_stops_flush_against_it() -> void:
	_open(Vector2i(0, 0), Vector2i(1, 1))
	var moved: Rect2 = _move(Rect2(21.5, 4, 10, 6), Vector2(1.4, 0))
	assert_eq(moved.end.x, 32.0, "right edge lands on the wall at 32")
	assert_eq(_move(moved, Vector2(1.4, 0)), moved,
		"pushing again changes nothing")


func test_moving_left_into_a_wall_stops_flush_against_it() -> void:
	_open(Vector2i(0, 0), Vector2i(1, 1))
	var moved: Rect2 = _move(Rect2(0.5, 4, 10, 6), Vector2(-1.4, 0))
	assert_eq(moved.position.x, 0.0, "left edge lands on the wall at 0")
	assert_eq(_move(moved, Vector2(-1.4, 0)), moved,
		"pushing again changes nothing")


func test_moving_down_into_a_wall_stops_flush_against_it() -> void:
	_open(Vector2i(0, 0), Vector2i(1, 1))
	var moved: Rect2 = _move(Rect2(4, 25.5, 10, 6), Vector2(0, 1.4))
	assert_eq(moved.end.y, 32.0, "bottom edge lands on the wall at 32")
	assert_eq(_move(moved, Vector2(0, 1.4)), moved,
		"pushing again changes nothing")


func test_moving_up_into_a_wall_stops_flush_against_it() -> void:
	_open(Vector2i(0, 0), Vector2i(1, 1))
	var moved: Rect2 = _move(Rect2(4, 0.5, 10, 6), Vector2(0, -1.4))
	assert_eq(moved.position.y, 0.0, "top edge lands on the wall at 0")
	assert_eq(_move(moved, Vector2(0, -1.4)), moved,
		"pushing again changes nothing")


# --- leaving a wall ---

# A box flush against a right or bottom wall has its far edge exactly
# on a tile boundary. Without the exclusive far edge (- epsilon), it
# counts as inside the wall and every move is refused.

func test_flush_against_a_right_wall_can_move_away() -> void:
	_open(Vector2i(0, 0), Vector2i(1, 1))
	var moved: Rect2 = _move(Rect2(22, 4, 10, 6), Vector2(-1.4, 0))
	assert_almost_eq(moved.position.x, 20.6, NEAR.x, "moves left freely")


func test_flush_against_a_bottom_wall_can_move_away() -> void:
	_open(Vector2i(0, 0), Vector2i(1, 1))
	var moved: Rect2 = _move(Rect2(4, 26, 10, 6), Vector2(0, -1.4))
	assert_almost_eq(moved.position.y, 24.6, NEAR.y, "moves up freely")


func test_flush_against_a_right_wall_can_slide_along_it() -> void:
	_open(Vector2i(0, 0), Vector2i(1, 1))
	var moved: Rect2 = _move(Rect2(22, 4, 10, 6), Vector2(0, 1.4))
	assert_almost_eq(moved.position, Vector2(22, 5.4), NEAR,
		"moves along the wall, not stuck to it")
