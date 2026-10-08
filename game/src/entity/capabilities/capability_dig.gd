extends Node
class_name CapabilityDig

const verb: String = "dig"

var progress: float = 0.0
var tile_density: float = 0.0
var current_tile: WorldPos = WorldPos.new(99,99,99)
var actor: Actor

func _ready() -> void:
	World.connect("tile_dug",complete_tile_dig)
	actor.connect("action_ended",action_ended)


func dig(delta: float, tool_speed: float, target_tile: WorldPos, level: Level) -> void:
	if _target_tile_changed(target_tile):
		_reset_progress()
	
	current_tile = target_tile
	var kind: int = _get_tile_kind(level, target_tile)
	if not _is_diggable(kind): return
	
	var is_minable: bool = _set_tile_density(kind)
	if not is_minable:
		return
	
	progress += tool_speed * delta
	if _is_dig_complete(): 
		World.emit_signal("tile_dug", actor, target_tile)


func _target_tile_changed(target_tile: WorldPos) -> bool:
	return not current_tile.equals(target_tile)


func _reset_progress() -> void:
	progress = 0.0
	current_tile = WorldPos.new(99,99,99)


func action_ended(p_verb: String) -> void:
	if p_verb != verb: return # Event not for this capability
	_reset_progress()


func complete_tile_dig(p_actor: Actor, _tile: WorldPos = null) -> void:
	if not actor == p_actor: return # Event not for this actor
	_reset_progress()


func _get_tile_kind(level: Level, tile: WorldPos) -> int:
	return level.level_tiles.get_top(tile.x, tile.y)


func _is_diggable(kind: int) -> bool:
	match kind:
		TileKind.TOP.MINABLE_ROCK: return true
		TileKind.TOP.MINABLE_DIRT: return true
	
	# Reset if not minable
	tile_density = 0.0
	progress = 0.0
	return false


func _is_dig_complete() -> bool:
	if progress >= tile_density:
		return true
	return false


func _set_tile_density(kind: int) -> bool:
	for key in TileKind.MINABLE_DENSITY:
		if kind == TileKind.MINABLE_DENSITY[key].id:
			tile_density = TileKind.MINABLE_DENSITY[key].density
			return true
	return false # not minable











