class_name LevelRenderer
extends MeshInstance2D

# Draws a level's tiles (D-046): a quad whose shader works out which
# tile each pixel is in and draws that tile's art out of tile_atlas.png.
# Presentation only -- nothing in src/world/ may reach back into this.

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
