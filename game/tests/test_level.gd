extends GutTest

# Level's anchor and the positions derived from it. The anchor is
# where a prefab's marker lands (D-060), and the marker tile is open
# floor in the top grid (D-056), which is what makes it a safe spawn.

const ANCHOR: Vector2i = Vector2i(2, -3)


func _level_at(anchor: Vector2i) -> Level:
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(0, TilePrefabRegistry.get_prefab(&"surface_start"), anchor)
	add_child_autofree(level)
	return level


func test_setup_stores_the_anchor() -> void:
	var level: Level = _level_at(ANCHOR)
	assert_eq(level.anchor, ANCHOR, "the anchor given to setup is kept")


func test_anchor_defaults_to_the_origin() -> void:
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(1)
	add_child_autofree(level)
	assert_eq(level.anchor, Vector2i.ZERO,
		"a level set up without an anchor is anchored on (0, 0)")


func test_the_anchor_tile_is_open_floor() -> void:
	var level: Level = _level_at(ANCHOR)
	assert_eq(level.level_tiles.get_top(ANCHOR.x, ANCHOR.y), TileKind.TOP.OPEN,
		"spawning on the anchor never starts an actor inside rock")


func test_anchor_position_is_the_anchor_tile_center() -> void:
	var level: Level = _level_at(ANCHOR)
	assert_eq(level.get_anchor_global_position(), Vector2(40, -40),
		"tile (2, -3) is centered at (40, -40) with the level at origin")


func test_spawn_position_is_the_anchor_tile_center() -> void:
	var level: Level = _level_at(ANCHOR)
	assert_eq(level.get_spawn_global_position(), Vector2(40, -40),
		"tile (2, -3) is centered at (40, -40) with the level at origin")


# The point of "global": if the level node moves, the answer moves
# with it, rather than staying in the level's own space.
func test_positions_follow_the_level_node() -> void:
	var level: Level = _level_at(ANCHOR)
	level.position = Vector2(100, 50)
	assert_eq(level.get_anchor_global_position(), Vector2(140, 10),
		"the anchor position includes the level node's offset")
	assert_eq(level.get_spawn_global_position(), Vector2(140, 10),
		"the spawn position includes the level node's offset")
