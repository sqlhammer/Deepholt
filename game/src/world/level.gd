extends Node2D
class_name Level

var _depth: int = -1
var depth: int:
	get: return _depth
var level_seed: int
var level_tiles: LevelTiles
var level_fixtures: LevelFixtures


func _ready() -> void:
	pass


# A new level is entirely the default tile -- solid minable rock on rock
# ground, out to its radial bounds -- with no fixtures. The level
# generator fills it from its recipe (D-084); where players spawn is a
# fixture, not a level property (D-091, D-092).
func setup(p_depth: int) -> void:
	set_depth(p_depth)
	self.name = "Level%d" % depth

	level_tiles = LevelTiles.new(World.level_recipes.get_bounds(depth))
	level_fixtures = LevelFixtures.new()


func set_depth(_d: int) -> void:
	_depth = clamp_depth(_d)
	_set_level_seed()


func clamp_depth(_d: int) -> int:
	var _min: int = 0
	var _max: int = World.level_recipes.rows.size() - 1
	return clamp(_d,_min,_max)


func _set_level_seed() -> void:
	level_seed = hash("%s|%d" % [World.world_seed, _depth])
	Global.emit_signal("debug_event","Level Seed",str(level_seed))









