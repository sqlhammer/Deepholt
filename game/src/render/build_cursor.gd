class_name BuildCursor
extends Node2D

# Build mode's anchored cursor (D-154, ui-ux §2.1, §7): a grid cursor
# clamped to a radius around the local player, moved by the mouse or
# the right stick with the same reach. Presentation: it knows the
# local player (D-045). It places nothing itself: placing is a request
# on the player's world, and the preview asks the same rules the
# fixture gatekeeper enforces, so the two can't disagree.
#
# A ladder is aimed at a hole on the player's own level, and placed on
# the level below at the same (x, y) (D-154). A timber prop is placed
# on open floor at the cursor, on the player's own level (D-165). A
# chute is aimed at a hole and placed over it, on the player's own
# level (D-219). Only
# on a tile the player can sense or see lit: nobody builds blind.

# The preview refused a placement before asking the world: shown like
# any refusal.
signal cursor_refused(text: String)
# Entered or left: the hotbar shows build slots while it's active
# (D-170).
signal active_changed(active: bool)

# Why the cursor's tile can't take a ladder, or NONE.
enum PROBLEM {
	NONE,
	TOO_DARK,
	NO_LEVEL_BELOW,
	NOT_A_HOLE,
	LANDING_NOT_PASSABLE,
	LANDING_OCCUPIED,
	OUTSIDE_LEVEL,
	CANNOT_AFFORD,
	NOT_OPEN_FLOOR,
	TILE_OCCUPIED,
	ACTOR_IN_WAY,
	NOTHING_SELECTED,
	NEEDS_HOLE,
	HOLE_IN_USE,
}

const REASONS: Dictionary = {
	PROBLEM.TOO_DARK: "Too dark to see there.",
	PROBLEM.NO_LEVEL_BELOW: "There's nothing below this level.",
	PROBLEM.NOT_A_HOLE: "A ladder goes in a hole.",
	PROBLEM.LANDING_NOT_PASSABLE: "There's no floor below for it to stand on.",
	PROBLEM.LANDING_OCCUPIED: "Something below is in the way.",
	PROBLEM.OUTSIDE_LEVEL: "That's past the edge of the level.",
	PROBLEM.CANNOT_AFFORD: "You don't have enough to build that.",
	PROBLEM.NOT_OPEN_FLOOR: "A prop stands on open floor.",
	PROBLEM.TILE_OCCUPIED: "Something is already there.",
	PROBLEM.ACTOR_IN_WAY: "Someone is standing there.",
	PROBLEM.NOTHING_SELECTED: "Nothing to build in that slot.",
	PROBLEM.NEEDS_HOLE: "That goes over a hole.",
	PROBLEM.HOLE_IN_USE: "A hole holds one ladder, chute or winch.",
}

# How long the stick holds a direction before the cursor steps again,
# in seconds. Feel, not tuning.
const STICK_REPEAT_SECONDS: float = 0.15
# How strongly the ghost of what's placed shows through, tinted the
# cursor's color.
const GHOST_ALPHA: float = 0.5
const VALID_COLOR: Color = Color(0.45, 0.95, 0.5)
const INVALID_COLOR: Color = Color(1.0, 0.4, 0.35)

var active: bool = false
var actor: Actor
# What the screen shows of each tile (D-146), for "too dark to see"
var visibility: Visibility
# The cursor's tile on the actor's level
var tile: Vector2i = Vector2i.ZERO
# What the cursor places: the actor's selected build slot (D-170),
# NULL when that slot is empty
var item: int:
	get: return actor.hotbar.build() if actor != null else ObjectKind.OBJECT.NULL

var _stick_wait: float = 0.0


func _init() -> void:
	name = "BuildCursor"
	z_index = 10
	visible = false


# --- the mode ---

func toggle() -> void:
	set_active(not active)


func set_active(value: bool) -> void:
	var was: bool = active
	active = value and actor != null
	visible = active
	if active: tile = _actor_tile()
	queue_redraw()
	if active != was: active_changed.emit(active)


# --- moving it (ui-ux §2.1: same reach for both inputs) ---

func radius() -> int:
	return actor.current_level.world.tuning.build_cursor_radius


# The tile under a point in the level, clamped into reach.
func point_at(world_point: Vector2) -> void:
	set_tile(Vector2i((world_point / TileSpace.TILE_PIXELS).floor()))


# One step in a direction while the stick is held, then again every
# STICK_REPEAT_SECONDS. A centered stick lets the next push step at
# once.
func step(direction: Vector2, delta: float) -> void:
	if direction.length() < 0.5:
		_stick_wait = 0.0
		return
	_stick_wait -= delta
	if _stick_wait > 0.0: return
	_stick_wait = STICK_REPEAT_SECONDS
	set_tile(tile + Vector2i(roundi(direction.x), roundi(direction.y)))


