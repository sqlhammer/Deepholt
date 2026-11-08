extends Node2D
class_name Level

var _depth: int = -1
var depth: int:
	get: return _depth
var level_seed: int
var level_tiles: LevelTiles
var level_fixtures: LevelFixtures
# The items lying on this level (D-160)
var level_drops: LevelDrops = LevelDrops.new()
# The world this level belongs to, set by the world when it takes the
# level in (D-126). Null until then. A level never moves between
# worlds.
var world: World


# `world_seed` is the seed of the world the level is built for; the
# level's own seed is derived from it and the depth. `bound` is the
# level's shape: a load passes the saved one, which wins over the
# recipe's (D-112); with none, the recipe's is used.
func setup(p_depth: int, world_seed: int = 0, bound: LevelBound = null) -> void:
	set_depth(p_depth, world_seed)
	self.name = "Level%d" % depth

	if bound == null:
		bound = LevelRecipes.TABLE.get_bounds(depth)
	level_tiles = LevelTiles.new(bound)
	level_fixtures = LevelFixtures.new()


func set_depth(_d: int, world_seed: int = 0) -> void:
	_depth = clamp_depth(_d)
	_set_level_seed(world_seed)


func clamp_depth(_d: int) -> int:
	var _min: int = 0
	var _max: int = LevelRecipes.TABLE.rows.size() - 1
	return clamp(_d,_min,_max)


func _set_level_seed(world_seed: int) -> void:
	level_seed = hash("%s|%d" % [world_seed, _depth])
	Global.emit_signal("debug_event","Level Seed",str(level_seed))
