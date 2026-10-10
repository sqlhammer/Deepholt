class_name LevelTiles
extends RefCounted

# A level's tile truth: flat per-layer byte arrays sized to the square around the level's
# radial bounds (D-048), with a third array for ore (D-054). Access goes only through the
# small read/write functions below.

var level_bound: LevelBound
var _ground: PackedByteArray
var ground: PackedByteArray:
	get: return _ground
	set(new_value): _set_ground(new_value)
var _top: PackedByteArray
var top: PackedByteArray:
	get: return _top
	set(new_value): _set_top(new_value)
var _ore: PackedByteArray
var ore: PackedByteArray:
	get: return _ore
	set(new_value): _set_ore(new_value)

enum LAYER {
	NONE,
	GROUND,
	TOP,
	ORE,
}

signal tile_changed(x: int, y: int, layer: LAYER, level_tiles: LevelTiles)


func _init(p_level_bound: LevelBound) -> void:
	level_bound = p_level_bound
	
	# Using the private vars and not using the setters to avoid tens of 
	# thousands of tile change signal emits during initialization.
	_ground = _init_tile_array(ground,TileKind.GROUND.ROCK)
	_top = _init_tile_array(top,TileKind.TOP.MINABLE_ROCK)
	_ore = _init_tile_array(ore,TileKind.ORE.NONE)


func _init_tile_array(tiles: PackedByteArray, tile_kind: int) -> PackedByteArray:
	var max_x = level_bound.radius
	var max_y = level_bound.radius
	var min_x = 0-level_bound.radius
	var min_y = 0-level_bound.radius
	var width: int = 2 * level_bound.radius + 1
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


func is_diggable(p_tile: WorldPos) -> bool:
	var kind = get_top(p_tile.x, p_tile.y)
	return TileKind.is_diggable(kind)


func set_ground(x: int, y: int, kind: int, bypass_signals: bool = false) -> void:
	var _tile: int = _get_tile(ground,x,y)
	if _tile == TileKind.SENTINEL_OUT_OF_ARRAY or _tile == TileKind.SENTINEL_OUT_OF_BOUNDS:
		return
	
	var idx: int = get_index(x,y)
	
	# Only change if there is a real change to make
	if ground[idx] == kind: return
	
	ground[idx] = kind
	if not bypass_signals: tile_changed.emit(x, y, LAYER.GROUND, self)


func set_top(x: int, y: int, kind: int, bypass_signals: bool = false) -> void:
	var _tile: int = _get_tile(top,x,y)
	if _tile == TileKind.SENTINEL_OUT_OF_ARRAY or _tile == TileKind.SENTINEL_OUT_OF_BOUNDS:
		return
	
	var idx: int = get_index(x,y)
	
	# Only change if there is a real change to make
	if top[idx] == kind: return
	
	top[idx] = kind
	if not bypass_signals: tile_changed.emit(x, y, LAYER.TOP, self)


func set_ore(x: int, y: int, kind: int, bypass_signals: bool = false) -> void:
	var _tile: int = _get_tile(ore,x,y)
	if _tile == TileKind.SENTINEL_OUT_OF_ARRAY or _tile == TileKind.SENTINEL_OUT_OF_BOUNDS:
		return
	
	var idx: int = get_index(x,y)
	
	# Only change if there is a real change to make
	if ore[idx] == kind: return
	
	ore[idx] = kind
	if not bypass_signals: tile_changed.emit(x, y, LAYER.ORE, self)


func get_index(x: int, y: int) -> int:
	if level_bound == null: return TileKind.SENTINEL_OUT_OF_ARRAY
	if level_bound.radius == null: return TileKind.SENTINEL_OUT_OF_ARRAY
	
	var r: int = level_bound.radius
	var width: int = (2 * r + 1)
	var idx: int = (y + r) * width + (x + r)
	return idx


func _is_out_of_array(x: int, y: int) -> int:
	if x < (0-level_bound.radius) or x > level_bound.radius:
		return TileKind.SENTINEL_OUT_OF_ARRAY
	if y < (0-level_bound.radius) or y > level_bound.radius:
		return TileKind.SENTINEL_OUT_OF_ARRAY
	return 0


func _is_out_of_bounds(x: int, y: int) -> int:
	var pos: WorldPos = WorldPos.new(x,y,level_bound.depth)
	if not World.is_in_bounds(pos):
		return TileKind.SENTINEL_OUT_OF_BOUNDS
	return 0


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


func _set_ground(new_value: PackedByteArray) -> void:
	push_warning("Use set_ground() to modify individual elements.")
	_ground = new_value


func _set_top(new_value: PackedByteArray) -> void:
	push_warning("Use set_top() to modify individual elements.")
	_top = new_value


func _set_ore(new_value: PackedByteArray) -> void:
	push_warning("Use set_ore() to modify individual elements.")
	_ore = new_value



















