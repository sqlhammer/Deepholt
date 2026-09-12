extends Resource
class_name LevelBoundTable

@export var rows: Array[LevelBound] = []


func get_bounds(depth: int) -> LevelBound:
	var bounds: LevelBound
	
	if depth < 0 or depth >= rows.size():
		push_error("LevelBound for depth %d was not found." % depth)
		return
	
	bounds = rows[depth]
	return bounds


