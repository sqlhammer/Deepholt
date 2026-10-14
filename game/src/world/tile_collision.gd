extends Node
class_name TileCollision

static func move_box(tiles: LevelTiles, box: Rect2, motion: Vector2) -> Rect2:
	var result: Rect2 = box
	
	var along_x: Rect2 = result
	along_x.position.x += motion.x
	if not _overlaps_solid(tiles, along_x) and not _crosses_closed_edge(tiles, result, along_x):
		result = along_x
	else:
		result.position.x = _flush_x(along_x, motion.x)
	
	var along_y: Rect2 = result
	along_y.position.y += motion.y
	if not _overlaps_solid(tiles, along_y) and not _crosses_closed_edge(tiles, result, along_y):
		result = along_y
	else:
		result.position.y = _flush_y(along_y, motion.y)
	
	return result


# Whether a box can stand where it is: every tile under it passable.
# The same test movement uses, for placing an actor rather than
# sliding one.
static func fits(tiles: LevelTiles, box: Rect2) -> bool:
	return not _overlaps_solid(tiles, box)


static func _overlaps_solid(tiles: LevelTiles, box: Rect2) -> bool:
	var first: Vector2i = TileSpace.get_tile_coordinates_from_pixels(box.position)
	# The far edges are exclusive: a box whose right edge sits exactly
	# on a tile boundary touches that tile but doesn't overlap it.
	var last: Vector2i = TileSpace.get_tile_coordinates_from_pixels(
		box.end - Vector2(Global.epsilon, Global.epsilon))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var top_kind: int = tiles.get_top(x, y)
			var ground_kind: int = tiles.get_ground(x, y)
			if TileKind.is_passable(top_kind, ground_kind):
				return true
	return false


# Whether moving from `before` to `after` (along one axis) carries the
# box's leading edge across a tile edge that can't be crossed: a ramp's
# closed side (D-099). Tiles the box only touches don't count, the
# same as solid tiles.
static func _crosses_closed_edge(tiles: LevelTiles, before: Rect2, after: Rect2) -> bool:
	var eps: Vector2 = Vector2(Global.epsilon, Global.epsilon)
	var old_first: Vector2i = TileSpace.get_tile_coordinates_from_pixels(before.position)
	var old_last: Vector2i = TileSpace.get_tile_coordinates_from_pixels(before.end - eps)
	var new_first: Vector2i = TileSpace.get_tile_coordinates_from_pixels(after.position)
	var new_last: Vector2i = TileSpace.get_tile_coordinates_from_pixels(after.end - eps)

	var steps: Array[Vector2i] = []  # [from, to] pairs of tiles
	for c in range(old_last.x, new_last.x):
		for y in range(new_first.y, new_last.y + 1):
			steps.append_array([Vector2i(c, y), Vector2i(c + 1, y)])
	for c in range(old_first.x, new_first.x, -1):
		for y in range(new_first.y, new_last.y + 1):
			steps.append_array([Vector2i(c, y), Vector2i(c - 1, y)])
	for r in range(old_last.y, new_last.y):
		for x in range(new_first.x, new_last.x + 1):
			steps.append_array([Vector2i(x, r), Vector2i(x, r + 1)])
	for r in range(old_first.y, new_first.y, -1):
		for x in range(new_first.x, new_last.x + 1):
			steps.append_array([Vector2i(x, r), Vector2i(x, r - 1)])

	for i in range(0, steps.size(), 2):
		if not edge_open(tiles, steps[i], steps[i + 1]):
			return true
	return false


# Whether an actor may step from one tile to its neighbor: not if
# either is a ramp whose side facing the other is closed (D-099).
static func edge_open(tiles: LevelTiles, from: Vector2i, to: Vector2i) -> bool:
	var step: Vector2i = to - from
	var from_ground: int = tiles.get_ground(from.x, from.y)
	if TileKind.is_ramp(from_ground) and step != TileKind.ramp_open_side(from_ground):
		return false
	var to_ground: int = tiles.get_ground(to.x, to.y)
	if TileKind.is_ramp(to_ground) and -step != TileKind.ramp_open_side(to_ground):
		return false
	return true


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









