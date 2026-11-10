extends GutTest

# Build mode and placing a ladder (D-154): the anchored cursor,
# clamped to a radius around the player with the same reach for mouse
# and stick; a preview from the fixture gatekeeper's own rules, Sensed
# or Lit tiles only; and a ladder placed below a hole, through the
# world.

const Worlds = preload("res://tests/worlds.gd")
const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/build_mode"
const SLOT: String = SAVES_ROOT + "/slot-001"
const HOLE: Vector2i = Vector2i(2, 0)

var _world: World
var _actor: Actor
var _view: View
var _vis: Visibility
var _cursor: BuildCursor


# Blank levels with open floor along y = 0 on -1 and -2; a breach at
# HOLE makes the hole on -1 and clears the landing on -2. The player
# stands on -1 at the origin, followed, so the hole is Sensed.
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2]))
	for depth in [1, 2]:
		for x in range(-12, 13):
			_world.level_at(depth).level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	_world.breach_requested.emit(null, WorldPos.new(HOLE.x, HOLE.y, 1), 999.0)
	_actor = Actor.create(Global.actor_packed_scene, "Builder", WorldPos.new(0, 0, 1),
		_world.level_at(1), ActorKind.ACTOR.PLAYER)
	_world.add_actor(_actor)
	# Ladders cost timber (D-156); enough for every test's placements
	_actor.pack.add(&"timber", 40)
	_view = add_child_autofree(View.new())
	_vis = add_child_autofree(Visibility.new())
	_vis.watch(_view)
	_view.follow(_actor)
	_cursor = add_child_autofree(BuildCursor.new())
	_cursor.visibility = _vis
	_cursor.actor = _actor
	_cursor.set_active(true)
	watch_signals(_world)


func after_each() -> void:
	SaveDirs.remove_tree(SAVES_ROOT)


# --- the cursor (ui-ux §2.1) ---

func test_it_starts_on_the_player() -> void:
	assert_eq(_cursor.tile, Vector2i.ZERO, "under the player")


func test_it_is_clamped_to_the_radius() -> void:
	_cursor.set_tile(Vector2i(40, 0))
	assert_eq(_cursor.tile, Vector2i(_world.tuning.build_cursor_radius, 0), "pulled back in")
	_cursor.set_tile(Vector2i(30, 30))
	assert_lte(Vector2(_cursor.tile).length(), float(_world.tuning.build_cursor_radius) + 0.5,
		"a disc, not a square")


# Parity: the mouse gets no reach the stick doesn't.
func test_mouse_and_stick_reach_the_same_tile() -> void:
	_cursor.point_at(Vector2(1000, 8))
	var by_mouse: Vector2i = _cursor.tile
	_cursor.set_tile(Vector2i.ZERO)
	for i in range(20):
		_cursor.step(Vector2.RIGHT, BuildCursor.STICK_REPEAT_SECONDS)
	assert_eq(_cursor.tile, by_mouse, "both stop at the edge of reach")


func test_the_stick_steps_one_tile_and_waits() -> void:
	_cursor.step(Vector2.RIGHT, 0.01)
	_cursor.step(Vector2.RIGHT, 0.01)
	assert_eq(_cursor.tile, Vector2i(1, 0), "one step, then the repeat wait")
	_cursor.step(Vector2.ZERO, 0.01)
	_cursor.step(Vector2.RIGHT, 0.01)
	assert_eq(_cursor.tile, Vector2i(2, 0), "a fresh push steps at once")


# --- the preview, from the gatekeeper's rules ---

func test_a_sensed_hole_with_a_clear_landing_is_valid() -> void:
	_cursor.set_tile(HOLE)
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.NONE, "valid")


func test_floor_is_not_a_hole() -> void:
	_cursor.set_tile(Vector2i(1, 0))
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.NOT_A_HOLE, "floor")


func test_a_hole_over_rock_has_no_landing() -> void:
	_world.level_at(1).level_tiles.set_ground(-2, 0, TileKind.GROUND.HOLE)
	_world.level_at(2).level_tiles.set_top(-2, 0, TileKind.TOP.MINABLE_ROCK)
	_cursor.set_tile(Vector2i(-2, 0))
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.LANDING_NOT_PASSABLE, "rock below")


