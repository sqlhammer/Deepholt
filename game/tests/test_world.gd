extends GutTest

# World (autoload): finding a resident level or its tiles by depth,
# and reading a depth back from its display name. Depth display
# round trips are in test_depth_mapping.gd.


func before_each() -> void:
	for depth in [0, 2]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		add_child_autofree(level)


func test_level_tiles_are_found_by_depth() -> void:
	var tiles: LevelTiles = World.get_level_tiles_from_depth(2)
	assert_not_null(tiles, "depth 2 is resident")
	if tiles:
		assert_eq(tiles, World.get_level_by_depth(2).level_tiles,
			"and they are depth 2's level's tiles")


func test_level_tiles_for_a_missing_depth_are_null() -> void:
	assert_null(World.get_level_tiles_from_depth(5),
		"no level is resident at depth 5")


func test_a_level_is_found_by_depth() -> void:
	var level: Level = World.get_level_by_depth(2)
	assert_not_null(level, "depth 2 is resident")
	if level:
		assert_eq(level.depth, 2, "and it is depth 2")


func test_a_missing_level_is_null() -> void:
	assert_null(World.get_level_by_depth(5), "no level is resident at depth 5")


func test_an_unreadable_display_name_is_not_a_depth() -> void:
	assert_eq(World.display_to_depth("Basement"), -99,
		"a name that is neither Surface nor a number gives -99")
	assert_eq(World.display_to_depth(""), -99, "and so does an empty one")


# --- dig requests (D-078) ---

# World is the only thing that changes tiles. A request is checked
# against the tile as it is now, then refused with a reason or
# accepted and announced. The levels from before_each are solid
# minable rock at depths 0 and 2.

var _digger: Actor


func _request(tile: WorldPos) -> void:
	_digger = autofree(Actor.new())
	watch_signals(World)
	World.dig_requested.emit(_digger, tile)


func _refusal_reason() -> int:
	var params: Array = get_signal_parameters(World, "dig_refused")
	return params[2] if params.size() == 3 else -1


func test_a_request_on_minable_rock_is_accepted() -> void:
	var tile: WorldPos = WorldPos.new(1, 0, 0)
	_request(tile)
	assert_signal_emitted(World, "tile_dug", "rock can be dug")
	assert_signal_not_emitted(World, "dig_refused", "and isn't refused")


func test_an_accepted_dig_names_the_actor_and_the_tile() -> void:
	var tile: WorldPos = WorldPos.new(1, 0, 0)
	_request(tile)
	var params: Array = get_signal_parameters(World, "tile_dug")
	assert_eq(params.size(), 2, "tile_dug carries (actor, tile)")
	if params.size() == 2:
		assert_eq(params[0], _digger, "the actor that asked")
		assert_true(params[1].equals(tile), "the tile it asked for")


func test_a_request_on_open_floor_is_refused() -> void:
	World.get_level_by_depth(0).level_tiles.set_top(1, 0, TileKind.TOP.OPEN)
	_request(WorldPos.new(1, 0, 0))
	assert_signal_not_emitted(World, "tile_dug", "open floor isn't dug")
	assert_eq(_refusal_reason(), World.REFUSAL_REASON.TILE_NOT_DIGGABLE,
		"refused as not diggable")


# The request is a claim from the past: the tile was rock when digging
# began. World checks the tile as it is when the request arrives.
func test_a_tile_that_changed_since_digging_began_is_refused() -> void:
	var tiles: LevelTiles = World.get_level_by_depth(0).level_tiles
	assert_true(TileKind.is_diggable(tiles.get_top(1, 0)), "rock when digging began")
	tiles.set_top(1, 0, TileKind.TOP.OPEN)
	_request(WorldPos.new(1, 0, 0))
	assert_eq(_refusal_reason(), World.REFUSAL_REASON.TILE_NOT_DIGGABLE,
		"open by the time the request arrives, so refused")


func test_a_request_at_a_depth_with_no_level_is_refused() -> void:
	_request(WorldPos.new(0, 0, 5))
	assert_signal_not_emitted(World, "tile_dug", "nothing to dig")
	assert_eq(_refusal_reason(), World.REFUSAL_REASON.LEVEL_NOT_EXISTS,
		"refused because no level is resident at depth 5")


func test_a_request_outside_the_level_is_refused() -> void:
	# (90, 1) is inside Surface's array but outside its radial bounds.
	_request(WorldPos.new(90, 1, 0))
	assert_eq(_refusal_reason(), World.REFUSAL_REASON.TILE_NOT_EXISTS,
		"outside the bounds (254) is no tile at all")


func test_a_request_past_the_array_is_refused() -> void:
	_request(WorldPos.new(91, 0, 0))
	assert_eq(_refusal_reason(), World.REFUSAL_REASON.TILE_NOT_EXISTS,
		"past the array (255) is no tile at all")


# Only 254 and 255 are reserved (D-059). Any other id is a tile, even
# one no table names; it just isn't diggable.
func test_an_unnamed_kind_is_a_tile_that_cannot_be_dug() -> void:
	World.get_level_by_depth(0).level_tiles.set_top(1, 0, 200)
	_request(WorldPos.new(1, 0, 0))
	assert_eq(_refusal_reason(), World.REFUSAL_REASON.TILE_NOT_DIGGABLE,
		"id 200 exists but isn't diggable, rather than not existing")


