extends GutTest

# LevelRenderer's data textures -- each layer as a read returns it, one
# byte per tile, in the arrays' own row-major order (D-065). Encoding bugs
# render as a plausible level rather than as an error, so they are pinned
# here instead of trusted to the eye.


func _surface_with_start() -> LevelTiles:
	var tiles: LevelTiles = LevelTiles.new(World.level_bounds.rows[0])
	LevelGridLoader.stamp(tiles, TilePrefabRegistry.get_prefab(&"surface_start"), Vector2i.ZERO)
	return tiles


func test_one_byte_per_tile_on_every_layer() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var layers: Dictionary = LevelRenderer.layer_bytes(tiles)
	for layer: String in ["ground", "top", "ore"]:
		assert_eq(layers[layer].size(), tiles.top.size(),
			"the %s texture should hold exactly one byte per tile" % layer)


func test_texel_order_matches_array_index() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var bytes: PackedByteArray = LevelRenderer.layer_bytes(tiles)["top"]
	assert_eq(bytes[tiles.get_index(0, 0)], TileKind.TOP.OPEN,
		"the anchor is open floor, at the same index the arrays use")
	assert_eq(bytes[tiles.get_index(-1, 0)], TileKind.TOP.MINABLE_ROCK,
		"the pocket's left wall is rock")
	assert_eq(bytes[tiles.get_index(6, 1)], TileKind.TOP.OPEN,
		"the pocket's far bottom-right corner is open")


func test_ore_lands_in_the_same_tile_as_its_rock() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var layers: Dictionary = LevelRenderer.layer_bytes(tiles)
	var index: int = tiles.get_index(-1, 0)
	assert_eq(layers["ore"][index], TileKind.ORE.COPPER,
		"the prefab puts copper in the pocket's left wall")
	assert_eq(layers["top"][index], TileKind.TOP.MINABLE_ROCK,
		"and that tile's top is the rock the copper sits in")


func test_outside_the_disc_is_the_out_of_bounds_sentinel_on_every_layer() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var layers: Dictionary = LevelRenderer.layer_bytes(tiles)
	var radius: int = tiles.level_bound.radius
	var corner: int = tiles.get_index(-radius, -radius)
	for layer: String in ["ground", "top", "ore"]:
		assert_eq(layers[layer][corner], LevelTiles.SENTINEL_OUT_OF_BOUNDS,
			"a corner of the square is outside the disc, so %s is 254 -- not the default the array stores" % layer)


func test_every_byte_survives_the_r8_round_trip() -> void:
	var all_values: PackedByteArray = []
	for value in range(256):
		all_values.append(value)
	var image: Image = Image.create_from_data(256, 1, false, Image.FORMAT_R8, all_values)
	for value in range(256):
		var decoded: int = int(image.get_pixel(value, 0).r * 255.0 + 0.5)
		assert_eq(decoded, value, "byte %d should decode to itself" % value)
