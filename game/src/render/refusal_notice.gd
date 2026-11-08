class_name RefusalNotice
extends CanvasLayer

# Tells the player why their action was refused (D-141's feedback,
# D-152): a line at the bottom of the screen, gone after a few
# seconds. Presentation: it shows only the followed actor's refusals
# (D-045), heard on the shown world, re-pointed when the world changes
# (D-129).

# How long a refusal stays on screen, in seconds. Presentation only,
# and too small a choice for the tuning profile.
const SHOW_SECONDS: float = 2.5

const BREACH_REASONS: Dictionary = {
	World.BREACH_REFUSAL.LEVEL_NOT_EXISTS: "There's nothing here to breach.",
	World.BREACH_REFUSAL.TILE_NOT_EXISTS: "That's past the edge of the level.",
	World.BREACH_REFUSAL.NOT_PLAIN_FLOOR: "Only plain open floor can be breached.",
	World.BREACH_REFUSAL.FIXTURE_ON_TILE: "Something stands on that floor.",
	World.BREACH_REFUSAL.ACTOR_ON_TILE: "Someone is standing there.",
	World.BREACH_REFUSAL.NO_LEVEL_BELOW: "There's nothing below this level.",
	World.BREACH_REFUSAL.LANDING_NOT_EXISTS: "Below that is past the edge of the next level.",
	World.BREACH_REFUSAL.LANDING_BLOCKED: "Something below is in the way.",
	World.BREACH_REFUSAL.TOOL_TOO_WEAK: "This floor is too hard for your tool.",
}

const PLACE_REASONS: Dictionary = {
	World.FIXTURE_REFUSAL.LEVEL_NOT_EXISTS: "There's nothing below this level.",
	World.FIXTURE_REFUSAL.TILE_NOT_EXISTS: "That's past the edge of the level.",
	World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE: "There's no floor below for it to stand on.",
	World.FIXTURE_REFUSAL.NO_HOLE_ABOVE: "A ladder goes in a hole.",
	World.FIXTURE_REFUSAL.TILE_OCCUPIED: "Something below is in the way.",
	World.FIXTURE_REFUSAL.CANNOT_AFFORD: "You don't have enough to build that.",
}

var text: String:
	get: return _label.text

var _view: View
var _world: World
var _label: Label
var _remaining: float = 0.0


func _init() -> void:
	name = "RefusalNotice"
	layer = 90
	_label = Label.new()
	_label.name = "Label"
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_bottom = -24
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)


func watch(view: View) -> void:
	_view = view
	view.shown_world_changed.connect(_on_shown_world_changed)
	if view.shown_world != null:
		_on_shown_world_changed(view.shown_world, view.shown_depth)


func _on_shown_world_changed(world: World, _depth: int) -> void:
	if is_instance_valid(_world) and _world.breach_refused.is_connected(_on_breach_refused):
		_world.breach_refused.disconnect(_on_breach_refused)
		_world.request_refused.disconnect(_on_request_refused)
		_world.climb_refused.disconnect(_on_climb_refused)
	_world = world
	if _world != null:
		_world.breach_refused.connect(_on_breach_refused)
		_world.request_refused.connect(_on_request_refused)
		_world.climb_refused.connect(_on_climb_refused)


# Build mode's own preview refusals (D-154): too dark, not a hole.
func watch_cursor(cursor: BuildCursor) -> void:
	cursor.cursor_refused.connect(show_text)


func _on_request_refused(actor: Actor, _verb: World.FIXTURE_VERB, _tile: WorldPos,
		reason: World.FIXTURE_REFUSAL) -> void:
	if _view == null or actor != _view.actor: return
	show_text(PLACE_REASONS.get(reason, "That can't go there."))


func _on_climb_refused(actor: Actor, _tile: WorldPos) -> void:
	if _view == null or actor != _view.actor: return
	show_text("Too heavy to climb.")


func _on_breach_refused(actor: Actor, _tile: WorldPos, reason: World.BREACH_REFUSAL) -> void:
	if _view == null or actor != _view.actor: return
	show_text(BREACH_REASONS.get(reason, "That can't be breached."))


func show_text(p_text: String) -> void:
	_label.text = p_text
	_label.modulate.a = 1.0
	_remaining = SHOW_SECONDS


func _process(delta: float) -> void:
	if _remaining <= 0.0: return
	_remaining -= delta
	# The last half second fades
	_label.modulate.a = clampf(_remaining / 0.5, 0.0, 1.0)
	if _remaining <= 0.0: _label.text = ""
