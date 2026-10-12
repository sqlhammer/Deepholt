class_name DebugDepth
extends Node

# Throwaway, like slice 001's debug pan: '-' moves the locally
# controlled actor one depth down and '=' one up, at the same
# (x, y). It exists to put a depth change on screen before ramps and
# ladders do, and is deleted once they work (slice 002 checklist).
# The actor refuses a landing it can't stand on (D-093), and the
# refusal shows in F3.

const SECTION: String = "Debug depth"

var actor: Actor


func setup(p_actor: Actor) -> void:
	actor = p_actor
	name = "DebugDepth%s" % p_actor.actor_name


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_depth_down"):
		step(1)
	elif event.is_action_pressed("debug_depth_up"):
		step(-1)


# +1 is one level deeper (internal depth is positive going down).
func step(direction: int) -> bool:
	var here: WorldPos = actor.current_WorldPos
	var target: WorldPos = WorldPos.new(here.x, here.y, here.depth + direction)
	var where: String = "(%d, %d) depth %s" % [
		target.x, target.y, World.depth_to_display(target.depth)]
	if actor.change_depth(target):
		Global.debug_event.emit(SECTION, "moved to %s" % where, false)
		return true
	Global.debug_event.emit(SECTION, "refused: %s is not open floor" % where, false)
	return false
