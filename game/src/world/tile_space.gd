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


static func get_tile_coordinate_from_pixels(pos_coord: float) -> int:
	return floori(pos_coord / TILE_PIXELS)


static func get_tile_coordinates_from_pixels(p_pos: Vector2) -> Vector2i:
	var pos: Vector2i = Vector2i.ZERO
	pos.x = floori(p_pos.x / TILE_PIXELS)
	pos.y = floori(p_pos.y / TILE_PIXELS)
	return pos


static func get_facing_offset(dir: Vector2) -> Vector2i:
	if absf(dir.x) >= absf(dir.y):
		return Vector2i(signi(int(signf(dir.x))), 0)
	return Vector2i(0, int(signf(dir.y)))