# D-154: nobody builds blind.
func test_a_hole_out_of_sight_is_too_dark() -> void:
	_world.level_at(1).level_tiles.set_ground(0, 4, TileKind.GROUND.HOLE)
	_cursor.set_tile(Vector2i(0, 4))
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.TOO_DARK, "behind rock, unsensed")


func test_the_preview_agrees_with_the_gatekeeper() -> void:
	for x in range(-5, 6):
		_cursor.set_tile(Vector2i(x, 0))
		var valid: bool = _cursor.problem() == BuildCursor.PROBLEM.NONE
		var rule: World.FIXTURE_REFUSAL = FixturePlacement.problem(ObjectKind.OBJECT.LADDER,
			Vector2i(x, 0), _world.level_at(2).level_tiles, _world.level_at(2).level_fixtures,
			_world.level_at(1).level_tiles)
		assert_eq(valid, rule == World.FIXTURE_REFUSAL.NONE, "x = %d" % x)


# --- placing (D-154) ---

func _place_at_hole() -> Fixture:
	_cursor.set_tile(HOLE)
	assert_true(_cursor.place(), "asked")
	var ladders: Array[Fixture] = _world.level_at(2).level_fixtures.of_kind(ObjectKind.OBJECT.LADDER)
	return ladders[0] if ladders.size() == 1 else null


func test_placing_puts_a_ladder_below_the_hole() -> void:
	var ladder: Fixture = _place_at_hole()
	assert_not_null(ladder, "a ladder on -2")
	if ladder: assert_true(ladder.tile.equals(WorldPos.new(HOLE.x, HOLE.y, 2)), "under the hole")
	assert_signal_emitted(_world, "fixture_placed", "through the gatekeeper")


func test_it_takes_the_worlds_next_fixture_id() -> void:
	var next: int = _world.fixture_ids.peek()
	var ladder: Fixture = _place_at_hole()
	assert_eq(ladder.id, next, "the world's next id")
	assert_eq(_world.fixture_ids.peek(), next + 1, "and the counter moved on")


func test_a_refused_preview_asks_nothing_and_says_why() -> void:
	watch_signals(_cursor)
	_cursor.set_tile(Vector2i(1, 0))
	assert_false(_cursor.place(), "not asked")
	assert_signal_not_emitted(_world, "place_requested")
	assert_signal_emitted_with_parameters(_cursor, "cursor_refused", ["A ladder goes in a hole."])


func test_a_placed_ladder_climbs_both_ways() -> void:
	_place_at_hole()
	_actor.move_to(WorldPos.new(HOLE.x - 1, 0, 1))
	_actor.facing = Vector2i(1, 0)
	assert_true(_actor.interact(), "down")
	assert_eq(_actor.depth, 2, "on -2")
	assert_true(_actor.interact(), "and back up")
	assert_eq(_actor.depth, 1, "on -1")


func test_both_levels_draw_it() -> void:
	var renderer: FixtureRenderer = add_child_autofree(FixtureRenderer.new())
	renderer.watch(_view)
	var ladder: Fixture = _place_at_hole()
	assert_not_null(renderer.top_sprite_for(ladder.id), "its top in the hole on -1")
	_view.show_world(_world, 2)
	assert_not_null(renderer.sprite_for(ladder.id), "itself on -2")


func test_a_placed_ladder_survives_a_save_and_ids_carry_on() -> void:
	var ladder: Fixture = _place_at_hole()
	DirAccess.make_dir_recursive_absolute(SLOT)
	assert_eq(SaveGame.save_game(SLOT, _world, SaveSession.new(_actor.actor_id), SAVES_ROOT),
		SaveGame.REFUSAL_REASON.NONE, "saved")
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(SLOT)
	if loaded == null:
		fail_test("refused")
		return
	var back: Fixture = loaded.world.level_at(2).level_fixtures.find(ladder.id)
	assert_not_null(back, "the ladder came back")
	assert_eq(loaded.world.level_at(1).level_tiles.get_ground(HOLE.x, HOLE.y),
		TileKind.GROUND.HOLE, "and its hole")
	assert_gt(loaded.world.fixture_ids.peek(), ladder.id, "the next id is past it")
	loaded.free_world()


