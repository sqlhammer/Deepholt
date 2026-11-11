extends GutTest

# The map (ui-ux §6, D-226, D-227) and the depth strip: one level at a
# time over its neighbors, anchors on every level they pass through,
# only what's remembered, every player a dot; View or M, and LB / RB,
# the wheel or Page Up / Down for the level. The strip says which
# level you're on and how many lie below.

const Worlds = preload("res://tests/worlds.gd")
const HOLE: Vector2i = Vector2i(4, 0)

var _world: World
var _actor: Actor
var _view: View
var _map: MapOverlay


# Levels 0 to 3 of rock. On -1 a corridor along y = 0 with a hole at
# HOLE; on -2 its landing and a ladder up it. The player on -1.
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2, 3]))
	var minus_one: LevelTiles = _world.level_at(1).level_tiles
	for x in range(0, 8):
		minus_one.set_top(x, 0, TileKind.TOP.OPEN)
	minus_one.set_ground(HOLE.x, HOLE.y, TileKind.GROUND.HOLE)
	_world.level_at(2).level_tiles.set_top(HOLE.x, HOLE.y, TileKind.TOP.OPEN)
	_world.level_at(2).level_fixtures.add(Fixture.new(ObjectKind.OBJECT.LADDER,
		WorldPos.new(HOLE.x, HOLE.y, 2), _world.fixture_ids.allocate()))
	_actor = Actor.create(Global.actor_packed_scene, "Mapper", WorldPos.new(0, 0, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)
	_view = add_child_autofree(View.new())
	_view.follow(_actor)
	_map = add_child_autofree(MapOverlay.new())
	_map.watch(_view)


func _remember(depth: int, tiles: Array[Vector2i]) -> void:
	_world.level_at(depth).level_tiles.remember(tiles)


func _kinds_at(depth: int, tile: Vector2i) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for anchor: Dictionary in MapOverlay.anchors(_world, depth):
		if anchor.tile == tile: kinds.append(anchor.kind)
	return kinds


# --- anchors ---

func test_a_shaft_shows_on_both_levels_it_passes_through() -> void:
	_remember(1, [HOLE])
	_remember(2, [HOLE])
	assert_eq(_kinds_at(1, HOLE), [&"hole", &"ladder"] as Array[StringName], "on -1: the hole, the ladder up it")
	assert_eq(_kinds_at(2, HOLE), [&"hole", &"ladder"] as Array[StringName], "on -2: the same")
	assert_eq(_kinds_at(0, HOLE), [] as Array[StringName], "not two levels away")


func test_an_anchor_nobody_has_seen_isnt_drawn() -> void:
	var minus_three: LevelTiles = _world.level_at(3).level_tiles
	minus_three.set_top(9, 9, TileKind.TOP.OPEN)
	minus_three.set_ground(9, 9, TileKind.GROUND.HOLE)
	assert_eq(MapOverlay.anchors(_world, 3), [] as Array[Dictionary], "nobody's seen it: not shown")


func test_chutes_winches_and_ramps_are_anchors() -> void:
	var minus_one: Level = _world.level_at(1)
	minus_one.level_fixtures.add(Fixture.new(ObjectKind.OBJECT.CHUTE, WorldPos.new(HOLE.x, HOLE.y, 1),
		_world.fixture_ids.allocate()))
	minus_one.level_tiles.set_ground(6, 0, TileKind.GROUND.RAMP_DOWN_E)
	_remember(1, [HOLE, Vector2i(6, 0)])
	assert_true(_kinds_at(2, HOLE).has(&"chute"), "the chute shows on the level it feeds")
	assert_true(_kinds_at(2, Vector2i(6, 0)).has(&"ramp"), "and the ramp down on the level it reaches")
	assert_eq(MapOverlay.ANCHOR_COLORS.size(), 5, "each kind has its color")


# --- only what's remembered (trap 6) ---

func test_the_picture_shows_only_remembered_tiles() -> void:
	var tiles: LevelTiles = _world.level_at(1).level_tiles
	_remember(1, [Vector2i(0, 0), Vector2i(0, 1)])
	tiles.set_ore(0, 1, TileKind.ORE.COPPER)
	tiles.set_top(3, 5, TileKind.TOP.OPEN)
	var image: Image = MapOverlay.picture(tiles)
	var radius: int = tiles.level_bound.radius
	# Compared as bytes: the picture stores 8 bits a channel
	assert_eq(image.get_pixel(radius, radius).to_rgba32(), MapOverlay.FLOOR.to_rgba32(),
		"remembered floor")
	assert_eq(image.get_pixel(radius, radius + 1).to_rgba32(), MapOverlay.SOLID.to_rgba32(),
		"a remembered face: solid, no ore")
	assert_eq(image.get_pixel(radius + 3, radius + 5).a, 0.0, "open, but never seen: nothing")


func test_a_crushed_region_shows_only_its_face() -> void:
	var tiles: LevelTiles = _world.level_at(1).level_tiles
	tiles.set_top(0, 1, TileKind.TOP.CRUSHED)
	tiles.set_top(0, 2, TileKind.TOP.CRUSHED)
	_remember(1, [Vector2i(0, 1)])
	assert_eq(MapOverlay.tile_color(tiles, 0, 1), MapOverlay.RUBBLE, "the face seen")
	assert_eq(MapOverlay.tile_color(tiles, 0, 2).a, 0.0, "its insides never")


# --- players ---

func test_every_player_is_a_dot_and_the_viewers_is_marked() -> void:
	var other: Actor = Actor.create(Global.actor_packed_scene, "Other", WorldPos.new(2, 0, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(other)
	var found: Array[Dictionary] = MapOverlay.dots(_world, 1, _actor)
	assert_eq(found.size(), 2, "both players")
	assert_true(found[0].viewer, "the viewer marked")
	assert_false(found[1].viewer, "the other not")
	assert_eq(MapOverlay.dots(_world, 2, _actor).size(), 0, "nobody on -2")


# --- opening it, its levels, its keys ---

func test_it_opens_on_the_viewers_level_and_steps_between_levels() -> void:
	_map.set_open(true)
	assert_true(_map.is_open, "open")
	assert_eq(_map.shown_depth, 1, "on the viewer's level")
	_map.step_level(1)
	assert_eq(_map.shown_depth, 2, "one down")
	_map.step_level(-1)
	_map.step_level(-1)
	_map.step_level(-1)
	assert_eq(_map.shown_depth, 0, "never past the Surface")
	_map.toggle()
	assert_false(_map.is_open, "closed")


func test_the_keys_named_are_the_scheme_in_uses_only() -> void:
	_map.set_open(true)
	_map.set_gamepad(true)
	assert_string_contains(_map.keys_text(), "LB/RB")
	assert_false(_map.keys_text().contains("PgUp"), "no keyboard keys on a pad (D-223)")
	_map.set_gamepad(false)
	assert_string_contains(_map.keys_text(), "M: close")
	assert_false(_map.keys_text().contains("LB"), "no pad buttons on a keyboard")


func test_with_the_map_open_the_bumpers_change_its_level_not_the_hotbar() -> void:
	var input: InputHandler = add_child_autofree(InputHandler.new())
	input.setup(_actor, func() -> Vector2: return Vector2.ZERO)
	input.map = _map
	_map.set_open(true)
	var next: InputEventAction = InputEventAction.new()
	next.action = &"hotbar_next"
	next.pressed = true
	var slot: int = _actor.hotbar.selected_tool
	input._hotbar_input(next)
	assert_eq(_map.shown_depth, 2, "the map stepped down")
	assert_eq(_actor.hotbar.selected_tool, slot, "the hotbar didn't move")


func test_the_map_is_on_view_and_m_and_quick_save_left_the_pad() -> void:
	var has_pad: Callable = func(action: StringName, button: int) -> bool:
		return InputMap.action_get_events(action).any(func(event: InputEvent) -> bool:
			return event is InputEventJoypadButton and event.button_index == button)
	assert_true(has_pad.call(&"open_map", JOY_BUTTON_BACK), "View opens the map")
	assert_false(InputMap.action_get_events(&"quick_save").any(func(event: InputEvent) -> bool:
		return event is InputEventJoypadButton), "quick save is keyboard only now")
	assert_true(InputMap.action_get_events(&"open_map").any(func(event: InputEvent) -> bool:
		return event is InputEventKey and event.physical_keycode == KEY_M), "M opens it")


# --- the depth strip ---

func test_the_strip_says_where_you_are_and_how_many_lie_below() -> void:
	var strip: DepthStrip = add_child_autofree(DepthStrip.new())
	strip.watch(_view)
	assert_eq(strip.here(), 1, "on -1")
	assert_eq(strip.below(), DepthStrip.depths() - 2, "the rest below")
	_actor.move_to(WorldPos.new(HOLE.x, HOLE.y, 2), &"test")
	assert_eq(strip.here(), 2, "it follows the player down")
