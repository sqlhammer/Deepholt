class_name LevelTiles
extends RefCounted

# A level's tile truth: flat per-layer byte arrays sized to the square
# around the level's radial bounds (D-048), with a third array for ore
# (D-054). Access goes only through the small read/write functions
# below.

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
# What the world's players have sensed here (D-145): bit flags per
# tile (D-147). Bit 0 is REMEMBERED; the other seven are reserved.
# Perception, not terrain: nothing that decides what a tile is reads
# it. Saved, never generated.
var _memory: PackedByteArray
var memory: PackedByteArray:
	get: return _memory
	set(new_value): _set_memory(new_value)

const REMEMBERED: int = 1

enum LAYER {
	NONE,
	GROUND,
	TOP,
	ORE,
	MEMORY,
}
enum REFUSAL_REASON {
	NONE,
	LAYER_SIZE_MISMATCH
}

signal tile_changed(x: int, y: int, layer: LAYER, level_tiles: LevelTiles)
signal tiles_replaced(level_tiles: LevelTiles)
# Some tiles became remembered: once per batch, not per tile, since a
# step can mark a hundred (D-145).
signal memory_changed(level_tiles: LevelTiles)

func _init(p_level_bound: LevelBound) -> void:
	level_bound = p_level_bound
	
	# Using the private vars and not using the setters to avoid tens of 
	# thousands of tile change signal emits during initialization.
	_ground = _init_tile_array(ground,TileKind.GROUND.ROCK)
	_top = _init_tile_array(top,TileKind.TOP.MINABLE_ROCK)
	_ore = _init_tile_array(ore,TileKind.ORE.NONE)
	_memory = _init_tile_array(memory, 0)


func bulk_load_tile_arrays(layers: Dictionary) -> REFUSAL_REASON:
	var level_size: int = _get_level_bound_array_size(level_bound)
	if (layers.has("ground") and layers["ground"].size() != level_size):
		return REFUSAL_REASON.LAYER_SIZE_MISMATCH
	if (layers.has("top") and layers["top"].size() != level_size):
		return REFUSAL_REASON.LAYER_SIZE_MISMATCH
	if (layers.has("ore") and layers["ore"].size() != level_size):
		return REFUSAL_REASON.LAYER_SIZE_MISMATCH
	if (layers.has("memory") and layers["memory"].size() != level_size):
		return REFUSAL_REASON.LAYER_SIZE_MISMATCH
	
	# Using the private vars and not using the setters to avoid tens of 
	# thousands of tile change signal emits during initialization.
	if layers.has("ground"): _ground = layers["ground"].duplicate()
	if layers.has("top"): _top = layers["top"].duplicate()
	if layers.has("ore"): _ore = layers["ore"].duplicate()
	if layers.has("memory"): _memory = layers["memory"].duplicate()
	
	tiles_replaced.emit(self)
	
	return REFUSAL_REASON.NONE


# Every tile of the square gets the kind. fill, not a loop over x and
# y: the loop set the same bytes one at a time in GDScript, and made
# up most of a load's time (375 ms for all eight levels).
func _init_tile_array(tiles: PackedByteArray, tile_kind: int) -> PackedByteArray:
	tiles.resize(_get_level_bound_array_size(level_bound))
	tiles.fill(tile_kind)
	return tiles


func _get_level_bound_array_size(p_level_bound: LevelBound) -> int:
	return array_size(p_level_bound.radius)


# How many tiles a layer holds for a level of this radius: the square
# around its disc. The one place this is worked out, so a load and the
# tiles it fills can't disagree.
static func array_size(radius: int) -> int:
	var width: int = 2 * radius + 1
	return width * width


func get_ground(x: int, y: int) -> int:
	return _get_tile(ground,x,y)


func get_ore(x: int, y: int) -> int:
	return _get_tile(ore,x,y)


func get_top(x: int, y: int) -> int:
	return _get_tile(top,x,y)


# The memory byte, or a sentinel outside the level (D-059).
func get_memory(x: int, y: int) -> int:
	return _get_tile(memory,x,y)


func is_remembered(x: int, y: int) -> bool:
	var flags: int = get_memory(x, y)
	if TileKind.is_sentinel(flags): return false
	return (flags & REMEMBERED) != 0


# Marks each tile remembered, skipping any outside the level, and
# announces the batch once if anything changed. Returns how many
# tiles were newly remembered.
func remember(tiles: Array[Vector2i]) -> int:
	var count: int = 0
	for tile: Vector2i in tiles:
		var flags: int = get_memory(tile.x, tile.y)
		if TileKind.is_sentinel(flags) or (flags & REMEMBERED) != 0: continue
		_memory[get_index(tile.x, tile.y)] = flags | REMEMBERED
		count += 1
	if count > 0: memory_changed.emit(self)
	return count


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


# The radial bounds of this level's own shape: distance from the axis
# <= radius, compared squared so a read allocates nothing and asks
# nothing outside (the same disc World.is_in_bounds draws). Every tile
# read passes through here, so building a level's textures calls it
# about 100,000 times at the Surface.
func _is_out_of_bounds(x: int, y: int) -> int:
	var radius: int = level_bound.radius
	if x * x + y * y > radius * radius:
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


func _set_memory(new_value: PackedByteArray) -> void:
	push_warning("Use remember() to modify individual elements.")
	_memory = new_value



















