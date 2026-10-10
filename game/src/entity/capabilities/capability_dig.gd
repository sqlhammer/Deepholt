extends Node
class_name CapabilityDig

const verb: String = "dig"

var progress: float = 0.0
var tile_density: float = 0.0
var current_tile: WorldPos = WorldPos.new(99,99,99)
var actor: Actor

func _ready() -> void:
	World.tile_dug.connect(_on_tile_dug)
	World.dig_refused.connect(_on_dig_refused)
	actor.action_ended.connect(action_ended)


func dig(delta: float, tool_speed: float, target_tile: WorldPos, level: Level) -> void:
	if _target_tile_changed(target_tile):
		_reset_progress()
	
	current_tile = target_tile
	var kind: int = _get_tile_kind(level, target_tile)
	var ore: int = level.level_tiles.get_ore(target_tile.x, target_tile.y)
	
	var is_diggable: bool = _set_tile_density(kind, ore)
	if not is_diggable:
		_reset_progress()
		return
	
	progress += tool_speed * delta
	if _is_dig_complete(): 
		World.dig_requested.emit(actor, target_tile)


func _target_tile_changed(target_tile: WorldPos) -> bool:
	return not current_tile.equals(target_tile)


func _matches_attached_actor(p_actor: Actor) -> bool:
	return actor == p_actor


func _on_dig_refused(p_actor: Actor, _tile: WorldPos, _reason: World.REFUSAL_REASON) -> void:
	if not _matches_attached_actor(p_actor): return # Event not for this actor
	_reset_progress()


func _reset_progress() -> void:
	progress = 0.0
	tile_density = 0.0
	current_tile = WorldPos.new(99,99,99)


func action_ended(p_verb: String) -> void:
	if p_verb != verb: return # Event not for this capability
	_reset_progress()


func _on_tile_dug(p_actor: Actor, _tile: WorldPos = null) -> void:
	if not _matches_attached_actor(p_actor): return # Event not for this actor
	_reset_progress()


func _get_tile_kind(level: Level, tile: WorldPos) -> int:
	return level.level_tiles.get_top(tile.x, tile.y)


func _is_dig_complete() -> bool:
	if progress >= tile_density:
		return true
	return false


# Ore makes a tile harder to dig (TileKind.ORE_DIG_MULTIPLIER).
func _set_tile_density(kind: int, ore: int = TileKind.ORE.NONE) -> bool:
	var density: float = TileKind.get_dig_density(kind, ore)
	if density >= 0.0:
		tile_density = density
		return true
	return false # failed to set density (not diggable)











