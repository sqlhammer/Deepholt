class_name LevelRenderer
extends MeshInstance2D

# Draws one level's tiles (D-046, D-063): a quad the size of the whole
# level, whose shader reads one texel per tile per layer from data
# textures and draws each layer's art out of tile_atlas.png, ground
# first, then top, then ore (D-066). Presentation only -- nothing in
# src/world/ may reach back into this.

# The cells of tile_atlas.png, left to right, 16 x 16 px each.
enum AtlasCell {
	FLOOR,
	MINABLE_ROCK,
	COPPER,
	OUTSIDE_LEVEL,
	MISSING,
	EMPTY,
}


# The data the shader reads, kept so single tiles can be rewritten
# after the level is shown (D-065). Keyed by layer name: "ground",
# "top", "ore".
var _layer_data_imagetextures: Dictionary[String, ImageTexture] = {}
var _layer_data_images: Dictionary[String, Image] = {}

# The level being shown, and the layers changed since the last
# upload. Changes within a frame are gathered into one upload per
# layer, because an upload re-sends the whole layer (D-065).
var _tiles: LevelTiles
var _dirty_layers: Dictionary[String, bool] = {}

const LAYER_NAMES: Dictionary = {
	LevelTiles.LAYER.GROUND: "ground",
	LevelTiles.LAYER.TOP: "top",
	LevelTiles.LAYER.ORE: "ore",
}

func _ready() -> void:
	material.set_shader_parameter("ground_cells", _ground_cells())
	material.set_shader_parameter("top_cells", _top_cells())
	material.set_shader_parameter("ore_cells", _ore_cells())


# Sends each layer changed this frame to the GPU, once.
func _process(_delta: float) -> void:
	upload_changed_layers()


# Builds the level's data textures, one per layer, and sizes the quad to
# the level. The textures are derived from the tile data and never read
# back as truth (D-048, D-065).
func show_level(tiles: LevelTiles) -> void:
	_listen_to(tiles)
	_tiles = tiles
	_dirty_layers.clear()
	
	var layers: Dictionary = layer_bytes(tiles)
	for layer: String in layers:
		var layer_texture: ImageTexture = _get_and_store_data(layer, tiles, layers[layer])
		material.set_shader_parameter(layer + "_data", layer_texture)

	# A QuadMesh is centered on its node, and an odd-width level's center
	# is the middle of tile (0, 0). Shifting by half a tile puts that
	# tile's top-left corner on the node's origin instead (D-067).
	var quad: QuadMesh = mesh as QuadMesh
	var level_pixels: int = level_width(tiles) * TileSpace.TILE_PIXELS
	var half_tile: float = TileSpace.TILE_PIXELS / 2.0
	quad.size = Vector2(level_pixels, level_pixels)
	quad.center_offset = Vector3(half_tile, half_tile, 0.0)


# A level's tiles are a square this many tiles on a side.
static func level_width(tiles: LevelTiles) -> int:
	return 2 * tiles.level_bound.radius + 1


# Uploads every layer changed since the last upload, then forgets
# them. Called once a frame; public so tests can drive it.
func upload_changed_layers() -> void:
	for layer_name: String in _dirty_layers:
		_layer_data_imagetextures[layer_name].update(_layer_data_images[layer_name])
	_dirty_layers.clear()


# Every layer as a read returns it, one byte per tile in the same
# row-major order as the arrays, so texel (column, row) is the tile at
# (column - radius, row - radius). Built through the reads rather than by
# copying the arrays: the arrays store the default kind outside the
# radial bounds, and only a read says 254 there (D-059, D-065).
static func layer_bytes(tiles: LevelTiles) -> Dictionary:
	var radius: int = tiles.level_bound.radius
	var ground: PackedByteArray = []
	var top: PackedByteArray = []
	var ore: PackedByteArray = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			ground.append(tiles.get_ground(x, y))
			top.append(tiles.get_top(x, y))
			ore.append(tiles.get_ore(x, y))
	return {"ground": ground, "top": top, "ore": ore}


