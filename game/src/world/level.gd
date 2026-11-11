extends Node2D
class_name Level

# A fixture was added to or removed from this level's store, or was
# re-filed under another tile of it (D-138). Forwarded from whichever
# store the level holds, so a listener needn't follow a store that is
# swapped in by a load.
signal fixtures_changed(fixture: Fixture, added: bool)
signal fixtures_moved(fixture: Fixture, from: WorldPos)
# The level's store was replaced whole, by a load.
signal fixtures_replaced

var _depth: int = -1
var depth: int:
	get: return _depth
var level_seed: int
var level_tiles: LevelTiles
var _level_fixtures: LevelFixtures
var level_fixtures: LevelFixtures:
	get: return _level_fixtures
	set(value): _set_level_fixtures(value)
# The items lying on this level (D-160)
var level_drops: LevelDrops = LevelDrops.new()
# Its tagged regions (D-218): where it is CRUSHED, for now
var level_regions: LevelRegions = LevelRegions.new()
# Whether this level's excavations are held up (D-163): derived from
# the tiles and fixtures, with the countdowns it saves. Built when the
# world takes the level in, since its numbers are the world's.
var support: LevelSupport
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


# Takes a store in, listening to it in place of the one before, and
# works out which tiles its fixtures keep walkers off (D-165).
func _set_level_fixtures(value: LevelFixtures) -> void:
	if _level_fixtures != null and _level_fixtures.fixture_changed.is_connected(_on_fixture_changed):
		_level_fixtures.fixture_changed.disconnect(_on_fixture_changed)
		_level_fixtures.fixture_moved.disconnect(_on_fixture_moved)
	var replaced: bool = _level_fixtures != null
	_level_fixtures = value
	if _level_fixtures == null: return
	_level_fixtures.fixture_changed.connect(_on_fixture_changed)
	_level_fixtures.fixture_moved.connect(_on_fixture_moved)
	if level_tiles != null:
		level_tiles.clear_blocked()
		for fixture: Fixture in _level_fixtures.all():
			if ObjectKind.blocks_walking(fixture.kind):
				level_tiles.block(Vector2i(fixture.tile.x, fixture.tile.y))
	if replaced: fixtures_replaced.emit()


func _on_fixture_changed(fixture: Fixture, added: bool) -> void:
	if ObjectKind.blocks_walking(fixture.kind):
		var tile: Vector2i = Vector2i(fixture.tile.x, fixture.tile.y)
		if added: level_tiles.block(tile)
		else: level_tiles.unblock(tile)
	fixtures_changed.emit(fixture, added)


func _on_fixture_moved(fixture: Fixture, from: WorldPos) -> void:
	if ObjectKind.blocks_walking(fixture.kind):
		level_tiles.unblock(Vector2i(from.x, from.y))
		level_tiles.block(Vector2i(fixture.tile.x, fixture.tile.y))
	fixtures_moved.emit(fixture, from)
