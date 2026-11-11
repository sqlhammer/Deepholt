class_name RefusalNotice
extends ScaledHud

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
	World.BREACH_REFUSAL.NEEDS_PICK: "Breaching needs a pick.",
}

# Said once per tile faced (D-217, D-218). Other dig refusals are no
# attempt (open floor, the edge) and stay quiet.
const DIG_REASONS: Dictionary = {
	World.DIG_REFUSAL.CRUSHED: "Collapsed solid. Clearing this needs shoring and jacks.",
	World.DIG_REFUSAL.TOOL_TOO_WEAK: "This ore is too hard for your pick.",
}

const PLACE_REASONS: Dictionary = {
	World.FIXTURE_REFUSAL.LEVEL_NOT_EXISTS: "There's nothing below this level.",
	World.FIXTURE_REFUSAL.TILE_NOT_EXISTS: "That's past the edge of the level.",
	World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE: "There's no floor below for it to stand on.",
	World.FIXTURE_REFUSAL.NO_HOLE_ABOVE: "A ladder goes in a hole.",
	World.FIXTURE_REFUSAL.TILE_OCCUPIED: "Something below is in the way.",
	World.FIXTURE_REFUSAL.CANNOT_AFFORD: "You don't have enough to build that.",
	World.FIXTURE_REFUSAL.ACTOR_ON_TILE: "Someone is standing there.",
}

var text: String:
	get: return _label.text

var _view: View
var _world: World
var _label: Label
var _remaining: float = 0.0


func _init() -> void:
	super()
	name = "RefusalNotice"
	layer = 90
	_label = Label.new()
	_label.name = "Label"
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Above the carry bar and the hotbar
	_label.offset_bottom = -62
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	root.add_child(_label)


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
		_world.ceiling_failing.disconnect(_on_ceiling_failing)
		_world.actor_moved_clear.disconnect(_on_actor_moved_clear)
		_world.took.disconnect(_on_took)
		_world.chop_refused.disconnect(_on_chop_refused)
		_world.dig_refused.disconnect(_on_dig_refused)
	_world = world
	if _world != null:
		_world.breach_refused.connect(_on_breach_refused)
		_world.request_refused.connect(_on_request_refused)
		_world.climb_refused.connect(_on_climb_refused)
		_world.ceiling_failing.connect(_on_ceiling_failing)
		_world.actor_moved_clear.connect(_on_actor_moved_clear)
		_world.took.connect(_on_took)
		_world.chop_refused.connect(_on_chop_refused)
		_world.dig_refused.connect(_on_dig_refused)


# Build mode's own preview refusals (D-154): too dark, not a hole.
func watch_cursor(cursor: BuildCursor) -> void:
	cursor.cursor_refused.connect(show_text)


func _on_request_refused(actor: Actor, _verb: World.FIXTURE_VERB, _tile: WorldPos,
		reason: World.FIXTURE_REFUSAL) -> void:
	if _view == null or actor != _view.actor: return
	show_text(PLACE_REASONS.get(reason, "That can't go there."))


# A region began to fail where the player is (D-166). The collapse
# itself isn't announced: the cracks and this are the warning.
func _on_ceiling_failing(depth: int, _tiles: Array[Vector2i]) -> void:
	if _view == null or not is_instance_valid(_view.actor) or _view.actor.depth != depth: return
	show_text("The ceiling is failing.")


func _on_actor_moved_clear(actor: Actor, _from: WorldPos, _to: WorldPos) -> void:
	if _view == null or actor != _view.actor: return
	show_text("The ceiling came down on you.")


func _on_chop_refused(actor: Actor, _tile: WorldPos, reason: World.CHOP_REFUSAL) -> void:
	if _view == null or actor != _view.actor: return
	if reason == World.CHOP_REFUSAL.NEEDS_AXE: show_text("Chopping needs an axe.")


# The take key says what it did (D-167), so pad A taking instead of
# climbing is never a mystery.
func _on_took(actor: Actor, items: Dictionary) -> void:
	if _view == null or actor != _view.actor: return
	show_text(took_text(items))


static func took_text(items: Dictionary) -> String:
	if items.is_empty(): return "Nothing in reach to take."
	var parts: PackedStringArray = []
	for id: StringName in items:
		var item: Item = ItemRegistry.find(id)
		parts.append("%d %s" % [items[id], item.display_key if item != null else String(id)])
	return "Took %s." % ", ".join(parts)


func _on_dig_refused(actor: Actor, _tile: WorldPos, reason: World.DIG_REFUSAL) -> void:
	if _view == null or actor != _view.actor: return
	if DIG_REASONS.has(reason): show_text(DIG_REASONS[reason])


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
