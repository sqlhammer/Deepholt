extends GutTest

# TileKind — the ground/top/ore kind ids from D-051, D-052 and D-056, gathered into one table
# so every layer's valid ids can be enumerated and checked against LevelTiles' reserved
# sentinels (D-059).


func test_ground_kind_ids_avoid_sentinels() -> void:
	for id in TileKind.GROUND.values():
		assert_ne(id, LevelTiles.SENTINEL_OUT_OF_ARRAY,
			"ground kind %d collides with the out-of-array sentinel" % id)
		assert_ne(id, LevelTiles.SENTINEL_OUT_OF_BOUNDS,
			"ground kind %d collides with the out-of-bounds sentinel" % id)


func test_top_kind_ids_avoid_sentinels() -> void:
	for id in TileKind.TOP.values():
		assert_ne(id, LevelTiles.SENTINEL_OUT_OF_ARRAY,
			"top kind %d collides with the out-of-array sentinel" % id)
		assert_ne(id, LevelTiles.SENTINEL_OUT_OF_BOUNDS,
			"top kind %d collides with the out-of-bounds sentinel" % id)


func test_ore_kind_ids_avoid_sentinels() -> void:
	for id in TileKind.ORE.values():
		assert_ne(id, LevelTiles.SENTINEL_OUT_OF_ARRAY,
			"ore kind %d collides with the out-of-array sentinel" % id)
		assert_ne(id, LevelTiles.SENTINEL_OUT_OF_BOUNDS,
			"ore kind %d collides with the out-of-bounds sentinel" % id)


func test_slice_001_kinds_are_present() -> void:
	assert_true(TileKind.GROUND.has("ROCK"), "rock is the only ground kind (D-056)")
	assert_true(TileKind.TOP.has("OPEN"), "open is a top kind (D-051, D-052)")
	assert_true(TileKind.TOP.has("MINABLE_ROCK"), "minable rock is a top kind (D-051, D-052)")
	assert_true(TileKind.ORE.has("NONE"), "no-ore is a value on the ore layer (D-052)")
	assert_true(TileKind.ORE.has("COPPER"), "copper is the ore in this slice (D-051)")
