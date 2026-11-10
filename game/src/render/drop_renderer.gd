class_name DropRenderer
extends Node2D

# Draws the items lying on the shown level (D-160): a small square per
# item on its tile, up to four to a tile. Placeholders until there's
# art. In the dark, a drop shows only on a Sensed or Lit tile, the way
# other actors do (D-161, D-148). Presentation: follows the view's
# world and depth (D-129), and redraws when drops or states change.

const COLORS: Dictionary = {
	&"stone": Color(0.62, 0.62, 0.6),
	&"copper_ore": Color(0.85, 0.48, 0.25),
	&"timber": Color(0.55, 0.38, 0.2),
}
const UNKNOWN_COLOR: Color = Color(0.9, 0.2, 0.9)
# Where each of a tile's items sits, in tile pixels
const SLOTS: Array[Vector2] = [Vector2(3, 3), Vector2(9, 3), Vector2(3, 9), Vector2(9, 9)]
const SQUARE: Vector2 = Vector2(4, 4)

var _world: World
var _drops: LevelDrops
var _tiles: LevelTiles
var _visibility: Visibility


func _init() -> void:
	name = "DropRenderer"
	z_index = 4


func watch(view: View) -> void:
	view.shown_world_changed.connect(_on_shown_world_changed)
	view.shown_depth_changed.connect(_on_shown_depth_changed)
	if view.shown_world != null:
		_on_shown_world_changed(view.shown_world, view.shown_depth)


func watch_visibility(visibility: Visibility) -> void:
	_visibility = visibility
	visibility.states_changed.connect(queue_redraw)


func _on_shown_world_changed(world: World, depth: int) -> void:
	_world = world
	_show(depth)


func _on_shown_depth_changed(_old: int, depth: int) -> void:
	_show(depth)


func _show(depth: int) -> void:
	if _drops != null and _drops.drops_changed.is_connected(_on_drops_changed):
		_drops.drops_changed.disconnect(_on_drops_changed)
	if _tiles != null and _tiles.tile_changed.is_connected(_on_tile_changed):
		_tiles.tile_changed.disconnect(_on_tile_changed)
	var level: Level = _world.level_at(depth) if is_instance_valid(_world) else null
	_drops = level.level_drops if level != null else null
	_tiles = level.level_tiles if level != null else null
	if _drops != null: _drops.drops_changed.connect(_on_drops_changed)
	if _tiles != null: _tiles.tile_changed.connect(_on_tile_changed)
	queue_redraw()


# Rubble buries drops, and clearing it brings them back (D-166).
func _on_tile_changed(_x: int, _y: int, layer: LevelTiles.LAYER, _source: LevelTiles) -> void:
	if layer == LevelTiles.LAYER.TOP: queue_redraw()


func _on_drops_changed(_tile: Vector2i) -> void:
	queue_redraw()


# Whether a tile's drops are drawn: Sensed or Lit, or always without a
# Visibility.
func shows(tile: Vector2i) -> bool:
	if _tiles != null and _tiles.get_top(tile.x, tile.y) != TileKind.TOP.OPEN: return false
	if _visibility == null: return true
	return _visibility.state_at(tile.x, tile.y) >= Visibility.STATE.SENSED


func _draw() -> void:
	if _drops == null: return
	for tile: Vector2i in _drops.tiles():
		if not shows(tile): continue
		var corner: Vector2 = Vector2(tile) * TileSpace.TILE_PIXELS
		var slot: int = 0
		for id: StringName in _drops.at(tile):
			if slot >= SLOTS.size(): break
			draw_rect(Rect2(corner + SLOTS[slot], SQUARE), COLORS.get(id, UNKNOWN_COLOR))
			draw_rect(Rect2(corner + SLOTS[slot], SQUARE), Color.BLACK, false, 1.0)
			slot += 1
