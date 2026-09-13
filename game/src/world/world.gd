extends Node

var world_seed: int
var level_bounds: Resource = preload("res://src/world/level_bounds.tres")


func _ready() -> void:
	set_world_seed("Default Seed")


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
	Global.emit_signal("debug_event",["World Seed",str(world_seed)])




