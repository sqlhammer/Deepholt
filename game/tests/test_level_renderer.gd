extends GutTest

# LevelRenderer's data texture -- the top layer as a read returns it, one
# byte per tile, in the arrays' own row-major order (D-065). Encoding bugs
# render as a plausible level rather than as an error, so they are pinned
# here instead of trusted to the eye.


func _surface_with_start() -> LevelTiles:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[0])
	LevelGridLoader.stamp(tiles, TilePrefabRegistry.get_prefab(&"surface_start"), Vector2i.ZERO)
	return tiles


func test_one_byte_per_tile() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var bytes: PackedByteArray = LevelRenderer.top_layer_bytes(tiles)
	assert_eq(bytes.size(), tiles.top.size(),
		"the texture should hold exactly one byte per tile in the array")


func test_texel_order_matches_array_index() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var bytes: PackedByteArray = LevelRenderer.top_layer_bytes(tiles)
	assert_eq(bytes[tiles.get_index(0, 0)], TileKind.TOP.OPEN,
		"the anchor is open floor, at the same index the arrays use")
	assert_eq(bytes[tiles.get_index(-1, 0)], TileKind.TOP.MINABLE_ROCK,
		"the pocket's left wall is rock")
	assert_eq(bytes[tiles.get_index(6, 1)], TileKind.TOP.OPEN,
		"the pocket's far bottom-right corner is open")


func test_outside_the_disc_is_the_out_of_bounds_sentinel() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var bytes: PackedByteArray = LevelRenderer.top_layer_bytes(tiles)
	var radius: int = tiles.level_bound.radius
	assert_eq(bytes[tiles.get_index(-radius, -radius)], LevelTiles.SENTINEL_OUT_OF_BOUNDS,
		"a corner of the square is outside the disc, so it is 254 -- not the rock the array stores")


func test_every_byte_survives_the_r8_round_trip() -> void:
	var all_values: PackedByteArray = []
	for value in range(256):
		all_values.append(value)
	var image: Image = Image.create_from_data(256, 1, false, Image.FORMAT_R8, all_values)
	for value in range(256):
		var decoded: int = int(image.get_pixel(value, 0).r * 255.0 + 0.5)
		assert_eq(decoded, value, "byte %d should decode to itself" % value)
