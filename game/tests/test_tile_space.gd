extends GutTest

# TileSpace -- the tile <-> pixel convention shared by simulation and
# presentation (D-067). Moved here from test_level_renderer.gd along
# with tile_center itself.


func test_a_tile_is_sixteen_pixels() -> void:
	assert_eq(TileSpace.TILE_PIXELS, 16,
		"tile art and every conversion assume 16 px tiles")


func test_tile_centers_sit_half_a_tile_into_each_tile() -> void:
	assert_eq(TileSpace.tile_center(Vector2i(0, 0)), Vector2(8, 8),
		"tile (0, 0)'s top-left corner is the level's origin")
	assert_eq(TileSpace.tile_center(Vector2i(2, 1)), Vector2(40, 24),
		"each tile is 16 px further along")
	assert_eq(TileSpace.tile_center(Vector2i(-1, -1)), Vector2(-8, -8),
		"negative tiles sit up and to the left of the origin, not on it")


# --- facing ---

# A direction `degrees` clockwise from right. +y is down the screen,
# so 90 is down and -90 is up.
func _dir(degrees: float) -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(degrees))


const RIGHT: Vector2i = Vector2i(1, 0)
const DOWN: Vector2i = Vector2i(0, 1)
const LEFT: Vector2i = Vector2i(-1, 0)
const UP: Vector2i = Vector2i(0, -1)


func test_facing_offset_snaps_to_the_axis_a_direction_leans_on() -> void:
	assert_eq(TileSpace.get_facing_offset(_dir(10)), RIGHT, "10° leans right")
	assert_eq(TileSpace.get_facing_offset(_dir(80)), DOWN, "80° leans down")
	assert_eq(TileSpace.get_facing_offset(_dir(170)), LEFT, "170° leans left")
	assert_eq(TileSpace.get_facing_offset(_dir(-80)), UP, "-80° leans up")


func test_facing_offset_breaks_an_exact_diagonal_tie_horizontally() -> void:
	assert_eq(TileSpace.get_facing_offset(Vector2(1, 1)), RIGHT,
		"exactly 45° goes to the horizontal neighbor, every time")


# The hysteresis band: facing switches only once the direction is
# more than 45° + FACING_HYSTERESIS_DEG away from the current facing.

func test_snap_facing_holds_inside_the_band() -> void:
	assert_eq(TileSpace.snap_facing(RIGHT, _dir(50)), RIGHT,
		"facing right, 50° is inside the band: stays right")
	assert_eq(TileSpace.snap_facing(DOWN, _dir(50)), DOWN,
		"facing down, 50° (40° from down) is inside the band: stays down")


func test_snap_facing_switches_past_the_band() -> void:
	assert_eq(TileSpace.snap_facing(RIGHT, _dir(60)), DOWN,
		"facing right, 60° is past the band: switches down")
	assert_eq(TileSpace.snap_facing(DOWN, _dir(30)), RIGHT,
		"facing down, 30° (60° from down) is past the band: switches right")


func test_snap_facing_turns_around_at_once() -> void:
	assert_eq(TileSpace.snap_facing(RIGHT, _dir(180)), LEFT,
		"aiming straight behind switches immediately")


func test_snap_facing_keeps_facing_with_no_direction() -> void:
	for current: Vector2i in [RIGHT, DOWN, LEFT, UP]:
		assert_eq(TileSpace.snap_facing(current, Vector2.ZERO), current,
			"no input keeps %s" % current)


# The band's edge is 45° + the margin; just either side of it.
func test_snap_facing_band_edge_follows_the_constant() -> void:
	var edge: float = 45.0 + TileSpace.FACING_HYSTERESIS_DEG
	assert_eq(TileSpace.snap_facing(RIGHT, _dir(edge - 0.5)), RIGHT,
		"just inside the edge holds")
	assert_eq(TileSpace.snap_facing(RIGHT, _dir(edge + 0.5)), DOWN,
		"just past the edge switches")


# The case the band exists for: a thumb resting on the diagonal.
func test_wobble_across_the_diagonal_does_not_flip_facing() -> void:
	var facing: Vector2i = RIGHT
	for degrees: float in [44.0, 46.0, 44.0, 46.0, 43.0, 47.0]:
		facing = TileSpace.snap_facing(facing, _dir(degrees))
		assert_eq(facing, RIGHT, "wobbling at %s° stays right" % degrees)


# A keyboard diagonal is exactly 45° from both neighbors (D-076).
func test_a_keyboard_diagonal_keeps_the_previous_facing() -> void:
	assert_eq(TileSpace.snap_facing(UP, Vector2(1, -1)), UP,
		"facing up, walking up-right keeps up")
	assert_eq(TileSpace.snap_facing(RIGHT, Vector2(1, -1)), RIGHT,
		"facing right, walking up-right keeps right")