# Clamped to a disc around the actor, the way level bounds are discs.
func set_tile(wanted: Vector2i) -> void:
	var here: Vector2i = _actor_tile()
	var offset: Vector2 = Vector2(wanted - here)
	var limit: int = radius()
	if offset.length() > limit:
		offset = offset.normalized() * limit
		var rounded: Vector2i = Vector2i(roundi(offset.x), roundi(offset.y))
		# Rounding a diagonal can step outside the disc; truncating can't
		if Vector2(rounded).length() > limit: rounded = Vector2i(offset)
		wanted = here + rounded
	tile = wanted
	queue_redraw()


func _actor_tile() -> Vector2i:
	var here: WorldPos = actor.current_WorldPos
	return Vector2i(here.x, here.y)


# --- what can go there ---

# Why `kind` (the selected item when none is given) can't go at the
# cursor, or NONE.
func problem(kind: int = -1) -> PROBLEM:
	if kind == -1: kind = item
	if actor == null or actor.current_level == null: return PROBLEM.OUTSIDE_LEVEL
	if kind not in Hotbar.BUILDABLE: return PROBLEM.NOTHING_SELECTED
	var level: Level = actor.current_level
	var tiles: LevelTiles = level.level_tiles
	if TileKind.is_sentinel(tiles.get_ground(tile.x, tile.y)): return PROBLEM.OUTSIDE_LEVEL
	if visibility != null and visibility.state_at(tile.x, tile.y) < Visibility.STATE.SENSED:
		return PROBLEM.TOO_DARK
	if kind == ObjectKind.OBJECT.TIMBER_PROP: return _prop_problem(level)
	if ObjectKind.is_over_hole(kind): return _over_hole_problem(level, kind)
	var below: Level = level.world.level_at(level.depth + 1)
	if below == null: return PROBLEM.NO_LEVEL_BELOW
	# The fixture gatekeeper's own rule, for a ladder below this tile
	var rule: World.FIXTURE_REFUSAL = FixturePlacement.problem(ObjectKind.OBJECT.LADDER, tile,
		below.level_tiles, below.level_fixtures, tiles, null, level.level_fixtures)
	match rule:
		World.FIXTURE_REFUSAL.NONE:
			# The gatekeeper's own cost rule (D-159)
			if not Building.can_afford(level.world.tuning, actor, ObjectKind.OBJECT.LADDER):
				return PROBLEM.CANNOT_AFFORD
			return PROBLEM.NONE
		World.FIXTURE_REFUSAL.NO_HOLE_ABOVE: return PROBLEM.NOT_A_HOLE
		World.FIXTURE_REFUSAL.HOLE_IN_USE: return PROBLEM.HOLE_IN_USE
		World.FIXTURE_REFUSAL.TILE_OCCUPIED: return PROBLEM.LANDING_OCCUPIED
		World.FIXTURE_REFUSAL.TILE_NOT_EXISTS: return PROBLEM.OUTSIDE_LEVEL
	return PROBLEM.LANDING_NOT_PASSABLE


# The gatekeeper's own rules for a prop on the cursor's tile of the
# player's level: open floor, nothing there, nobody standing on it, and
# the cost (D-159, D-165).
func _prop_problem(level: Level) -> PROBLEM:
	var rule: World.FIXTURE_REFUSAL = FixturePlacement.problem(ObjectKind.OBJECT.TIMBER_PROP, tile,
		level.level_tiles, level.level_fixtures, null)
	match rule:
		World.FIXTURE_REFUSAL.NONE: pass
		World.FIXTURE_REFUSAL.TILE_OCCUPIED: return PROBLEM.TILE_OCCUPIED
		World.FIXTURE_REFUSAL.TILE_NOT_EXISTS: return PROBLEM.OUTSIDE_LEVEL
		_: return PROBLEM.NOT_OPEN_FLOOR
	if level.world.blocks_actor(level, ObjectKind.OBJECT.TIMBER_PROP,
			WorldPos.new(tile.x, tile.y, level.depth)):
		return PROBLEM.ACTOR_IN_WAY
	if not Building.can_afford(level.world.tuning, actor, ObjectKind.OBJECT.TIMBER_PROP):
		return PROBLEM.CANNOT_AFFORD
	return PROBLEM.NONE