func _get_and_store_data(layer: String, tiles: LevelTiles, bytes: PackedByteArray) -> ImageTexture:
	var image: Image = _data_image(tiles, bytes)
	var layer_texture: ImageTexture = _data_texture(image)
	
	# Store for later
	_layer_data_images[layer] = image
	_layer_data_imagetextures[layer] = layer_texture
	
	return layer_texture


func _data_texture(image: Image) -> ImageTexture:
	var layer_texture: ImageTexture = ImageTexture.create_from_image(image)
	return layer_texture


func _data_image(tiles: LevelTiles, bytes: PackedByteArray) -> Image:
	var width: int = level_width(tiles)
	var image: Image = Image.create_from_data(
		width, width, false, Image.FORMAT_R8, bytes)
	return image


# Which atlas cell draws each byte of a layer, indexed by the byte itself
# (D-064). Every byte without an entry draws MISSING, so a kind that is
# added without art shows up loudly instead of borrowing a neighbour's.
func _cell_table() -> PackedInt32Array:
	var cells: PackedInt32Array = []
	cells.resize(256)
	cells.fill(AtlasCell.MISSING)
	return cells


# Only the ground draws the outside of the level; the layers above draw
# nothing there, so it shows through.
func _ground_cells() -> PackedInt32Array:
	var cells: PackedInt32Array = _cell_table()
	cells[TileKind.GROUND.ROCK] = AtlasCell.FLOOR
	cells[TileKind.SENTINEL_OUT_OF_BOUNDS] = AtlasCell.OUTSIDE_LEVEL
	return cells


func _top_cells() -> PackedInt32Array:
	var cells: PackedInt32Array = _cell_table()
	cells[TileKind.TOP.OPEN] = AtlasCell.EMPTY
	cells[TileKind.TOP.MINABLE_ROCK] = AtlasCell.MINABLE_ROCK
	cells[TileKind.SENTINEL_OUT_OF_BOUNDS] = AtlasCell.EMPTY
	return cells


# Ore draws over whatever the top layer drew. The tile data, not this
# table, keeps ore out of open floor (D-056).
func _ore_cells() -> PackedInt32Array:
	var cells: PackedInt32Array = _cell_table()
	cells[TileKind.ORE.NONE] = AtlasCell.EMPTY
	cells[TileKind.ORE.COPPER] = AtlasCell.COPPER
	cells[TileKind.SENTINEL_OUT_OF_BOUNDS] = AtlasCell.EMPTY
	return cells


# Listens to the tile data of the level being shown, and stops
# listening to the one shown before. Without the disconnect, a change
# on the old level would be drawn onto the new one, at the same
# coordinates.
func _listen_to(new_tiles: LevelTiles) -> void:
	if _tiles == new_tiles: return
	
	if _tiles != null and _tiles.tile_changed.is_connected(_on_tile_changed):
		_tiles.tile_changed.disconnect(_on_tile_changed)
	
	new_tiles.tile_changed.connect(_on_tile_changed)


# One tile of one layer changed in the data: rewrite its texel. The
# value written is what a read returns, the same rule the textures
# are built by (D-065). The upload waits for the end of the frame.
func _on_tile_changed(x: int, y: int, layer: LevelTiles.LAYER,
		source: LevelTiles) -> void:
	# Only the level on screen; the disconnect in _listen_to should
	# already guarantee it, this keeps it true if that ever slips.
	if source != _tiles: return
	var layer_name: String = LAYER_NAMES.get(layer, "")
	if not _layer_data_images.has(layer_name): return
	
	var kind: int = _read(layer, x, y)
	var radius: int = _tiles.level_bound.radius
	var texel: Vector2i = Vector2i(x + radius, y + radius)
	_layer_data_images[layer_name].set_pixelv(texel, Color(kind / 255.0, 0.0, 0.0))
	_dirty_layers[layer_name] = true


func _read(layer: LevelTiles.LAYER, x: int, y: int) -> int:
	match layer:
		LevelTiles.LAYER.GROUND: return _tiles.get_ground(x, y)
		LevelTiles.LAYER.TOP: return _tiles.get_top(x, y)
		LevelTiles.LAYER.ORE: return _tiles.get_ore(x, y)
	return TileKind.SENTINEL_OUT_OF_ARRAY























