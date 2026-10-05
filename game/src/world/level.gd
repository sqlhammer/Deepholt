extends Node2D
class_name Level

var _depth: int = -1
var depth: int:
	get: return _depth
var level_seed: int
var level_tiles: LevelTiles
var anchor: Vector2i = Vector2i.ZERO


func _ready() -> void:
	add_to_group("levels")


# A level with no prefab stamped into it is entirely the default tile: solid
# minable rock on rock ground, out to its radial bounds.
func setup(p_depth: int, p_prefab: TilePrefab = null, p_anchor: Vector2i = Vector2i.ZERO) -> void:
	anchor = p_anchor
	set_depth(p_depth)
	self.name = "Level%d" % depth

	level_tiles = LevelTiles.new(World.level_bounds.rows[depth])
	if p_prefab != null:
		LevelGridLoader.stamp(level_tiles, p_prefab, p_anchor)
	
	add_to_group("levels")


func set_depth(_d: int) -> void:
	_depth = clamp_depth(_d)
	_set_level_seed()


func clamp_depth(_d: int) -> int:
	var _min: int = 0
	var _max: int = World.level_bounds.rows.size() - 1
	return clamp(_d,_min,_max)


func _set_level_seed() -> void:
	level_seed = hash("%s|%d" % [World.world_seed, _depth])
	Global.emit_signal("debug_event","Level Seed",str(level_seed))


func get_anchor_global_position() -> Vector2:
	var g_pos: Vector2 = Vector2.ZERO
	g_pos = to_global(TileSpace.tile_center(anchor))
	return g_pos


func get_spawn_global_position() -> Vector2:
	return to_global(TileSpace.tile_center(anchor))