# --- changing the tile (D-078, D-079) ---

func _tiles_at(depth: int) -> LevelTiles:
	return World.get_level_by_depth(depth).level_tiles


func test_an_accepted_dig_opens_the_tile() -> void:
	_request(WorldPos.new(1, 0, 0))
	assert_eq(_tiles_at(0).get_top(1, 0), TileKind.TOP.OPEN,
		"the dug tile is open floor")


# Ore draws over whatever the top layer shows (D-066), so an opened
# tile left with ore would draw copper flecks on open floor. The ore
# is discarded, not given to anyone, until M1 (D-079).
func test_an_accepted_dig_clears_the_ore() -> void:
	_tiles_at(0).set_ore(1, 0, TileKind.ORE.COPPER)
	_request(WorldPos.new(1, 0, 0))
	assert_eq(_tiles_at(0).get_ore(1, 0), TileKind.ORE.NONE,
		"the ore goes with the rock")


# Digging removes what sat on the ground, not the ground itself.
func test_an_accepted_dig_leaves_the_ground() -> void:
	var before: int = _tiles_at(0).get_ground(1, 0)
	_request(WorldPos.new(1, 0, 0))
	assert_eq(_tiles_at(0).get_ground(1, 0), before, "the ground is untouched")


func test_only_the_requested_tile_changes() -> void:
	_request(WorldPos.new(1, 0, 0))
	for neighbor: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, -1), Vector2i(1, 1)]:
		assert_eq(_tiles_at(0).get_top(neighbor.x, neighbor.y), TileKind.TOP.MINABLE_ROCK,
			"%s is still rock" % neighbor)


# Check, then change, then announce: anything hearing tile_dug must
# find the tile already open.
func test_the_tile_is_already_open_when_tile_dug_fires() -> void:
	var seen: Array = []
	var listener: Callable = func(_a: Actor, t: WorldPos) -> void:
		seen.append(_tiles_at(t.depth).get_top(t.x, t.y))
	World.tile_dug.connect(listener)
	_request(WorldPos.new(1, 0, 0))
	World.tile_dug.disconnect(listener)
	assert_eq(seen, [TileKind.TOP.OPEN], "listeners see the change, not the old rock")


# The level comes from the tile's own depth, not the level on screen.
func test_a_dig_changes_the_level_at_the_tiles_depth() -> void:
	_request(WorldPos.new(1, 0, 2))
	assert_eq(_tiles_at(2).get_top(1, 0), TileKind.TOP.OPEN, "depth 2's tile opens")
	assert_eq(_tiles_at(0).get_top(1, 0), TileKind.TOP.MINABLE_ROCK,
		"the same coordinate on depth 0 doesn't")


func test_a_refused_dig_changes_nothing() -> void:
	_tiles_at(0).set_top(1, 0, 200)
	_tiles_at(0).set_ore(1, 0, TileKind.ORE.COPPER)
	_request(WorldPos.new(1, 0, 0))
	assert_signal_emitted(World, "dig_refused", "200 isn't diggable")
	assert_eq(_tiles_at(0).get_top(1, 0), 200, "its top is unchanged")
	assert_eq(_tiles_at(0).get_ore(1, 0), TileKind.ORE.COPPER, "and so is its ore")


# --- what a dig announces from the tile data (D-065) ---

func test_digging_copper_announces_the_top_and_the_ore() -> void:
	_tiles_at(0).set_ore(1, 0, TileKind.ORE.COPPER)
	watch_signals(_tiles_at(0))
	_request(WorldPos.new(1, 0, 0))
	assert_signal_emit_count(_tiles_at(0), "tile_changed", 2,
		"the rock opens and the copper goes: two changes")


func test_digging_plain_rock_announces_only_the_top() -> void:
	watch_signals(_tiles_at(0))
	_request(WorldPos.new(1, 0, 0))
	assert_signal_emit_count(_tiles_at(0), "tile_changed", 1,
		"there was no ore to clear, so only the top changed")
	assert_eq(get_signal_parameters(_tiles_at(0), "tile_changed"),
		[1, 0, LevelTiles.LAYER.TOP, _tiles_at(0)], "and it names the top layer")


func test_a_refused_dig_announces_nothing() -> void:
	_tiles_at(0).set_top(1, 0, TileKind.TOP.OPEN)
	watch_signals(_tiles_at(0))
	_request(WorldPos.new(1, 0, 0))
	assert_signal_not_emitted(_tiles_at(0), "tile_changed", "nothing changed, so nothing is said")


# Every request ends in exactly one answer. If the level vanished
# between the check and the change, the dig is refused rather than
# left unanswered (which would leave the digger asking every tick).
func test_a_dig_whose_level_is_gone_is_refused() -> void:
	var actor: Actor = autofree(Actor.new())
	watch_signals(World)
	World._dig_tile(actor, WorldPos.new(1, 0, 5))
	assert_push_error("Cannot complete the dig.", "it is logged")
	assert_signal_emitted(World, "dig_refused", "and the digger hears no")
	assert_signal_not_emitted(World, "tile_dug", "and nothing is dug")
