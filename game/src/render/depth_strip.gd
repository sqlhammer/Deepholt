class_name DepthStrip
extends ScaledHud

# The depth strip (ui-ux §6): a thin column at the frame's right edge,
# one mark per level of the mountain, top to bottom, the one the
# followed actor is on filled and named. So which level you're on, and
# how many lie below, shows at a glance. A level not yet generated is
# drawn dimmer: it's there, nobody has been near it. Presentation: it
# follows the view (D-045).

const MARK: Vector2 = Vector2(6, 8)
const GAP: int = 2
const EDGE: int = 6
const HERE: Color = Color(1.0, 0.9, 0.45)
const KNOWN: Color = Color(0.7, 0.7, 0.65)
const UNKNOWN: Color = Color(0.35, 0.35, 0.33)

var _view: View
var _strip: Control


func _init() -> void:
	super()
	name = "DepthStrip"
	layer = 79
	_strip = Control.new()
	_strip.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_strip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_strip.grow_vertical = Control.GROW_DIRECTION_BOTH
	_strip.offset_right = -EDGE
	_strip.custom_minimum_size = Vector2(MARK.x + 24, depths() * (MARK.y + GAP))
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.draw.connect(_draw_strip)
	root.add_child(_strip)


func watch(view: View) -> void:
	_view = view
	view.shown_depth_changed.connect(func(_old: int, _new: int) -> void: _strip.queue_redraw())
	view.shown_world_changed.connect(func(_world: World, _depth: int) -> void: _strip.queue_redraw())


# How many levels the mountain has: one per recipe.
static func depths() -> int:
	return LevelRecipes.TABLE.rows.size()


# The depth marked as here, or -1 with nothing followed.
func here() -> int:
	if _view == null or not is_instance_valid(_view.actor): return -1
	return _view.actor.depth


# How many levels lie below the one marked.
func below() -> int:
	return depths() - 1 - here() if here() >= 0 else 0


func _draw_strip() -> void:
	var world: World = _view.shown_world if _view != null else null
	var at: int = here()
	for depth: int in range(depths()):
		var rect: Rect2 = Rect2(Vector2(24, depth * (MARK.y + GAP)), MARK)
		var known: bool = is_instance_valid(world) and world.level_at(depth) != null
		if depth == at:
			_strip.draw_rect(rect, HERE)
			_strip.draw_string(ScaledHud.FONT, Vector2(0, rect.end.y), DepthName.of(depth).left(3),
				HORIZONTAL_ALIGNMENT_RIGHT, 22, ScaledHud.FONT_SIZE, HERE)
		else:
			_strip.draw_rect(rect, KNOWN if known else UNKNOWN, false, 1.0)
