class_name DepthName
extends RefCounted

# How a depth is shown to a player: "Surface" for 0, and the floors
# below it as negative numbers. Stateless, so it needs no world
# (D-118, D-124).


# Depth 0 is "Surface"; depth 3 is "-3".
static func of(depth: int) -> String:
	if depth == 0: return "Surface"
	return str(0 - depth)


# The depth a display name stands for, or -99 if it names none.
static func to_depth(display_name: String) -> int:
	if display_name == "Surface": return 0
	if display_name.is_valid_int(): return abs(int(display_name))
	return -99
