class_name SupportOverlay
extends Node2D

# The support overlay (D-163, digging-and-structure §4): the shown
# level's excavated ceiling tinted green, amber or red for Stable,
# Marginal and Failing, and a mark besides the tint so it reads
# without color (ui-ux §7): nothing, a slash, a cross. A toggle, off
# until asked for. Presentation: it reads the shown level's support
# and changes nothing. Its rings and ghosted suggestions come later.

const STABLE_COLOR: Color = Color(0.25, 0.85, 0.35, 0.30)
const MARGINAL_COLOR: Color = Color(0.98, 0.72, 0.12, 0.45)
const FAILING_COLOR: Color = Color(0.92, 0.2, 0.15, 0.55)
const MARK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.7)

# Whether the overlay is showing
var active: bool = false

var _world: World
var _support: LevelSupport
var _visibility: Visibility


func _init() -> void:
	name = "SupportOverlay"
	z_index = 3
	visible = false


func watch(view: View) -> void:
	view.shown_world_changed.connect(_on_shown_world_changed)
	view.shown_depth_changed.connect(_on_shown_depth_changed)
	if view.shown_world != null:
		_on_shown_world_changed(view.shown_world, view.shown_depth)


# A tile nobody has seen isn't tinted: the overlay shows what you've
# dug, not where the rock is thin.
func watch_visibility(visibility: Visibility) -> void:
	_visibility = visibility
	visibility.states_changed.connect(queue_redraw)


func toggle() -> void:
	set_active(not active)


func set_active(value: bool) -> void:
	active = value
	visible = active
	queue_redraw()


func _on_shown_world_changed(world: World, depth: int) -> void:
	_world = world
	_show(depth)


func _on_shown_depth_changed(_old_depth: int, depth: int) -> void:
	_show(depth)


func _show(depth: int) -> void:
	if _support != null and _support.states_changed.is_connected(_on_states_changed):
		_support.states_changed.disconnect(_on_states_changed)
	var level: Level = _world.level_at(depth) if is_instance_valid(_world) else null
	_support = level.support if level != null else null
	if _support != null: _support.states_changed.connect(_on_states_changed)
	queue_redraw()


func _on_states_changed(_tiles: Array[Vector2i]) -> void:
	queue_redraw()


# The tint a state is drawn in, or transparent for a tile not judged.
static func color_for(state: LevelSupport.STATE) -> Color:
	match state:
		LevelSupport.STATE.STABLE: return STABLE_COLOR
		LevelSupport.STATE.MARGINAL: return MARGINAL_COLOR
		LevelSupport.STATE.FAILING: return FAILING_COLOR
	return Color.TRANSPARENT


func _draw() -> void:
	if not active or _support == null: return
	var size: float = TileSpace.TILE_PIXELS
	for tile: Vector2i in _support.judged_tiles():
		if _visibility != null and _visibility.state_at(tile.x, tile.y) < Visibility.STATE.REMEMBERED:
			continue
		var state: LevelSupport.STATE = _support.state_at(tile)
		var corner: Vector2 = Vector2(tile) * size
		draw_rect(Rect2(corner, Vector2(size, size)), color_for(state))
		match state:
			LevelSupport.STATE.MARGINAL:
				draw_line(corner + Vector2(4, 12), corner + Vector2(12, 4), MARK_COLOR, 1.0)
			LevelSupport.STATE.FAILING:
				draw_line(corner + Vector2(4, 4), corner + Vector2(12, 12), MARK_COLOR, 1.0)
				draw_line(corner + Vector2(12, 4), corner + Vector2(4, 12), MARK_COLOR, 1.0)
