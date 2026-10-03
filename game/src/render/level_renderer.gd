class_name LevelRenderer
extends MeshInstance2D

# Draws one level's tiles (D-046, D-063): a quad the size of the whole
# level, whose shader reads one texel per tile per layer from data
# textures and draws each layer's art out of tile_atlas.png, ground
# first, then top, then ore (D-066). Presentation only -- nothing in
# src/world/ may reach back into this.

const TILE_PIXELS: int = 16

# The cells of tile_atlas.png, left to right, 16 x 16 px each.
enum AtlasCell {
	FLOOR,
	MINABLE_ROCK,
	COPPER,
	OUTSIDE_LEVEL,
	MISSING,
	EMPTY,
}


func _ready() -> void:
	material.set_shader_parameter("ground_cells", _ground_cells())
	material.set_shader_parameter("top_cells", _top_cells())
	material.set_shader_parameter("ore_cells", _ore_cells())


# Builds the level's data textures, one per layer, and sizes the quad to
# the level. The textures are derived from the tile data and never read
# back as truth (D-048, D-065).
func show_level(tiles: LevelTiles) -> void:
	var layers: Dictionary = layer_bytes(tiles)
	for layer: String in layers:
		var layer_texture: ImageTexture = _data_texture(tiles, layers[layer])
		material.set_shader_parameter(layer + "_data", layer_texture)

	var level_pixels: int = level_width(tiles) * TILE_PIXELS
	(mesh as QuadMesh).size = Vector2(level_pixels, level_pixels)


# A level's tiles are a square this many tiles on a side.
static func level_width(tiles: LevelTiles) -> int:
	return 2 * tiles.level_bound.radius + 1


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


func _data_texture(tiles: LevelTiles, bytes: PackedByteArray) -> ImageTexture:
	var width: int = level_width(tiles)
	var image: Image = Image.create_from_data(
		width, width, false, Image.FORMAT_R8, bytes)
	return ImageTexture.create_from_image(image)


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
	cells[LevelTiles.SENTINEL_OUT_OF_BOUNDS] = AtlasCell.OUTSIDE_LEVEL
	return cells


func _top_cells() -> PackedInt32Array:
	var cells: PackedInt32Array = _cell_table()
	cells[TileKind.TOP.OPEN] = AtlasCell.EMPTY
	cells[TileKind.TOP.MINABLE_ROCK] = AtlasCell.MINABLE_ROCK
	cells[LevelTiles.SENTINEL_OUT_OF_BOUNDS] = AtlasCell.EMPTY
	return cells


# Ore draws over whatever the top layer drew. The tile data, not this
# table, keeps ore out of open floor (D-056).
func _ore_cells() -> PackedInt32Array:
	var cells: PackedInt32Array = _cell_table()
	cells[TileKind.ORE.NONE] = AtlasCell.EMPTY
	cells[TileKind.ORE.COPPER] = AtlasCell.COPPER
	cells[LevelTiles.SENTINEL_OUT_OF_BOUNDS] = AtlasCell.EMPTY
	return cells
