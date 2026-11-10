class_name CollapseCracks
extends Node2D

# The warning on a failing ceiling (D-166): cracks spread across each
# failing tile of the shown level in three stages as its countdown
# runs, whether or not the overlay is up. Presentation: it reads the
# shown level's support and changes nothing. Sound comes later, with
# audio.

const STAGES: int = 3
const CRACK_COLOR: Color = Color(0.05, 0.03, 0.02, 0.85)

# Each stage adds its lines to the ones before, in tile pixels from the
# tile's top-left: a crack from the middle outward, then branches.
const LINES: Array = [
	[Vector2(8, 8), Vector2(4, 3), Vector2(8, 8), Vector2(12, 12)],
	[Vector2(4, 3), Vector2(1, 4), Vector2(12, 12), Vector2(15, 10), Vector2(8, 8), Vector2(13, 4)],
	[Vector2(13, 4), Vector2(14, 1), Vector2(8, 8), Vector2(3, 13), Vector2(4, 3), Vector2(6, 0),
		Vector2(12, 12), Vector2(10, 15)],
]

var _world: World
var _support: LevelSupport
var _visibility: Visibility
# What is drawn, per tile: the stage. Redrawn only when one changes.
var _drawn: Dictionary[Vector2i, int] = {}


func _init() -> void:
	name = "CollapseCracks"
	z_index = 5


func watch(view: View) -> void:
	view.shown_world_changed.connect(_on_shown_world_changed)
	view.shown_depth_changed.connect(_on_shown_depth_changed)
	if view.shown_world != null:
		_on_shown_world_changed(view.shown_world, view.shown_depth)


func watch_visibility(visibility: Visibility) -> void:
	_visibility = visibility
	visibility.states_changed.connect(_redraw)


# How many stages of cracks show this far into a countdown: one as it
# begins, all of them in its last third.
static func stage_for(progress: float) -> int:
	return clampi(int(progress * STAGES) + 1, 1, STAGES)


func _on_shown_world_changed(world: World, depth: int) -> void:
	_world = world
	_show(depth)


func _on_shown_depth_changed(_old_depth: int, depth: int) -> void:
	_show(depth)


func _show(depth: int) -> void:
	var level: Level = _world.level_at(depth) if is_instance_valid(_world) else null
	_support = level.support if level != null else null
	_redraw()


func _process(_delta: float) -> void:
	if _support == null or not (_support.has_failing() or not _drawn.is_empty()): return
	# Only when some tile's stage moved
	if _stages() != _drawn: _redraw()


func _stages() -> Dictionary[Vector2i, int]:
	var stages: Dictionary[Vector2i, int] = {}
	if _support == null: return stages
	for tile: Vector2i in _support.failing_tiles():
		if _visibility != null and _visibility.state_at(tile.x, tile.y) < Visibility.STATE.REMEMBERED:
			continue
		stages[tile] = stage_for(_support.progress_at(tile))
	return stages


func _redraw() -> void:
	_drawn = _stages()
	queue_redraw()


func _draw() -> void:
	for tile: Vector2i in _drawn:
		var corner: Vector2 = Vector2(tile) * TileSpace.TILE_PIXELS
		# Mirrored on alternate tiles, so a room doesn't tile one crack
		var mirrored: bool = (tile.x + tile.y) % 2 != 0
		for stage in range(_drawn[tile]):
			var points: Array = LINES[stage]
			for index in range(0, points.size(), 2):
				var from: Vector2 = points[index]
				var to: Vector2 = points[index + 1]
				if mirrored:
					from.x = TileSpace.TILE_PIXELS - from.x
					to.x = TileSpace.TILE_PIXELS - to.x
				draw_line(corner + from, corner + to, CRACK_COLOR, 1.0)
