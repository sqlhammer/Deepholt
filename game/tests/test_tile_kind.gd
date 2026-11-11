extends GutTest

# TileKind — the ground/top/ore kind ids from D-051, D-052 and D-056,
# gathered into one table so every layer's valid ids can be enumerated
# and checked against LevelTiles' reserved sentinels (D-059).


func test_ground_kind_ids_avoid_sentinels() -> void:
	for id in TileKind.GROUND.values():
		assert_ne(id, TileKind.SENTINEL_OUT_OF_ARRAY,
			"ground kind %d collides with the out-of-array sentinel" % id)
		assert_ne(id, TileKind.SENTINEL_OUT_OF_BOUNDS,
			"ground kind %d collides with the out-of-bounds sentinel" % id)


func test_top_kind_ids_avoid_sentinels() -> void:
	for id in TileKind.TOP.values():
		assert_ne(id, TileKind.SENTINEL_OUT_OF_ARRAY,
			"top kind %d collides with the out-of-array sentinel" % id)
		assert_ne(id, TileKind.SENTINEL_OUT_OF_BOUNDS,
			"top kind %d collides with the out-of-bounds sentinel" % id)


func test_ore_kind_ids_avoid_sentinels() -> void:
	for id in TileKind.ORE.values():
		assert_ne(id, TileKind.SENTINEL_OUT_OF_ARRAY,
			"ore kind %d collides with the out-of-array sentinel" % id)
		assert_ne(id, TileKind.SENTINEL_OUT_OF_BOUNDS,
			"ore kind %d collides with the out-of-bounds sentinel" % id)



# --- sentinels ---

func test_only_the_two_reserved_ids_are_sentinels() -> void:
	assert_true(TileKind.is_sentinel(TileKind.SENTINEL_OUT_OF_ARRAY), "255 is")
	assert_true(TileKind.is_sentinel(TileKind.SENTINEL_OUT_OF_BOUNDS), "254 is")
	for id: int in [0, 1, 2, 3, 4, 200, 253]:
		assert_false(TileKind.is_sentinel(id), "%d is not (D-059 reserves 254 and 255)" % id)


# --- what can be dug ---

func test_minable_kinds_are_diggable() -> void:
	assert_true(TileKind.is_diggable(TileKind.TOP.MINABLE_ROCK), "rock")
	assert_true(TileKind.is_diggable(TileKind.TOP.MINABLE_DIRT), "dirt")


func test_other_kinds_are_not_diggable() -> void:
	for kind_name: String in ["NULL", "OPEN", "IMPENETRABLE_ROCK"]:
		assert_false(TileKind.is_diggable(TileKind.TOP[kind_name]), kind_name)
	assert_false(TileKind.is_diggable(TileKind.SENTINEL_OUT_OF_BOUNDS), "outside the level")
	assert_false(TileKind.is_diggable(TileKind.SENTINEL_OUT_OF_ARRAY), "past the array")


# --- ids are forever ---

# A save stores these numbers. Renumbering, reordering or reusing one
# makes every old save read as the wrong kinds, so the table is
# pinned: a new kind adds a new number, and nothing here ever changes
# (trap 8).
func test_existing_kind_ids_never_change() -> void:
	assert_eq(TileKind.GROUND, {
		"NULL": 0, "ROCK": 1, "DIRT": 2, "GRASS": 3, "WATER": 4, "HOLE": 5,
		"RAMP_DOWN_N": 6, "RAMP_UP_N": 7, "RAMP_DOWN_E": 8, "RAMP_UP_E": 9,
		"RAMP_DOWN_S": 10, "RAMP_UP_S": 11, "RAMP_DOWN_W": 12, "RAMP_UP_W": 13,
	}, "ground ids")
	assert_eq(TileKind.TOP, {
		"NULL": 0, "OPEN": 1, "MINABLE_ROCK": 2, "MINABLE_DIRT": 3, "IMPENETRABLE_ROCK": 4,
		"RUBBLE": 5, "CRUSHED": 6,
	}, "top ids (CRUSHED: D-218)")
	assert_eq(TileKind.ORE, {"NULL": 0, "NONE": 1, "COPPER": 2, "TIN": 3, "IRON": 4},
		"ore ids (D-183, D-216)")


func test_no_two_kinds_on_a_layer_share_an_id() -> void:
	for layer: Dictionary in [TileKind.GROUND, TileKind.TOP, TileKind.ORE]:
		var ids: Array = layer.values()
		for id in ids:
			assert_eq(ids.count(id), 1, "id %d is used once in its layer" % id)


func test_object_kind_ids_never_change() -> void:
	assert_eq(ObjectKind.OBJECT, {"NULL": 0, "LADDER": 1, "WORLD_SPAWN": 2, "BRAZIER": 3,
		"TIMBER_PROP": 4, "TREE": 5, "CHUTE": 6, "WINCH": 7, "CRATE": 8, "TORCH": 9},
		"object ids (D-089, D-092, D-144, D-165, D-181, D-219, D-224, D-221)")
