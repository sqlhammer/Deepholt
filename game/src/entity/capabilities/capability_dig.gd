extends Node
class_name CapabilityDig

const verb: String = "dig"

var progress: float = 0.0
var tile_hardness: float = 0.0
var current_tile: WorldPos = WorldPos.new(99,99,99)
var actor: Actor
# The tree a refusal was already asked about, so the wrong tool hears
# "needs an axe" once, not every tick (D-181).
var _refused_tree: WorldPos
# The same for a tile whose dig is refused with a reason (D-217,
# D-218). Kept apart from the progress, which a refusal resets.
var _refused_dig: WorldPos

# The dig refusals a player is told about. Facing open floor or the
# level's edge is no attempt, so it stays quiet.
const SAID_REFUSALS: Array[World.DIG_REFUSAL] = [
	World.DIG_REFUSAL.CRUSHED, World.DIG_REFUSAL.TOOL_TOO_WEAK]

# The gatekeeper is the actor's world, reached through its level
# (D-126). An actor never changes world, so it is listened to once.
func _ready() -> void:
	var world: World = actor.current_level.world
	world.tile_dug.connect(_on_tile_dug)
	world.dig_refused.connect(_on_dig_refused)
	world.tree_felled.connect(_on_tile_dug)
	world.chop_refused.connect(_on_chop_refused)
	actor.action_ended.connect(action_ended)


# One tick of digging `target_tile` with `tool`: progress at the tool's
# power for the tile's kind (D-168) until it reaches the hardness.
func dig(delta: float, tool: ToolData, target_tile: WorldPos, level: Level) -> void:
	if _target_tile_changed(target_tile):
		_reset_progress()
	
	current_tile = target_tile
	# A tree on the faced tile is felled, not dug (D-181)
	if level.world.tree_at(target_tile) != null:
		_chop(delta, tool, target_tile, level)
		return
	_refused_tree = null
	# Crushed rubble and ore too hard for the tool are refused with a
	# reason, once per tile (D-217, D-218), never silently
	var refusal: World.DIG_REFUSAL = level.world.dig_problem(target_tile, actor)
	if refusal in SAID_REFUSALS:
		_reset_progress()
		if _refused_dig == null or not _refused_dig.equals(target_tile):
			_refused_dig = target_tile
			level.world.dig_requested.emit(actor, target_tile)
		return
	_refused_dig = null
	var kind: int = _get_tile_kind(level, target_tile)
	var ore: int = level.level_tiles.get_ore(target_tile.x, target_tile.y)
	
	var is_diggable: bool = _set_tile_hardness(level.world.tuning, kind, ore)
	if not is_diggable:
		_reset_progress()
		return
	
	progress += Digging.dig_power(level.world.tuning, tool, kind) * delta
	if _is_dig_complete(): 
		level.world.dig_requested.emit(actor, target_tile)


# Felling: refused at once without an axe; otherwise work against the
# profile's tree work at the tool's power, then ask the world.
func _chop(delta: float, tool: ToolData, target: WorldPos, level: Level) -> void:
	var world: World = level.world
	if world.chop_problem(target, actor) != World.CHOP_REFUSAL.NONE:
		progress = 0.0
		if _refused_tree == null or not _refused_tree.equals(target):
			_refused_tree = target
			world.chop_requested.emit(actor, target)
		return
	tile_hardness = world.tuning.tree_work
	progress += tool.power * delta
	if _is_dig_complete():
		world.chop_requested.emit(actor, target)


func _on_chop_refused(p_actor: Actor, _tile: WorldPos, _reason: World.CHOP_REFUSAL) -> void:
	if _matches_attached_actor(p_actor): progress = 0.0


func _target_tile_changed(target_tile: WorldPos) -> bool:
	return not current_tile.equals(target_tile)


func _matches_attached_actor(p_actor: Actor) -> bool:
	return actor == p_actor


func _on_dig_refused(p_actor: Actor, _tile: WorldPos, _reason: World.DIG_REFUSAL) -> void:
	# Event not for this actor
	if not _matches_attached_actor(p_actor): return
	_reset_progress()


func _reset_progress() -> void:
	_refused_tree = null
	progress = 0.0
	tile_hardness = 0.0
	current_tile = WorldPos.new(99,99,99)


func action_ended(p_verb: String) -> void:
	if p_verb != verb: return # Event not for this capability
	_reset_progress()
	_refused_dig = null


func _on_tile_dug(p_actor: Actor, _tile: WorldPos = null) -> void:
	# Event not for this actor
	if not _matches_attached_actor(p_actor): return
	_reset_progress()


func _get_tile_kind(level: Level, tile: WorldPos) -> int:
	return level.level_tiles.get_top(tile.x, tile.y)


func _is_dig_complete() -> bool:
	if progress >= tile_hardness:
		return true
	return false


# The number is the profile of the world being dug (D-135). Ore makes
# a tile harder to dig.
func _set_tile_hardness(tuning: TuningProfile, kind: int,
		ore: int = TileKind.ORE.NONE) -> bool:
	var hardness: float = Digging.dig_hardness(tuning, kind, ore)
	if hardness >= 0.0:
		tile_hardness = hardness
		return true
	return false # failed to set hardness (not diggable)











