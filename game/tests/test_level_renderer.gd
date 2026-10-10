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
		assert_eq(layers[layer][corner], TileKind.SENTINEL_OUT_OF_BOUNDS,
			"a corner of the square is outside the disc, so %s is 254 -- not the default the array stores" % layer)


func test_every_byte_survives_the_r8_round_trip() -> void:
	var all_values: PackedByteArray = []
	for value in range(256):
		all_values.append(value)
	var image: Image = Image.create_from_data(256, 1, false, Image.FORMAT_R8, all_values)
	for value in range(256):
		var decoded: int = int(image.get_pixel(value, 0).r * 255.0 + 0.5)
		assert_eq(decoded, value, "byte %d should decode to itself" % value)


# --- keeping the screen in step with the tile data (D-065) ---

# A renderer as game.tscn builds one: a quad, and the level shader.
func _renderer() -> LevelRenderer:
	var renderer: LevelRenderer = LevelRenderer.new()
	renderer.mesh = QuadMesh.new()
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = load("res://src/render/level_tiles.gdshader")
	renderer.material = shader_material
	add_child_autofree(renderer)
	return renderer


# The byte the renderer's image holds for tile (x, y) on a layer.
func _texel(renderer: LevelRenderer, tiles: LevelTiles, layer: String, x: int, y: int) -> int:
	var radius: int = tiles.level_bound.radius
	var image: Image = renderer._layer_data_images[layer]
	return image.get_data()[(y + radius) * image.get_width() + (x + radius)]


func test_a_changed_tile_is_rewritten_in_its_layer() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var renderer: LevelRenderer = _renderer()
	renderer.show_level(tiles)
	tiles.set_top(-1, 0, TileKind.TOP.OPEN)
	assert_eq(_texel(renderer, tiles, "top", -1, 0), TileKind.TOP.OPEN,
		"the rock beside the anchor now reads open in the top image")


func test_only_the_changed_layer_is_touched() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var renderer: LevelRenderer = _renderer()
	renderer.show_level(tiles)
	var ground_before: int = _texel(renderer, tiles, "ground", -1, 0)
	tiles.set_top(-1, 0, TileKind.TOP.OPEN)
	assert_eq(_texel(renderer, tiles, "ground", -1, 0), ground_before,
		"the ground image is unchanged")
	assert_eq(renderer._dirty_layers.keys(), ["top"], "and only the top layer needs an upload")


# An upload re-sends the whole layer, so a frame's changes are
# gathered and each changed layer goes up once.
func test_changes_in_a_frame_are_gathered_into_one_upload() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var renderer: LevelRenderer = _renderer()
	renderer.show_level(tiles)
	tiles.set_top(-1, 0, TileKind.TOP.OPEN)
	tiles.set_top(-1, 1, TileKind.TOP.OPEN)
	tiles.set_top(-1, -1, TileKind.TOP.OPEN)
	assert_eq(renderer._dirty_layers.size(), 1, "three top changes, one dirty layer")
	renderer.upload_changed_layers()
	assert_eq(renderer._dirty_layers.size(), 0, "uploaded, nothing left waiting")


func test_nothing_waits_for_upload_after_showing_a_level() -> void:
	var renderer: LevelRenderer = _renderer()
	renderer.show_level(_surface_with_start())
	assert_eq(renderer._dirty_layers.size(), 0, "a fresh level is uploaded whole")


# The trap: without disconnecting, a change on the level shown before
# would be drawn onto the new one, at the same coordinates.
func test_changes_on_a_level_no_longer_shown_are_ignored() -> void:
	var old_level: LevelTiles = _surface_with_start()
	var new_level: LevelTiles = _surface_with_start()
	var renderer: LevelRenderer = _renderer()
	renderer.show_level(old_level)
	renderer.show_level(new_level)
	old_level.set_top(-1, 0, TileKind.TOP.OPEN)
	assert_eq(_texel(renderer, new_level, "top", -1, 0), TileKind.TOP.MINABLE_ROCK,
		"the new level still shows its own rock")
	assert_eq(renderer._dirty_layers.size(), 0, "and nothing is queued for upload")


func test_showing_the_same_level_again_is_harmless() -> void:
	var tiles: LevelTiles = _surface_with_start()
	var renderer: LevelRenderer = _renderer()
	renderer.show_level(tiles)
	renderer.show_level(tiles)
	tiles.set_top(-1, 0, TileKind.TOP.OPEN)
	assert_eq(_texel(renderer, tiles, "top", -1, 0), TileKind.TOP.OPEN,
		"still listening, and connected once (a second connect would be an error)")


# set_pixel turns a float back into a byte; every kind id must come
# back as itself, or a kind would be drawn as its neighbor.
func test_every_byte_survives_being_written_as_a_pixel() -> void:
	var image: Image = Image.create_empty(256, 1, false, Image.FORMAT_R8)
	for value in range(256):
		image.set_pixel(value, 0, Color(value / 255.0, 0.0, 0.0))
	var data: PackedByteArray = image.get_data()
	for value in range(256):
		assert_eq(data[value], value, "byte %d is written as itself" % value)


# Outcome 3, the screen half: a dig through World reaches the images
# with no code in World or the dig knowing a renderer exists.
func test_a_dig_reaches_the_screen() -> void:
	var level: Level = Global.level_packed_scene.instantiate()
	level.setup(0, TilePrefabRegistry.get_prefab(&"surface_start"))
	add_child_autofree(level)
	level.level_tiles.set_ore(-1, 0, TileKind.ORE.COPPER)
	var renderer: LevelRenderer = _renderer()
	renderer.show_level(level.level_tiles)
	World.dig_requested.emit(autofree(Actor.new()), WorldPos.new(-1, 0, 0))
	assert_eq(_texel(renderer, level.level_tiles, "top", -1, 0), TileKind.TOP.OPEN,
		"the dug tile is open on screen")
	assert_eq(_texel(renderer, level.level_tiles, "ore", -1, 0), TileKind.ORE.NONE,
		"and its copper is gone from screen")
