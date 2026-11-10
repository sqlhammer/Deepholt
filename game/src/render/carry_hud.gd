class_name CarryHud
extends CanvasLayer

# The followed actor's carry weight, always on screen (D-159, ui-ux
# §5): a slim bar at the bottom center, above the hotbar, and
# "20 / 60 kg" beside it. The bar runs to 150% of capacity, with a
# mark at 100%; its color changes at the load curve's bands (50%,
# 100%, 150%), and past 150% the end is hatched. Presentation: it
# follows the view's actor (D-045), and reads that actor's world's
# capacity.

const BAR_SIZE: Vector2 = Vector2(180, 8)
const BAR_SPAN: float = 1.5
const LIGHT: Color = Color(0.75, 0.75, 0.7)
const LOADED: Color = Color(0.9, 0.8, 0.35)
const HEAVY: Color = Color(0.95, 0.55, 0.25)
const OVER: Color = Color(0.95, 0.3, 0.25)

var text: String:
	get: return _label.text
# The load drawn, as a share of capacity
var ratio: float = 0.0

var _view: View
var _actor: Actor
var _bar: Control
var _label: Label


func _init() -> void:
	name = "CarryHud"
	layer = 80
	var box: HBoxContainer = HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Above the hotbar (ui-ux §4)
	box.offset_bottom = -30
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_bar = Control.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)
	_label = Label.new()
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	box.add_child(_label)


func watch(view: View) -> void:
	_view = view
	view.followed_moved.connect(_on_followed_moved)
	if view.actor != null: _on_followed_moved(view.actor)


# A new actor followed, or the same one moving: re-point only on a
# new one.
func _on_followed_moved(actor: Actor) -> void:
	if actor == _actor: return
	if is_instance_valid(_actor) and _actor.pack.changed.is_connected(_on_pack_changed):
		_actor.pack.changed.disconnect(_on_pack_changed)
	_actor = actor
	_actor.pack.changed.connect(_on_pack_changed)
	_on_pack_changed(_actor.pack)


func _on_pack_changed(pack: Pack) -> void:
	var capacity: float = 0.0
	if _actor.current_level and _actor.current_level.world:
		capacity = _actor.current_level.world.tuning.carry_capacity_kg
	ratio = _actor.load_ratio()
	_label.text = "%s / %s kg" % [_kg(pack.total_weight), _kg(capacity)]
	_bar.queue_redraw()


static func _kg(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


# The band's color for a load (the load curve's breakpoints, D-030).
static func color_for(p_ratio: float) -> Color:
	if p_ratio > 1.5: return OVER
	if p_ratio > 1.0: return HEAVY
	if p_ratio > 0.5: return LOADED
	return LIGHT


func _draw_bar() -> void:
	var size: Vector2 = _bar.size
	_bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var filled: float = clampf(ratio / BAR_SPAN, 0.0, 1.0) * size.x
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(filled, size.y)), color_for(ratio))
	# Past 150%: hatch the full bar's end, so overload reads by shape too
	if ratio > BAR_SPAN:
		for x in range(int(size.x) - 30, int(size.x), 4):
			_bar.draw_line(Vector2(x, size.y), Vector2(x + 4, 0), Color.BLACK)
	# The 100% mark
	var full: float = size.x / BAR_SPAN
	_bar.draw_line(Vector2(full, -2), Vector2(full, size.y + 2), Color.WHITE)
