extends Node

var world_seed: int
var level_bounds: Resource = preload("res://src/world/level_bounds.tres")

signal tile_dug(actor: Actor, tile: WorldPos)

func _ready() -> void:
	set_world_seed("Default Seed")
	connect("tile_dug",dig_tile)


func get_level_tiles_from_depth(_depth: int) -> LevelTiles:
	var tiles: LevelTiles
	for lvl in get_tree().get_nodes_in_group("levels"):
		if lvl is not Level: continue
		if lvl.depth == _depth:
			tiles = lvl.level_tiles
	return tiles


func get_level(_depth: int) -> Level:
	var level: Level
	for lvl in get_tree().get_nodes_in_group("levels"):
		if lvl is not Level: continue
		if lvl.depth == _depth:
			level = lvl
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


func dig_tile(actor: Actor, tile: WorldPos) -> void:
	print("Dug tile: %s by %s" % [tile._to_string(), actor.actor_name])
	
	# TODO: Code for changing the TOP to OPEN and handling dropped ore
	



