# P5: an NPC's request is answered the same way, and another world is
# untouched.
func test_an_npc_places_and_a_second_world_is_untouched() -> void:
	var other: World = add_child_autofree(Worlds.with_levels([0, 1, 2]))
	var npc: Actor = Actor.create(Global.actor_packed_scene, "Npc", WorldPos.new(-1, 0, 1),
		_world.level_at(1), ActorKind.ACTOR.NULL)
	_world.add_actor(npc)
	npc.pack.add(&"timber", 4)
	_world.place_requested.emit(npc, ObjectKind.OBJECT.LADDER, WorldPos.new(HOLE.x, HOLE.y, 2))
	assert_eq(_world.level_at(2).level_fixtures.of_kind(ObjectKind.OBJECT.LADDER).size(), 1,
		"placed")
	assert_eq(other.level_at(2).level_fixtures.all().size(), 0, "nothing in the other world")


# --- build mode and the other inputs (trap 5) ---

func test_entering_build_mode_stops_a_held_dig_and_breach() -> void:
	var handler: InputHandler = add_child_autofree(InputHandler.new())
	handler.setup(_actor, func() -> Vector2: return Vector2.ZERO)
	handler.build = _cursor
	_actor.primary_action(true)
	_actor.breach(true)
	handler._build_mode(Vector2.ZERO, 0.016)
	assert_false(_actor.action_intent, "no digging while building")
	assert_false(_actor.breach_intent, "nor breaching")


func test_leaving_build_mode_hides_the_cursor() -> void:
	_cursor.toggle()
	assert_false(_cursor.active, "off")
	assert_false(_cursor.visible, "and not drawn")


# Valid and invalid both draw (ui-ux §7); drawing needs a frame.
func test_the_cursor_draws_valid_and_invalid() -> void:
	_cursor.set_tile(HOLE)
	await get_tree().process_frame
	_cursor.set_tile(Vector2i(1, 0))
	await get_tree().process_frame
	assert_true(_cursor.visible, "drawn while active")


# A placement the gatekeeper refuses, past the preview, is shown too.
func test_a_refused_placement_is_shown() -> void:
	var notice: RefusalNotice = add_child_autofree(RefusalNotice.new())
	notice.watch(_view)
	_world.request_refused.emit(_actor, World.FIXTURE_VERB.PLACE, WorldPos.new(1, 0, 2),
		World.FIXTURE_REFUSAL.NO_HOLE_ABOVE)
	assert_eq(notice.text, "A ladder goes in a hole.", "with why")


# --- the cost (D-156, D-159) ---

func test_placing_takes_the_cost_from_the_placers_pack() -> void:
	_place_at_hole()
	assert_eq(_actor.pack.count_of(&"timber"), 36, "four timber")


func test_cant_afford_is_refused_by_the_preview_and_the_gatekeeper() -> void:
	_actor.pack.remove(&"timber", 37)
	_cursor.set_tile(HOLE)
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.CANNOT_AFFORD, "the preview, with 3")
	_world.place_requested.emit(_actor, ObjectKind.OBJECT.LADDER, WorldPos.new(HOLE.x, HOLE.y, 2))
	assert_eq(get_signal_parameters(_world, "request_refused")[3],
		World.FIXTURE_REFUSAL.CANNOT_AFFORD, "the gatekeeper too")
	assert_eq(_actor.pack.count_of(&"timber"), 3, "nothing taken")


func test_a_placement_with_no_actor_is_free() -> void:
	_world.place_requested.emit(null, ObjectKind.OBJECT.LADDER, WorldPos.new(HOLE.x, HOLE.y, 2))
	assert_signal_emitted(_world, "fixture_placed", "generation and loads build for free")


func test_the_preview_shows_the_cost() -> void:
	assert_eq(Building.cost_text(_world.tuning, ObjectKind.OBJECT.LADDER), "4 timber", "the cost")
	assert_eq(Building.cost_text(_world.tuning, ObjectKind.OBJECT.BRAZIER), "", "nothing for free")


