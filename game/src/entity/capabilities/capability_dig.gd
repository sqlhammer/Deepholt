extends Node
class_name CapabilityDig

const verb: String = "dig"

var progress: float = 0.0
var tile_hardness: float = 0.0
var current_tile: WorldPos = WorldPos.new(99,99,99)
var actor: Actor

# The gatekeeper is the actor's world, reached through its level
# (D-126). An actor never changes world, so it is listened to once.
func _ready() -> void:
	var world: World = actor.current_level.world
	world.tile_dug.connect(_on_tile_dug)
	world.dig_refused.connect(_on_dig_refused)
	actor.action_ended.connect(action_ended)


func dig(delta: float, tool_speed: float, target_tile: WorldPos, level: Level) -> void:
	if _target_tile_changed(target_tile):
		_reset_progress()
	
	current_tile = target_tile
	var kind: int = _get_tile_kind(level, target_tile)
	var ore: int = level.level_tiles.get_ore(target_tile.x, target_tile.y)
	
	var is_diggable: bool = _set_tile_hardness(level.world.tuning, kind, ore)
	if not is_diggable:
		_reset_progress()
		return
	
	progress += tool_speed * delta
	if _is_dig_complete(): 
		level.world.dig_requested.emit(actor, target_tile)


func _target_tile_changed(target_tile: WorldPos) -> bool:
	return not current_tile.equals(target_tile)


func _matches_attached_actor(p_actor: Actor) -> bool:
	return actor == p_actor


func _on_dig_refused(p_actor: Actor, _tile: WorldPos, _reason: World.DIG_REFUSAL) -> void:
	# Event not for this actor
	if not _matches_attached_actor(p_actor): return
	_reset_progress()


func _reset_progress() -> void:
	progress = 0.0
	tile_hardness = 0.0
	current_tile = WorldPos.new(99,99,99)


func action_ended(p_verb: String) -> void:
	if p_verb != verb: return # Event not for this capability
	_reset_progress()


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
	var hardness: float = tuning.dig_hardness(kind, ore)
	if hardness >= 0.0:
		tile_hardness = hardness
		return true
	return false # failed to set hardness (not diggable)











