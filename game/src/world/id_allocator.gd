class_name IdAllocator
extends RefCounted

var _next: int = 1  # 0 = "no id"

func allocate() -> int:
	var id := _next
	_next += 1
	return id

# Call for every id read from a save, so a stale or hand-edited
# counter can never hand out an id that is already in use.
func claim(id: int) -> void:
	_next = maxi(_next, id + 1)

