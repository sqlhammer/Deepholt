class_name LevelRenderer
extends MeshInstance2D

# Draws one level's tiles (D-046, D-063): a quad the size of the whole
# level, whose shader reads one texel per tile from a data texture and
# draws that tile's art out of tile_atlas.png. Presentation only --
# nothing in src/world/ may reach back into this.

const TILE_PIXELS: int = 16

# The cells of tile_atlas.png, left to right, 16 x 16 px each.
enum AtlasCell {
	FLOOR,
	MINABLE_ROCK,
	COPPER_IN_ROCK,
	OUTSIDE_LEVEL,
	MISSING,
}


func _ready() -> void:
	material.set_shader_parameter("top_cells", _top_cells())


# Builds the level's top-layer data texture and sizes the quad to the
# level. The texture is derived from the tile data and never read back
# as truth (D-048, D-065).
func show_level(tiles: LevelTiles) -> void:
	var radius: int = tiles.level_bound.radius
	var width: int = 2 * radius + 1
	var top_bytes: PackedByteArray = top_layer_bytes(tiles)
	var top_image: Image = Image.create_from_data(
		width, width, false, Image.FORMAT_R8, top_bytes)
	var top_texture: ImageTexture = ImageTexture.create_from_image(top_image)
	material.set_shader_parameter("top_data", top_texture)

	var level_pixels: int = width * TILE_PIXELS
	(mesh as QuadMesh).size = Vector2(level_pixels, level_pixels)


# The top layer as a read returns it, one byte per tile in the same
# row-major order as the arrays, so texel (column, row) is the tile at
# (column - radius, row - radius). Built through get_top rather than by
# copying the array: the array stores minable rock outside the radial
# bounds, and only a read says 254 there (D-059).
static func top_layer_bytes(tiles: LevelTiles) -> PackedByteArray:
	var radius: int = tiles.level_bound.radius
	var bytes: PackedByteArray = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			bytes.append(tiles.get_top(x, y))
	return bytes


# Which atlas cell draws each top-layer byte, indexed by the byte itself
# (D-064). Every byte without an entry draws MISSING, so a kind that is
# added without art shows up loudly instead of borrowing a neighbour's.
func _top_cells() -> PackedInt32Array:
	var cells: PackedInt32Array = []
	cells.resize(256)
	cells.fill(AtlasCell.MISSING)

	# Open floor stands in for "show the ground" until the ground layer
	# is drawn underneath the top layer (CHECKLIST C, combining layers).
	cells[TileKind.TOP.OPEN] = AtlasCell.FLOOR
	cells[TileKind.TOP.MINABLE_ROCK] = AtlasCell.MINABLE_ROCK
	cells[LevelTiles.SENTINEL_OUT_OF_BOUNDS] = AtlasCell.OUTSIDE_LEVEL
	return cells
