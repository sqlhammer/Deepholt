class_name Visibility
extends Node

# What the screen can show of the shown level, one state per tile
# (D-033, D-146): Unknown, Remembered, Sensed or Lit. Presentation:
# Sensed is the followed actor's (D-145), which only presentation may
# know (D-045). Built here once per change and read by everything that
# draws: the level renderer's state texture, the fixture renderer's
# dimming and the view's actor visibility (D-148).
#
# The rule: Lit if the tile is lit, else Sensed if the followed actor
# senses it, else Remembered if memory says so, else Unknown. The
# Surface is lit throughout (D-144).

# Fixed values: they're the bytes the shader reads.
enum STATE {
	UNKNOWN = 0,
	REMEMBERED = 1,
	SENSED = 2,
	LIT = 3,
}

# The state bytes changed: a new level, the followed actor moved, new
# memory, or light changed.
signal states_changed

# The state bytes of the shown level, row-major like its layers, so
# texel (column, row) is tile (column - radius, row - radius). Empty
# until a level is shown.
var state_bytes: PackedByteArray = []
# How long the last rebuild took, in ms, for F3. Rebuilt every tile
# step, so it has to stay small (slice 006 trap 5).
var last_build_msec: float = -1.0

var _view: View
var _world: World
var _level: Level
# The level's lit tiles, kept between rebuilds: light changes only
# when the level or its fixtures do, not every step.
var _lit: Array[Vector2i] = []


func watch(view: View) -> void:
	_view = view
	view.shown_world_changed.connect(_on_shown_world_changed)
	view.shown_depth_changed.connect(_on_shown_depth_changed)
	view.followed_moved.connect(_on_followed_moved)
	if view.shown_world != null:
		_on_shown_world_changed(view.shown_world, view.shown_depth)


# The tiles being described, or null before a level is shown.
func shown_tiles() -> LevelTiles:
	return _level.level_tiles if is_instance_valid(_level) else null


# The state of one tile of the shown level; Unknown outside it.
func state_at(x: int, y: int) -> STATE:
	var tiles: LevelTiles = shown_tiles()
	if tiles == null or state_bytes.is_empty(): return STATE.UNKNOWN
	var radius: int = tiles.level_bound.radius
	if absi(x) > radius or absi(y) > radius: return STATE.UNKNOWN
	return state_bytes[tiles.get_index(x, y)] as STATE


func _on_shown_world_changed(world: World, depth: int) -> void:
	_world = world
	_show(depth)


func _on_shown_depth_changed(_old_depth: int, new_depth: int) -> void:
	_show(new_depth)


func _on_followed_moved(_actor: Actor) -> void:
	rebuild()


# Re-points to the level at `depth`, and listens to what changes its
# states: its memory, its tiles (a dig opens space for light and the
# senses) and its fixtures (a light placed, moved or removed).
func _show(depth: int) -> void:
	var level: Level = _world.level_at(depth) if is_instance_valid(_world) else null
	if is_instance_valid(_level) and level == _level:
		rebuild()
		return
	_stop_listening()
	_level = level
	if is_instance_valid(_level):
		_level.level_tiles.memory_changed.connect(_on_memory_changed)
		_level.level_tiles.tile_changed.connect(_on_tile_changed)
		_level.level_tiles.tiles_replaced.connect(_on_tiles_replaced)
		_level.level_fixtures.fixture_changed.connect(_on_fixture_changed)
		_level.level_fixtures.fixture_moved.connect(_on_fixture_moved)
	_relight()


func _stop_listening() -> void:
	if not is_instance_valid(_level): return
	var tiles: LevelTiles = _level.level_tiles
	if tiles.memory_changed.is_connected(_on_memory_changed):
		tiles.memory_changed.disconnect(_on_memory_changed)
		tiles.tile_changed.disconnect(_on_tile_changed)
		tiles.tiles_replaced.disconnect(_on_tiles_replaced)
	var fixtures: LevelFixtures = _level.level_fixtures
	if fixtures.fixture_changed.is_connected(_on_fixture_changed):
		fixtures.fixture_changed.disconnect(_on_fixture_changed)
		fixtures.fixture_moved.disconnect(_on_fixture_moved)


func _on_memory_changed(_tiles: LevelTiles) -> void:
	rebuild()


func _on_tile_changed(_x: int, _y: int, _layer: LevelTiles.LAYER, _tiles: LevelTiles) -> void:
	_relight()


func _on_tiles_replaced(_tiles: LevelTiles) -> void:
	_relight()


func _on_fixture_changed(fixture: Fixture, _added: bool) -> void:
	if Light.radius_of(fixture.kind, _world.tuning) >= 0: _relight()


func _on_fixture_moved(fixture: Fixture, _from: WorldPos) -> void:
	if Light.radius_of(fixture.kind, _world.tuning) >= 0: _relight()


func _relight() -> void:
	_lit = []
	if is_instance_valid(_level) and not Light.is_daylit(_level):
		_lit = Light.lit_tiles(_level, _world.tuning)
	rebuild()


# Rebuilds the state bytes and announces them. Copies the memory layer
# (native, fast) and overwrites only what's sensed and lit, so the
# cost follows the ring and the light, not the level's size.
func rebuild() -> void:
	var started: int = Time.get_ticks_usec()
	if not is_instance_valid(_level):
		state_bytes = []
	else:
		state_bytes = build(_level, _sensed(), _lit)
	last_build_msec = (Time.get_ticks_usec() - started) / 1000.0
	states_changed.emit()


# The followed actor's sensed tiles, if it stands on the shown level.
# During a level change's fade it's already on the next one (D-142),
# so the level being faded out shows only what's remembered.
func _sensed() -> Array[Vector2i]:
	if _view == null: return []
	var followed: Actor = _view.actor
	if not is_instance_valid(followed) or followed.current_level != _level: return []
	var here: WorldPos = followed.current_WorldPos
	return Senses.flood(_level.level_tiles, Vector2i(here.x, here.y), _world.tuning.sense_radius)


# The rule, stateless, so a test can hand it any level, ring and
# light. Memory's bit 0 is REMEMBERED (D-147) and STATE.REMEMBERED is
# 1, so a copy of the memory layer with only that bit is already
# Unknown and Remembered everywhere. The tiles keep that copy, since
# memory's other bits (EXCAVATED, D-164) would read as Sensed or Lit.
static func build(level: Level, sensed: Array[Vector2i], lit: Array[Vector2i]) -> PackedByteArray:
	var tiles: LevelTiles = level.level_tiles
	var bytes: PackedByteArray = tiles.remembered_only.duplicate()
	if Light.is_daylit(level):
		bytes.fill(STATE.LIT)
		return bytes
	_overwrite(bytes, tiles, sensed, STATE.SENSED)
	_overwrite(bytes, tiles, lit, STATE.LIT)
	return bytes


static func _overwrite(bytes: PackedByteArray, tiles: LevelTiles,
		at: Array[Vector2i], state: STATE) -> void:
	var radius: int = tiles.level_bound.radius
	for tile: Vector2i in at:
		if absi(tile.x) > radius or absi(tile.y) > radius: continue
		bytes[tiles.get_index(tile.x, tile.y)] = state
