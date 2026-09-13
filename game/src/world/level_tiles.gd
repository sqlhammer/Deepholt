class_name LevelTiles
extends RefCounted

# A level's tile truth: flat per-layer byte arrays sized to the square around the level's
# radial bounds (D-048), with a third array for ore (D-054). Access goes only through the
# small read/write functions below. NOT YET IMPLEMENTED -- see work/CHECKLIST.md section A.
# These bodies exist only so the class parses; they do not do the real work yet.

const SENTINEL_OUT_OF_ARRAY: int = 255
const SENTINEL_OUT_OF_BOUNDS: int = 254

var _level_bound: LevelBound

var ground: PackedByteArray
var top: PackedByteArray
var ore: PackedByteArray


func _init(p_level_bound: LevelBound) -> void:
	_level_bound = p_level_bound
	ground = _init_tile_array(ground,TileKind.GROUND.ROCK)
	top = _init_tile_array(top,TileKind.TOP.OPEN)
	ore = _init_tile_array(ore,TileKind.ORE.NONE)

func _init_tile_array(tiles: PackedByteArray, tile_kind: int) -> PackedByteArray:
	var max_x = _level_bound.radius
	var max_y = _level_bound.radius
	var min_x = 0-_level_bound.radius
	var min_y = 0-_level_bound.radius
	var width: int = 2 * _level_bound.radius + 1
	tiles.resize(width * width)
	
	for x in range(min_x,max_x+1):
		for y in range(min_y, max_y+1):
			tiles[get_index(x,y)] = tile_kind
	
	return tiles


func get_ground(x: int, y: int) -> int:
	return _get_tile(ground,x,y)

func get_ore(x: int, y: int) -> int:
	return _get_tile(ore,x,y)

func get_top(x: int, y: int) -> int:
	return _get_tile(top,x,y)


func _get_tile(tiles: PackedByteArray, x: int, y: int) -> int:
	var idx: int = get_index(x,y)
	var validation_result: int = 0
	
	# Check for out of array
	validation_result = _is_out_of_array(x,y)
	if validation_result != 0:
		return validation_result
	
	# Check for out of bounds
	validation_result = _is_out_of_bounds(x,y)
	if validation_result != 0:
		return validation_result
	
	# Return
	return tiles[idx]


func set_ground(x: int, y: int, kind: int) -> void:
	var _tile: int = _get_tile(ground,x,y)
	if _tile == SENTINEL_OUT_OF_ARRAY or _tile == SENTINEL_OUT_OF_BOUNDS:
		return
	
	var idx: int = get_index(x,y)
	ground[idx] = kind

func set_top(x: int, y: int, kind: int) -> void:
	var _tile: int = _get_tile(top,x,y)
	if _tile == SENTINEL_OUT_OF_ARRAY or _tile == SENTINEL_OUT_OF_BOUNDS:
		return
	
	var idx: int = get_index(x,y)
	top[idx] = kind

func set_ore(x: int, y: int, kind: int) -> void:
	var _tile: int = _get_tile(ore,x,y)
	if _tile == SENTINEL_OUT_OF_ARRAY or _tile == SENTINEL_OUT_OF_BOUNDS:
		return
	
	var idx: int = get_index(x,y)
	ore[idx] = kind


func get_index(x: int, y: int) -> int:
	if _level_bound == null: return SENTINEL_OUT_OF_ARRAY
	if _level_bound.radius == null: return SENTINEL_OUT_OF_ARRAY
	
	var r: int = _level_bound.radius
	var width: int = (2 * r + 1)
	var idx: int = (y + r) * width + (x + r)
	return idx


func _is_out_of_array(x: int, y: int) -> int:
	if x < (0-_level_bound.radius) or x > _level_bound.radius:
		return SENTINEL_OUT_OF_ARRAY
	if y < (0-_level_bound.radius) or y > _level_bound.radius:
		return SENTINEL_OUT_OF_ARRAY
	return 0

func _is_out_of_bounds(x: int, y: int) -> int:
	var pos: WorldPos = WorldPos.new(x,y,_level_bound.depth)
	if not World.is_in_bounds(pos):
		return SENTINEL_OUT_OF_BOUNDS
	return 0







