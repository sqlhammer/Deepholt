extends GutTest

# TileKind — the ground/top/ore kind ids from D-051, D-052 and D-056, gathered into one table
# so every layer's valid ids can be enumerated and checked against LevelTiles' reserved
# sentinels (D-059).


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


# --- what can be dug, and how hard it is ---

func test_minable_kinds_are_diggable() -> void:
	assert_true(TileKind.is_diggable(TileKind.TOP.MINABLE_ROCK), "rock")
	assert_true(TileKind.is_diggable(TileKind.TOP.MINABLE_DIRT), "dirt")


func test_other_kinds_are_not_diggable() -> void:
	for kind_name: String in ["NULL", "OPEN", "IMPENETRABLE_ROCK"]:
		assert_false(TileKind.is_diggable(TileKind.TOP[kind_name]), kind_name)
	assert_false(TileKind.is_diggable(TileKind.SENTINEL_OUT_OF_BOUNDS), "outside the level")
	assert_false(TileKind.is_diggable(TileKind.SENTINEL_OUT_OF_ARRAY), "past the array")


func test_densities_come_from_the_table() -> void:
	assert_eq(TileKind.get_tile_density(TileKind.TOP.MINABLE_ROCK),
		TileKind.MINABLE_DENSITY["MINABLE_ROCK"].density, "rock's density")
	assert_eq(TileKind.get_tile_density(TileKind.TOP.MINABLE_DIRT),
		TileKind.MINABLE_DENSITY["MINABLE_DIRT"].density, "dirt's density")


func test_an_undiggable_kind_has_no_density() -> void:
	assert_lt(TileKind.get_tile_density(TileKind.TOP.OPEN), 0.0,
		"a negative density means not diggable")


# A density of zero or less would finish a dig on its first tick, or
# be read as "not diggable" by the capability.
func test_every_density_is_positive() -> void:
	for kind_name: String in TileKind.MINABLE_DENSITY:
		assert_gt(TileKind.MINABLE_DENSITY[kind_name].density, 0.0,
			"%s takes some time to dig" % kind_name)


func test_every_density_entry_is_a_top_kind() -> void:
	for kind_name: String in TileKind.MINABLE_DENSITY:
		var id: int = TileKind.MINABLE_DENSITY[kind_name].id
		assert_true(id in TileKind.TOP.values(), "%s names a real top kind" % kind_name)
		assert_eq(TileKind.TOP.get(kind_name, -1), id,
			"and the entry's name matches that kind's name")


# --- hardness (D-081) ---

# Hardness belongs to the tile kind. Surface stone matches the tuning
# appendix's Surface value; dirt is a bit easier.
func test_rock_and_dirt_hardness() -> void:
	assert_eq(TileKind.get_tile_density(TileKind.TOP.MINABLE_ROCK), 6.0, "rock is 6")
	assert_eq(TileKind.get_tile_density(TileKind.TOP.MINABLE_DIRT), 4.0, "dirt is 4")
	assert_lt(TileKind.get_tile_density(TileKind.TOP.MINABLE_DIRT),
		TileKind.get_tile_density(TileKind.TOP.MINABLE_ROCK), "dirt is easier than rock")


func test_ore_makes_a_tile_one_and_a_half_times_as_hard() -> void:
	assert_eq(TileKind.get_dig_density(TileKind.TOP.MINABLE_ROCK, TileKind.ORE.NONE), 6.0,
		"plain rock")
	assert_eq(TileKind.get_dig_density(TileKind.TOP.MINABLE_ROCK, TileKind.ORE.COPPER), 9.0,
		"rock with copper takes 1.5x")


func test_ore_does_not_make_an_undiggable_tile_diggable() -> void:
	assert_lt(TileKind.get_dig_density(TileKind.TOP.OPEN, TileKind.ORE.COPPER), 0.0,
		"open floor stays undiggable whatever the ore says")
