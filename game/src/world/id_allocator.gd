class_name IdAllocator
extends RefCounted

# One of a world's id counters (D-104, D-114, D-118): hands out ints
# that are never reused. 0 is "no id", so the first is 1.

const FIRST_ID: int = 1

var _next: int = FIRST_ID


func allocate() -> int:
	var id: int = _next
	_next += 1
	return id


# The id the next allocate() hands out, without taking it.
func peek() -> int:
	return _next


# Sets the next id outright, as a load restores a saved counter. Ids
# already in use are claimed after this, never before (D-130).
func restore(next: int) -> void:
	_next = maxi(next, FIRST_ID)


# Call for every id read from a save, so a stale or hand-edited
# counter can never hand out an id that is already in use.
func claim(id: int) -> void:
	_next = maxi(_next, id + 1)