# The gatekeeper's own rules for a chute over the cursor's hole, on
# the player's level (D-219): an open hole, nothing over it, no ladder
# under it, and the cost.
func _over_hole_problem(level: Level, kind: int) -> PROBLEM:
	var below: Level = level.world.level_at(level.depth + 1)
	if below == null: return PROBLEM.NO_LEVEL_BELOW
	var rule: World.FIXTURE_REFUSAL = FixturePlacement.problem(kind, tile, level.level_tiles,
		level.level_fixtures, null, null, null, below.level_fixtures)
	match rule:
		World.FIXTURE_REFUSAL.NONE: pass
		World.FIXTURE_REFUSAL.TILE_NOT_EXISTS: return PROBLEM.OUTSIDE_LEVEL
		World.FIXTURE_REFUSAL.NEEDS_HOLE: return PROBLEM.NEEDS_HOLE
		_: return PROBLEM.HOLE_IN_USE
	if not Building.can_afford(level.world.tuning, actor, kind):
		return PROBLEM.CANNOT_AFFORD
	return PROBLEM.NONE


# Asks the actor's world to place `kind` (the selected item when none
# is given) at the cursor: a ladder below the cursor's hole, a prop on
# the cursor's floor. The world answers: a placement, or a refusal the
# notice shows. Asks nothing when the preview already says no, and says
# why.
func place(kind: int = -1) -> bool:
	if not active: return false
	if kind == -1: kind = item
	var why: PROBLEM = problem(kind)
	if why != PROBLEM.NONE:
		cursor_refused.emit(REASONS.get(why, ""))
		return false
	var world: World = actor.current_level.world
	var depth: int = actor.depth + 1 if kind == ObjectKind.OBJECT.LADDER else actor.depth
	world.place_requested.emit(actor, kind, WorldPos.new(tile.x, tile.y, depth))
	return true



# --- what it says it places ---

# Beside the cursor: what the selected slot places and what it costs,
# "Timber prop · 2 timber". "" with nothing selected.
func label_text(kind: int = -1) -> String:
	if kind == -1: kind = item
	var name: String = ObjectKind.display_name(kind)
	if name == "" or actor == null: return ""
	var cost: String = Building.cost_text(actor.current_level.world.tuning, kind)
	return name if cost == "" else "%s · %s" % [name, cost]


# The art drawn faintly in the cursor's square: the fixture's own. A
# ladder stands on the level below, so from here it shows as the top
# seen down the hole (D-107).
static func ghost_texture(kind: int) -> Texture2D:
	if kind == ObjectKind.OBJECT.LADDER: return FixtureRenderer.LADDER_TOP
	return FixtureRenderer.TEXTURES.get(kind)


# --- drawing: valid or not by shape and icon too (ui-ux §7) ---

func _process(_delta: float) -> void:
	if active: queue_redraw()


func _draw() -> void:
	if not active: return
	var size: float = TileSpace.TILE_PIXELS
	var corner: Vector2 = Vector2(tile) * size
	var valid: bool = problem() == PROBLEM.NONE
	var color: Color = VALID_COLOR if valid else INVALID_COLOR
	# Valid: a solid frame and a check; invalid: a dashed frame and a
	# cross
	# What it places, faintly, standing on the tile as the real one will
	# (its bottom edge on the tile's, D-105)
	var ghost: Texture2D = ghost_texture(item)
	if ghost != null:
		var rise: float = ghost.get_height() - size
		draw_texture(ghost, corner - Vector2(0, rise), Color(color, GHOST_ALPHA))
	# What it is and what it costs, always, beside the cursor (ui-ux §7)
	var label: String = label_text()
	if label != "":
		draw_string(ScaledHud.FONT, corner + Vector2(size + 2, size - 4), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, ScaledHud.FONT_SIZE, color)
	if valid:
		draw_rect(Rect2(corner, Vector2(size, size)), color, false, 1.0)
		draw_polyline(PackedVector2Array([corner + Vector2(4, 8), corner + Vector2(7, 11),
			corner + Vector2(12, 5)]), color, 1.0)
	else:
		for i in range(4):
			var a: Vector2 = corner + Vector2(i * 4, 0)
			draw_line(a, a + Vector2(2, 0), color)
			draw_line(a + Vector2(0, size - 1), a + Vector2(2, size - 1), color)
			var b: Vector2 = corner + Vector2(0, i * 4)
			draw_line(b, b + Vector2(0, 2), color)
			draw_line(b + Vector2(size - 1, 0), b + Vector2(size - 1, 2), color)
		draw_line(corner + Vector2(4, 4), corner + Vector2(12, 12), color)
		draw_line(corner + Vector2(12, 4), corner + Vector2(4, 12), color)
