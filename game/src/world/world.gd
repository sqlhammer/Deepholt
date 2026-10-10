extends Node

var world_seed: int
var level_bounds: Resource = preload("res://src/world/level_bounds.tres")

signal tile_dug(actor: Actor, tile: WorldPos)
signal dig_requested(actor: Actor, tile: WorldPos)
signal dig_refused(actor: Actor, tile: WorldPos, reason: REFUSAL_REASON)

enum REFUSAL_REASON {
	NONE,
	LEVEL_NOT_EXISTS,
	TILE_NOT_EXISTS,
	TILE_NOT_DIGGABLE,
	LEVEL_NOT_EXIST,
}

func _ready() -> void:
	set_world_seed("Default Seed")
	dig_requested.connect(_on_dig_requested)


func get_level_tiles_from_depth(p_depth: int) -> LevelTiles:
	var level: Level = get_level_by_depth(p_depth)
	if level == null: return null
	return level.level_tiles


func get_level_by_depth(_depth: int) -> Level:
	var level: Level = null
	for lvl in get_tree().get_nodes_in_group("levels"):
		if not lvl is Level: continue
		if lvl.depth == _depth:
			return lvl
	return level


func get_worldpos_from_global_position(g_pos: Vector2, level: Level) -> WorldPos:
	var world_pos: WorldPos
	var _pos = level.to_local(g_pos)
	var tile: Vector2i = Vector2i((_pos / TileSpace.TILE_PIXELS).floor())
	world_pos = WorldPos.new(tile.x, tile.y, level.depth)
	return world_pos


func depth_to_display(depth: int) -> String:
	if depth == 0: return "Surface"
	return str(0-depth)


func display_to_depth(depth: String) -> int:
	if depth == "Surface": return 0
	if depth.is_valid_int(): return abs(int(depth))
	return -99


func is_in_bounds(pos: WorldPos) -> bool:
	var _bounds: LevelBound = level_bounds.get_bounds(pos.depth)
	if not _bounds: return false
	var _distance = Vector2(0,0).distance_to(Vector2(pos.x,pos.y))
	return _distance <= _bounds.radius


func set_world_seed(_seed: String) -> void:
	world_seed = hash(_seed)
	Global.emit_signal("debug_event","World Seed",str(world_seed))


func _dig_tile(actor: Actor, tile: WorldPos) -> void:
	var tiles: LevelTiles = get_level_tiles_from_depth(tile.depth)
	if tiles == null:
		push_error("Tile at %s is missing. Cannot complete the dig." % tile._to_string())
		dig_refused.emit(actor, tile, REFUSAL_REASON.LEVEL_NOT_EXIST)
		return
	tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)
	tiles.set_ore(tile.x, tile.y, TileKind.ORE.NONE)
	tile_dug.emit(actor, tile)


func _on_dig_requested(actor: Actor, tile: WorldPos) -> void:
	# Verify that the tile is still diggable
	var reason: REFUSAL_REASON
	reason = _is_ready_for_dig(tile)
	if reason != REFUSAL_REASON.NONE: 
		dig_refused.emit(actor, tile, reason)
		return
	
	# Dig it
	_dig_tile(actor, tile)


func _is_ready_for_dig(tile: WorldPos) -> REFUSAL_REASON:
	var level: Level = get_level_by_depth(tile.depth)
	
	# Verify the level exists
	if not level: 
		return REFUSAL_REASON.LEVEL_NOT_EXISTS
	
	# Tile does not exist
	var kind: int = level.level_tiles.get_top(tile.x, tile.y)
	if TileKind.is_sentinel(kind): 
		return REFUSAL_REASON.TILE_NOT_EXISTS
	
	# Tile is not diggable
	if not TileKind.is_diggable(kind): 
		return REFUSAL_REASON.TILE_NOT_DIGGABLE
	
	return REFUSAL_REASON.NONE


