# --- the second item: a timber prop (D-165) ---

# What the cursor places is the selected build slot (D-170, D-174)
func test_the_cursor_places_the_selected_build_slot() -> void:
	assert_eq(_cursor.item, ObjectKind.OBJECT.LADDER, "slot 1: a ladder to begin with")
	_actor.hotbar.select_build(1)
	assert_eq(_cursor.item, ObjectKind.OBJECT.TIMBER_PROP, "slot 2: a prop")
	_actor.hotbar.select_build(2)
	assert_eq(_cursor.item, ObjectKind.OBJECT.NULL, "slot 3: nothing")
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.NOTHING_SELECTED, "and the preview says so")
	assert_false(_cursor.place(), "nothing asked")
	_actor.hotbar.assign_build(ObjectKind.OBJECT.LADDER, 2)
	assert_eq(_cursor.item, ObjectKind.OBJECT.LADDER, "the ladder moved to slot 3")


func test_a_prop_is_placed_on_open_floor_at_the_cursor_for_two_timber() -> void:
	_actor.hotbar.select_build(1)
	_cursor.set_tile(Vector2i(3, 0))
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.NONE, "valid on floor")
	assert_true(_cursor.place(), "asked")
	assert_eq(_world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.TIMBER_PROP).size(), 1,
		"on the player's own level")
	assert_eq(_actor.pack.count_of(&"timber"), 38, "two timber")


func test_a_prop_preview_refuses_rock_a_taken_tile_and_the_dark() -> void:
	_actor.hotbar.select_build(1)
	_cursor.set_tile(Vector2i(0, 4))
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.TOO_DARK, "behind rock, unsensed")
	_cursor.set_tile(HOLE)
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.NOT_OPEN_FLOOR, "a hole is no floor")
	_cursor.set_tile(Vector2i(3, 0))
	_cursor.place()
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.TILE_OCCUPIED, "one prop to a tile")
	_cursor.set_tile(Vector2i.ZERO)
	assert_eq(_cursor.problem(), BuildCursor.PROBLEM.ACTOR_IN_WAY, "not on the player")


func test_the_prop_preview_agrees_with_the_gatekeeper() -> void:
	_actor.hotbar.select_build(1)
	for x in range(-5, 6):
		_cursor.set_tile(Vector2i(x, 0))
		var valid: bool = _cursor.problem() == BuildCursor.PROBLEM.NONE
		var before: int = _world.level_at(1).level_fixtures.all().size()
		_world.place_requested.emit(_actor, ObjectKind.OBJECT.TIMBER_PROP, WorldPos.new(x, 0, 1))
		var placed: bool = _world.level_at(1).level_fixtures.all().size() > before
		assert_eq(valid, placed, "x = %d" % x)


func test_the_quick_key_places_at_the_cursor_in_build_mode_whatever_is_selected() -> void:
	var handler: InputHandler = add_child_autofree(InputHandler.new())
	handler.setup(_actor, func() -> Vector2: return Vector2.ZERO)
	handler.build = _cursor
	_cursor.set_tile(Vector2i(4, 0))
	handler._quick_prop()
	assert_eq(_world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.TIMBER_PROP)[0].tile.x, 4,
		"at the cursor")


func test_the_quick_key_outside_build_mode_places_on_the_faced_tile() -> void:
	_cursor.set_active(false)
	var handler: InputHandler = add_child_autofree(InputHandler.new())
	handler.setup(_actor, func() -> Vector2: return Vector2.ZERO)
	handler.build = _cursor
	_actor.facing = Vector2i(1, 0)
	handler._quick_prop()
	assert_eq(_world.level_at(1).level_fixtures.of_kind(ObjectKind.OBJECT.TIMBER_PROP)[0].tile.x, 1,
		"beside the player, where it faces")


func test_the_prop_cost_is_shown() -> void:
	assert_eq(Building.cost_text(_world.tuning, ObjectKind.OBJECT.TIMBER_PROP), "2 timber", "the cost")
