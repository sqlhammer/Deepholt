class_name WorldPos
extends RefCounted

var x: int
var y: int
var depth: int

func _init(p_x: int, p_y: int, p_depth: int) -> void:
	x = p_x
	y = p_y
	depth = p_depth

func _to_string() -> String:
	return "(%d, %d, %d)" % [x, y, depth]

func hash_value() -> int:
	return hash([x, y, depth])

func equals(other: WorldPos) -> bool:
	return x == other.x and y == other.y and depth == other.depth
