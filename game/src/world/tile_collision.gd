extends Node
class_name TileCollision

static func move_box(tiles: LevelTiles, box: Rect2, motion: Vector2) -> Rect2:
	var result: Rect2 = box
	
	var along_x: Rect2 = result
	along_x.position.x += motion.x
	if not _overlaps_solid(tiles, along_x):
		result = along_x
	else:
		result.position.x = _flush_x(along_x, motion.x)
	
	var along_y: Rect2 = result
	along_y.position.y += motion.y
	if not _overlaps_solid(tiles, along_y):
		result = along_y
	else:
		result.position.y = _flush_y(along_y, motion.y)
	
	return result


static func _overlaps_solid(tiles: LevelTiles, box: Rect2) -> bool:
	var first: Vector2i = TileSpace.get_tile_coordinates_from_pixels(box.position)
	# The far edges are exclusive: a box whose right edge sits exactly
	# on a tile boundary touches that tile but doesn't overlap it.
	var last: Vector2i = TileSpace.get_tile_coordinates_from_pixels(
		box.end - Vector2(Global.epsilon, Global.epsilon))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if tiles.get_top(x, y) != TileKind.TOP.OPEN:
				return true
	return false


static func _flush_x(box: Rect2, motion: float) -> float:
	var result: float
	var column: int
	
	if motion > 0:
		column = TileSpace.get_tile_coordinate_from_pixels(box.end.x - Global.epsilon)
		result = column * 16 - box.size.x
	if motion < 0:
		column = TileSpace.get_tile_coordinate_from_pixels(box.position.x)
		result = (column + 1) * 16
	
	return result


static func _flush_y(box: Rect2, motion: float) -> float:
	var result: float
	var row: int
	
	if motion > 0:
		row = TileSpace.get_tile_coordinate_from_pixels(box.end.y - Global.epsilon)
		result = row * 16 - box.size.y
	if motion < 0:
		row = TileSpace.get_tile_coordinate_from_pixels(box.position.y)
		result = (row + 1) * 16
	
	return result









