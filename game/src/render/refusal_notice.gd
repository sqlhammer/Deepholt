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
	World.BREACH_REFUSAL.SHAFTS_CANT_JOIN: "That would join two shafts that can't share.",
	World.BREACH_REFUSAL.TOO_DEEP: "The rock below is packed too deep to break.",
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
	World.FIXTURE_REFUSAL.NEEDS_HOLE: "That goes over a hole.",
	World.FIXTURE_REFUSAL.HOLE_IN_USE: "A hole holds one ladder, chute or winch.",
	World.FIXTURE_REFUSAL.LANDING_BLOCKED: BuildCursor.CRATE_NEEDS_FLOOR_TEXT,
	World.FIXTURE_REFUSAL.WINCH_SHAFT: BuildCursor.WINCH_SHAFT_TEXT,
}

const LOAD_REASONS: Dictionary = {
	World.LOAD_REFUSAL.NOT_SMELTABLE: "The smelter takes ore, copper and tin ingots, and coal.",
	World.LOAD_REFUSAL.FULL: "It's full.",
}

const CRANK_REASONS: Dictionary = {
	World.CRANK_REFUSAL.FROM_BELOW: "The winch is cranked from the top.",
	World.CRANK_REFUSAL.LANDING_BLOCKED: "Something is in the crate's way.",
	World.CRANK_REFUSAL.CRATE_FULL: "The crate is full.",
	World.CRANK_REFUSAL.CRATE_ELSEWHERE: "The crate is at another winch in this shaft.",
}

var text: String:
	get: return _label.text

var _view: View
var _world: World
var _label: Label
var _remaining: float = 0.0
var _watched_hotbar: Hotbar = null
# The inventory: while it's open this notice is hidden under it, so a
# line goes to the board's own message instead (016's walk).
var _inventory: InventoryOverlay = null


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
		_world.crank_refused.disconnect(_on_crank_refused)
		_world.items_crated.disconnect(_on_items_crated)
		_world.load_refused.disconnect(_on_load_refused)
		_world.smelter_loaded.disconnect(_on_smelter_loaded)
		_world.bed_claimed.disconnect(_on_bed_claimed)
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
		_world.crank_refused.connect(_on_crank_refused)
		_world.items_crated.connect(_on_items_crated)
		_world.load_refused.connect(_on_load_refused)
		_world.smelter_loaded.connect(_on_smelter_loaded)
		_world.bed_claimed.connect(_on_bed_claimed)


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


func _on_crank_refused(actor: Actor, reason: World.CRANK_REFUSAL) -> void:
	if _view == null or actor != _view.actor: return
	if CRANK_REASONS.has(reason): show_text(CRANK_REASONS[reason])


# How full the crate is, each time something goes in (D-224, D-249).
func _on_items_crated(actor: Actor, crate: Fixture, _id: StringName, _count: int) -> void:
	if _view == null or actor != _view.actor: return
	if crate.kind == ObjectKind.OBJECT.STORAGE_CRATE:
		show_text(storage_text(crate.contents.total_weight, _world.tuning.storage_capacity_kg))
		return
	show_text(crate_text(crate.contents.total_weight, _world.tuning.crate_capacity_kg))


static func storage_text(weight: float, capacity: float) -> String:
	return "In storage: %d / %d kg" % [roundi(weight), roundi(capacity)]


func _on_load_refused(actor: Actor, _container: Fixture, reason: World.LOAD_REFUSAL) -> void:
	if _view == null or actor != _view.actor: return
	show_text(LOAD_REASONS.get(reason, "That doesn't go in."))


# What the smelter is working on, each time something goes in (D-238).
func _on_smelter_loaded(actor: Actor, smelter: Fixture, _id: StringName, _count: int) -> void:
	if _view == null or actor != _view.actor: return
	show_text(smelter_text(smelter))


static func smelter_text(smelter: Fixture) -> String:
	var parts: PackedStringArray = []
	var waiting: Dictionary[StringName, int] = smelter.machine.waiting()
	for id: StringName in waiting:
		var item: Item = ItemRegistry.find(id)
		parts.append("%d %s" % [waiting[id], item.display_key.to_lower() if item != null else String(id)])
	var text: String = "In the smelter: %s." % ", ".join(parts) if not parts.is_empty() \
		else "The smelter is empty."
	if not smelter.machine.is_working() and not waiting.is_empty():
		text += " Needs coal and 3 of an ore." if smelter.machine.coal <= 0 \
			else " Not enough of anything for a batch."
	return text


func _on_bed_claimed(actor: Actor, _bed: Fixture) -> void:
	if _view == null or actor != _view.actor: return
	show_text("This bed is yours. You'll wake here.")


# The followed player's lantern ran dry, or was lit with no oil (D-246).
func _on_light_dry(_hotbar: Hotbar) -> void:
	show_text("No lamp oil for the lantern.")


# Follows the followed player's hotbar for its lantern, as the view's
# player changes.
func _watch_hotbar() -> void:
	var hotbar: Hotbar = _view.actor.hotbar if _view != null and is_instance_valid(_view.actor) else null
	if hotbar == _watched_hotbar: return
	if _watched_hotbar != null and _watched_hotbar.light_dry.is_connected(_on_light_dry):
		_watched_hotbar.light_dry.disconnect(_on_light_dry)
	_watched_hotbar = hotbar
	if hotbar != null: hotbar.light_dry.connect(_on_light_dry)


static func crate_text(weight: float, capacity: float) -> String:
	return "In the crate: %d / %d kg" % [roundi(weight), roundi(capacity)]


func _on_climb_refused(actor: Actor, _tile: WorldPos) -> void:
	if _view == null or actor != _view.actor: return
	show_text("Too heavy to climb.")


func _on_breach_refused(actor: Actor, _tile: WorldPos, reason: World.BREACH_REFUSAL) -> void:
	if _view == null or actor != _view.actor: return
	show_text(BREACH_REASONS.get(reason, "That can't be breached."))


func watch_inventory(inventory: InventoryOverlay) -> void:
	super(inventory)
	_inventory = inventory


func show_text(p_text: String) -> void:
	if _inventory != null and _inventory.is_open:
		_inventory.show_message(p_text)
		return
	_label.text = p_text
	_label.modulate.a = 1.0
	_remaining = SHOW_SECONDS


func _process(delta: float) -> void:
	_watch_hotbar()
	if _remaining <= 0.0: return
	_remaining -= delta
	# The last half second fades
	_label.modulate.a = clampf(_remaining / 0.5, 0.0, 1.0)
	if _remaining <= 0.0: _label.text = ""
