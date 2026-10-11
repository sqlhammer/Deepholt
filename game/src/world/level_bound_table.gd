extends Resource
class_name LevelBoundTable

@export var rows: Array[LevelBound] = []


func get_bounds(depth: int) -> LevelBound:
	for row in rows:
		if not row is LevelBound: 
			continue
		if row.depth == depth:
			return row
	
	push_error("LevelBound for depth %d was not found." % depth)
	return null















