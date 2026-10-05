extends Node
class_name TileSpace

const TILE_PIXELS: int = 16

# Where a tile sits in a level's own pixel space: tile (x, y) covers
# x * 16 to x * 16 + 16 across and the same down, so world (0, 0)'s
# top-left corner is the level's origin (D-067). This is its center.
static func tile_center(tile: Vector2i) -> Vector2:
	var half_tile: float = TileSpace.TILE_PIXELS / 2.0
	var corner: Vector2 = Vector2(tile * TileSpace.TILE_PIXELS)
	return corner + Vector2(half_tile, half_tile)
