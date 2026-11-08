class_name BreachCracks
extends Node2D

# Shows a breach working (D-153): cracks spread across the floor the
# followed actor is breaching, in STAGES steps as the work goes on,
# and are gone the moment it's released, refused or done.
# Presentation, for the followed actor only (D-045); it reads the
# breach capability's progress and changes nothing. An actor
# animation and sound come later, with art and audio.

const STAGES: int = 4
const CRACK_COLOR: Color = Color(0.05, 0.03, 0.02, 0.85)

# Each stage adds its lines to the ones before, in tile pixels from
# the tile's top-left: a crack from the middle outward, then branches.
const LINES: Array = [
	[Vector2(8, 8), Vector2(5, 4), Vector2(8, 8), Vector2(11, 11)],
	[Vector2(5, 4), Vector2(2, 3), Vector2(11, 11), Vector2(14, 10), Vector2(8, 8), Vector2(12, 5)],
	[Vector2(12, 5), Vector2(14, 2), Vector2(8, 8), Vector2(4, 12), Vector2(5, 4), Vector2(6, 1)],
	[Vector2(4, 12), Vector2(1, 14), Vector2(11, 11), Vector2(10, 15), Vector2(12, 5), Vector2(15, 6)],
]

var _view: View
# The stage drawn, 0 for none, and the tile it's drawn on
var stage: int = 0
var tile: Vector2i


func _init() -> void:
	name = "BreachCracks"
	z_index = 5


func watch(view: View) -> void:
	_view = view


# How many stages of cracks show for this much of a breach's work.
static func stage_for(progress: float, work: float) -> int:
	if work <= 0.0 or progress <= 0.0: return 0
	return clampi(int(progress / work * STAGES) + 1, 1, STAGES)


func _process(_delta: float) -> void:
	var now: int = 0
	var capability: CapabilityBreach = _capability()
	if capability != null and capability.current_tile != null \
			and capability.current_tile.depth == _view.shown_depth:
		now = stage_for(capability.progress, capability.work)
		tile = Vector2i(capability.current_tile.x, capability.current_tile.y)
	if now != stage:
		stage = now
		queue_redraw()


func _capability() -> CapabilityBreach:
	if _view == null or not is_instance_valid(_view.actor): return null
	return _view.actor.get_node_or_null("Capabilities/CapabilityBreach")


func _draw() -> void:
	var corner: Vector2 = Vector2(tile) * TileSpace.TILE_PIXELS
	for s in range(stage):
		var points: Array = LINES[s]
		for i in range(0, points.size(), 2):
			draw_line(corner + points[i], corner + points[i + 1], CRACK_COLOR, 1.0)
