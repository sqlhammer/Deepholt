extends Node
class_name CapabilityDig

const verb: String = "dig"

var progress: float = 0.0
var tile_density: float = 0.0

func _ready() -> void:
	pass


func dig(delta: float, tool_speed: float, target_tile: WorldPos, level: Level) -> void:
	var ore_kind: int = _get_tile_kind(level, target_tile)
	if not _is_diggable(ore_kind): return
	
	_set_tile_density(ore_kind)
	progress += tool_speed * delta
	
	if _is_dig_complete(): 
		World.emit_signal("ore_mined", target_tile)
		progress = 0.0


func _get_tile_kind(level: Level, tile: WorldPos) -> int:
	return level.level_tiles.get_top(tile.x, tile.y)


func _is_diggable(kind: int) -> bool:
	match kind:
		TileKind.TOP.MINABLE_ROCK: return true
		TileKind.TOP.MINABLE_DIRT: return true
	
	return false


func _is_dig_complete() -> bool:
	if progress >= tile_density:
		return true
	return false


func _set_tile_density(kind: int) -> void:
	for key in TileKind.MINABLE_DENSITY:
		if kind == TileKind.MINABLE_DENSITY[key].id:
			tile_density = TileKind.MINABLE_DENSITY[key].density
			break











