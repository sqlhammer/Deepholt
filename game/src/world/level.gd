extends Node2D
class_name Level

var _depth: int = -1
var depth: int:
	get: return _depth
var level_seed: int


func _ready() -> void:
	set_depth(0) # debug


func set_depth(_d: int) -> void:
	_depth = clamp_depth(_d)
	_set_level_seed()


func clamp_depth(_d: int) -> int:
	var _min: int = 0
	var _max: int = World.level_bounds.rows.size() - 1
	return clamp(_d,_min,_max)


func _set_level_seed() -> void:
	level_seed = hash("%s|%d" % [World.world_seed, _depth])
	Global.emit_signal("debug_event","Level Seed",str(level_seed))


