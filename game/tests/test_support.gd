extends GutTest

# Holding it up (D-163 to D-166, digging-and-structure §2-4): the
# support rule and its R by depth, only what players dig being judged,
# the countdown a failing region shares, collapse into rubble that is
# cleared like a dig, burial rather than destruction, timber props,
# and the countdown surviving a save.

const Worlds = preload("res://tests/worlds.gd")
const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/support"
const SLOT: String = SAVES_ROOT + "/slot-001"
const FLINT: float = 16.0

var _world: World
# The level at -1, where R is 8
var _level: Level


func before_each() -> void:
	_world = autofree(Worlds.with_levels([0, 1, 2, 3, 4, 5, 6, 7], 0, wide_profile()))
	_level = _world.level_at(1)
	watch_signals(_world)


func after_each() -> void:
	SaveDirs.remove_tree(SAVES_ROOT)


# --- helpers ---

# Opens a rectangle the way digging does (marked excavated, then open),
# gathered so the rule judges it once.
func _dig_room(level: Level, rect: Rect2i) -> void:
	level.support.hold()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			level.level_tiles.mark_excavated(x, y)
			level.level_tiles.set_top(x, y, TileKind.TOP.OPEN)
	level.support.release()


# Opens a rectangle without marking it: a cave that was always there.
func _open_cave(level: Level, rect: Rect2i) -> void:
	level.support.hold()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			level.level_tiles.set_top(x, y, TileKind.TOP.OPEN)
	level.support.release()


func _states_in(level: Level, rect: Rect2i, state: LevelSupport.STATE) -> int:
	var found: int = 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if level.support.state_at(Vector2i(x, y)) == state: found += 1
	return found


# A player standing in a small natural pocket far from the rooms, so
# the level counts as occupied (its countdowns run) without standing in
# anything that falls.
func _player_on(depth: int, tile: Vector2i = Vector2i(40, 40)) -> Actor:
	var level: Level = _world.level_at(depth)
	level.level_tiles.set_top(tile.x, tile.y, TileKind.TOP.OPEN)
	var player: Actor = Actor.create(Global.actor_packed_scene, "Digger",
		WorldPos.new(tile.x, tile.y, depth), level, ActorKind.ACTOR.PLAYER)
	_world.add_actor(player)
	return player


func _at(tile: Vector2i, depth: int = 1) -> WorldPos:
	return WorldPos.new(tile.x, tile.y, depth)


func _top(tile: Vector2i, level: Level = null) -> int:
	if level == null: level = _level
	return level.level_tiles.get_top(tile.x, tile.y)


# 21 x 21 on -1: walls at 11, so the 3 x 3 in the middle is Failing.
const WIDE: Rect2i = Rect2i(-10, -10, 21, 21)


# --- R by depth (§2's table, in the profile) ---

# The rule's tests run under 010's R table, whose rooms they measure
# (R = 8 at -1); the default profile's own table is D-186's, pinned
# below. The rule is the same for any table.
static func wide_profile() -> TuningProfile:
	var profile: TuningProfile = TuningProfile.default_profile().duplicate()
	profile.support_radius_by_depth = [0, 8, 7, 6, 5, 4, 3, 3]
	return profile


func test_r_falls_with_depth_and_the_surface_has_no_ceiling() -> void:
	var expected: Array[int] = [-1, 8, 7, 6, 5, 4, 3, 3]
	for depth in range(8):
		assert_eq(_world.level_at(depth).support.radius, expected[depth], "depth %d" % depth)


# D-211: one less than D-186's at every depth. Red starts at 9 wide
# on -1.
func test_the_default_r_starts_red_at_nine_wide() -> void:
	assert_eq(TuningProfile.default_profile().support_radius_by_depth,
		[0, 3, 3, 2, 2, 1, 1, 1] as Array[int], "3, 3, 2, 2, 1, 1, 1")
	var world: World = autofree(Worlds.with_levels([1]))
	var level: Level = world.level_at(1)
	_dig_room(level, Rect2i(-4, -4, 9, 9))
	assert_eq(level.support.state_at(Vector2i.ZERO), LevelSupport.STATE.FAILING, "9 wide: red")
	var other: World = autofree(Worlds.with_levels([1]))
	_dig_room(other.level_at(1), Rect2i(-3, -3, 7, 7))
	assert_eq(other.level_at(1).support.state_at(Vector2i.ZERO), LevelSupport.STATE.MARGINAL,
		"7 wide: amber at most")


func test_state_for_the_three_bands() -> void:
	assert_eq(LevelSupport.state_for(8, 8), LevelSupport.STATE.STABLE, "at R")
	assert_eq(LevelSupport.state_for(1, 8), LevelSupport.STATE.STABLE, "beside a wall")
	assert_eq(LevelSupport.state_for(9, 8), LevelSupport.STATE.MARGINAL, "at R + 1")
	assert_eq(LevelSupport.state_for(10, 8), LevelSupport.STATE.FAILING, "beyond")


# --- the rule: Chebyshev, from solid walls ---

func test_a_corridor_never_fails_however_long() -> void:
	_dig_room(_level, Rect2i(-60, 0, 121, 1))
	assert_eq(_states_in(_level, Rect2i(-60, 0, 121, 1), LevelSupport.STATE.STABLE), 121,
		"every tile of it is stable")
	assert_false(_level.support.has_failing(), "nothing counts down")
	assert_signal_not_emitted(_world, "ceiling_failing")


func test_a_two_wide_tunnel_never_fails_at_any_depth() -> void:
	for depth in range(1, 8):
		var level: Level = _world.level_at(depth)
		_dig_room(level, Rect2i(-50, 0, 101, 2))
		assert_false(level.support.has_failing(), "depth %d" % depth)
		assert_eq(_states_in(level, Rect2i(-50, 0, 101, 2), LevelSupport.STATE.STABLE), 202,
			"depth %d: all stable" % depth)


func test_a_room_17_wide_is_amber_in_the_middle() -> void:
	_dig_room(_level, Rect2i(-8, -8, 17, 17))
	assert_eq(_level.support.state_at(Vector2i.ZERO), LevelSupport.STATE.MARGINAL,
		"nine tiles from every wall: R + 1")
	assert_eq(_level.support.state_at(Vector2i(5, 0)), LevelSupport.STATE.STABLE, "nearer a wall")
	assert_false(_level.support.has_failing(), "the teaching band doesn't count down")


func test_a_room_19_wide_fails_in_the_middle() -> void:
	_dig_room(_level, Rect2i(-9, -9, 19, 19))
	assert_eq(_level.support.state_at(Vector2i.ZERO), LevelSupport.STATE.FAILING, "ten from a wall")
	assert_eq(_level.support.failing_tiles().size(), 1, "just the middle tile")


func test_the_same_room_fails_sooner_deeper() -> void:
	# 7 wide: walls 4 away from the middle; R is 3 at -6
	var deep: Level = _world.level_at(6)
	_dig_room(deep, Rect2i(-3, -3, 7, 7))
	assert_eq(deep.support.state_at(Vector2i.ZERO), LevelSupport.STATE.MARGINAL, "R + 1 at -6")
	_dig_room(_level, Rect2i(-3, -3, 7, 7))
	assert_eq(_level.support.state_at(Vector2i.ZERO), LevelSupport.STATE.STABLE, "easy at -1")


func test_the_surface_is_never_judged() -> void:
	var surface: Level = _world.level_at(0)
	_dig_room(surface, Rect2i(-30, -30, 61, 61))
	assert_true(surface.support.judged_tiles().is_empty(), "open sky has no ceiling")


# D-164: natural caves hold themselves up.
func test_natural_caves_never_fail() -> void:
	_open_cave(_level, Rect2i(-30, -30, 61, 61))
	assert_true(_level.support.judged_tiles().is_empty(), "nothing is judged")
	_player_on(1)
	_world.advance_time(500.0)
	assert_eq(_top(Vector2i.ZERO), TileKind.TOP.OPEN, "and nothing falls")


func test_a_dig_marks_the_tile_excavated_and_the_rule_judges_it() -> void:
	_level.level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	_world.dig_requested.emit(null, _at(Vector2i(3, 3)))
	assert_true(_level.level_tiles.is_excavated(3, 3), "dug")
	assert_false(_level.level_tiles.is_excavated(0, 0), "a cave tile isn't")
	assert_ne(_level.support.state_at(Vector2i(3, 3)), LevelSupport.STATE.NONE, "judged")
	assert_eq(_level.support.state_at(Vector2i.ZERO), LevelSupport.STATE.NONE, "the cave isn't")


# A breach opens the landing below, rock a player dug; the floor above
# was open already.
func test_a_breach_marks_the_landing_not_the_floor() -> void:
	_level.level_tiles.set_top(2, 0, TileKind.TOP.OPEN)
	_world.level_at(2).level_tiles.set_top(2, 0, TileKind.TOP.OPEN)
	_world.breach_requested.emit(null, _at(Vector2i(2, 0)), 999.0)
	assert_true(_world.level_at(2).level_tiles.is_excavated(2, 0), "the landing")
	assert_false(_level.level_tiles.is_excavated(2, 0), "the hole's own tile")


# An NPC's digging goes through the same gatekeeper (pillar P5).
func test_an_npcs_digging_is_judged_the_same() -> void:
	var npc: Actor = Actor.create(Global.actor_packed_scene, "Npc", _at(Vector2i(40, 40)),
		_level, ActorKind.ACTOR.NULL)
	_level.level_tiles.set_top(40, 40, TileKind.TOP.OPEN)
	_world.add_actor(npc)
	_level.support.hold()
	for y in range(-9, 10):
		for x in range(-9, 10):
			_world.dig_requested.emit(npc, _at(Vector2i(x, y)))
	_level.support.release()
	assert_eq(_level.support.state_at(Vector2i.ZERO), LevelSupport.STATE.FAILING,
		"the NPC's room fails like anyone's")


# Trap 2: a dig removes a support, so a tile a few away changes state.
func test_a_dig_three_tiles_away_changes_a_tiles_state() -> void:
	_dig_room(_level, Rect2i(-8, -8, 17, 17))
	assert_eq(_level.support.state_at(Vector2i.ZERO), LevelSupport.STATE.MARGINAL, "to begin with")
	# Dig out the wall ring; the nearest walls are now one tile further
	_dig_room(_level, Rect2i(-9, -9, 19, 19))
	assert_eq(_level.support.state_at(Vector2i.ZERO), LevelSupport.STATE.FAILING,
		"the wall that held it is gone")


# Trap 1: the work follows the change, not the level.
func test_a_dig_in_a_big_room_costs_a_window_not_a_level() -> void:
	_dig_room(_level, WIDE)
	var started: int = Time.get_ticks_usec()
	_world.dig_requested.emit(null, _at(Vector2i(11, 0)))
	var msec: float = (Time.get_ticks_usec() - started) / 1000.0
	gut.p("a dig beside a big room judged in %.2f ms" % msec)
	assert_lt(msec, 40.0, "a few milliseconds, not a scan of 100,000 tiles")


# --- the countdown ---

func test_a_failing_region_counts_down_45_seconds_then_falls() -> void:
	_player_on(1)
	_dig_room(_level, WIDE)
	assert_eq(_level.support.failing_tiles().size(), 9, "the middle 3 x 3")
	assert_signal_emit_count(_world, "ceiling_failing", 1, "one warning for the region")
	assert_almost_eq(_level.support.remaining_at(Vector2i.ZERO), 45.0, 0.001, "45 s")

	_world.advance_time(44.0)
	assert_eq(_top(Vector2i.ZERO), TileKind.TOP.OPEN, "still standing at 44 s")
	assert_almost_eq(_level.support.remaining_at(Vector2i.ZERO), 1.0, 0.001, "a second left")
	_world.advance_time(1.5)
	assert_eq(_top(Vector2i.ZERO), TileKind.TOP.RUBBLE, "fallen")
	assert_eq(_states_in(_level, Rect2i(-1, -1, 3, 3), LevelSupport.STATE.NONE), 9,
		"rubble isn't judged")
	assert_signal_emit_count(_world, "collapsed", 1, "announced")
	assert_false(_level.support.has_failing(), "and nothing counts down any more")


func test_the_failing_tiles_are_rubble_and_the_rest_of_the_room_stands() -> void:
	_player_on(1)
	_dig_room(_level, WIDE)
	_world.advance_time(46.0)
	assert_eq(_top(Vector2i(2, 2)), TileKind.TOP.OPEN, "the marginal ring stands")
	assert_eq(_top(Vector2i(1, 1)), TileKind.TOP.RUBBLE, "the failing block is rubble")


func test_a_support_in_time_cancels_it() -> void:
	var player: Actor = _player_on(1)
	_dig_room(_level, WIDE)
	_world.advance_time(30.0)
	_world.place_requested.emit(null, ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i.ZERO))
	assert_false(_level.support.has_failing(), "the cracks stop")
	assert_eq(_level.support.state_at(Vector2i(1, 1)), LevelSupport.STATE.STABLE, "and it is green")
	_world.advance_time(100.0)
	assert_eq(_top(Vector2i(1, 1)), TileKind.TOP.OPEN, "nothing falls")
	assert_not_null(player, "someone was watching")


# Trap 3: tiles that join keep the region's time, not a fresh 45.
func test_digging_more_of_a_failing_room_keeps_the_regions_time() -> void:
	_player_on(1)
	_dig_room(_level, WIDE)
	_world.advance_time(30.0)
	_dig_room(_level, Rect2i(-11, -11, 23, 23))
	assert_eq(_level.support.failing_tiles().size(), 25, "the failing block grew to 5 x 5")
	assert_almost_eq(_level.support.remaining_at(Vector2i(2, 2)), 15.0, 0.001,
		"the new tiles took the region's time, not a fresh 45")
	assert_signal_emit_count(_world, "ceiling_failing", 1, "it is still one region")
	_world.advance_time(14.0)
	assert_eq(_top(Vector2i(2, 2)), TileKind.TOP.OPEN, "not yet")
	_world.advance_time(2.0)
	assert_eq(_top(Vector2i(2, 2)), TileKind.TOP.RUBBLE, "the joined tiles fall with the rest")
	assert_eq(_top(Vector2i.ZERO), TileKind.TOP.RUBBLE, "all of it")


# Trap 3: a region split by a prop keeps its time in both halves, and
# the tiles the prop saved lose theirs.
func test_a_prop_that_splits_a_region_leaves_both_halves_their_time() -> void:
	_player_on(1)
	_dig_room(_level, Rect2i(-20, -10, 41, 21))
	assert_eq(_level.support.failing_tiles().size(), 23 * 3, "a long strip")
	_world.advance_time(20.0)
	_world.place_requested.emit(null, ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i.ZERO))
	assert_eq(_level.support.remaining_at(Vector2i.ZERO), -1.0, "the saved middle has no countdown")
	assert_almost_eq(_level.support.remaining_at(Vector2i(10, 0)), 25.0, 0.001, "one half")
	assert_almost_eq(_level.support.remaining_at(Vector2i(-10, 0)), 25.0, 0.001, "the other")
	assert_signal_emit_count(_world, "ceiling_failing", 1, "no new warning")
	_world.advance_time(26.0)
	assert_eq(_top(Vector2i(10, 0)), TileKind.TOP.RUBBLE, "the east half fell")
	assert_eq(_top(Vector2i(-11, 1)), TileKind.TOP.RUBBLE, "and the west")
	assert_eq(_top(Vector2i.ZERO), TileKind.TOP.OPEN, "the middle stands")


func test_two_separate_failures_count_down_separately() -> void:
	_player_on(1)
	_dig_room(_level, Rect2i(-10, -10, 21, 21))
	_world.advance_time(20.0)
	_dig_room(_level, Rect2i(30, -10, 21, 21))
	assert_signal_emit_count(_world, "ceiling_failing", 2, "a second room, a second warning")
	assert_almost_eq(_level.support.remaining_at(Vector2i(40, 0)), 45.0, 0.001, "its own 45 s")
	assert_almost_eq(_level.support.remaining_at(Vector2i.ZERO), 25.0, 0.001, "the first runs on")


# --- who is on the level (slice 010 trap 5) ---

func test_a_level_nobody_is_on_stands_still() -> void:
	_player_on(2)
	_dig_room(_level, WIDE)
	_world.advance_time(500.0)
	assert_eq(_top(Vector2i.ZERO), TileKind.TOP.OPEN, "nothing falls out of sight")
	assert_almost_eq(_level.support.remaining_at(Vector2i.ZERO), 45.0, 0.001, "and the time holds")


func test_a_world_outside_the_tree_does_not_tick() -> void:
	_player_on(1)
	_dig_room(_level, WIDE)
	# Not in the tree: no physics tick reaches it, however long we wait
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_almost_eq(_level.support.remaining_at(Vector2i.ZERO), 45.0, 0.001,
		"a world still being built doesn't count down")


# --- collapse ---

func test_a_collapse_moves_an_actor_caught_in_it_clear() -> void:
	var stuck: Actor = _player_on(1, Vector2i.ZERO)
	_dig_room(_level, WIDE)
	_world.advance_time(46.0)
	assert_signal_emit_count(_world, "actor_moved_clear", 1, "told")
	var here: WorldPos = stuck.current_WorldPos
	assert_true(TileKind.is_passable(_top(Vector2i(here.x, here.y)), TileKind.GROUND.ROCK),
		"standing on open floor")
	assert_true(TileCollision.fits(_level.level_tiles, stuck.get_world_box()), "and it fits")


func test_rubble_is_solid_and_no_support() -> void:
	assert_false(TileKind.is_passable(TileKind.TOP.RUBBLE, TileKind.GROUND.ROCK), "solid")
	assert_false(TileKind.is_supporting(TileKind.TOP.RUBBLE), "holds nothing up")
	for kind: int in [TileKind.TOP.MINABLE_ROCK, TileKind.TOP.MINABLE_DIRT,
			TileKind.TOP.IMPENETRABLE_ROCK]:
		assert_true(TileKind.is_supporting(kind), "kind %d holds" % kind)


func test_rubble_does_not_hold_the_next_tile_up() -> void:
	_player_on(1)
	_dig_room(_level, Rect2i(-20, -10, 41, 21))
	_world.advance_time(46.0)
	# The strip fell; the room around it still has the same walls, so the
	# open tiles beside the rubble are no better held than before
	assert_eq(_level.support.state_at(Vector2i(0, 2)), LevelSupport.STATE.MARGINAL,
		"rubble isn't a wall")
	assert_false(_level.support.has_failing(), "and nothing cascades")


# --- clearing ---

func test_rubble_clears_like_a_dig_in_four_tenths_of_a_second_for_nothing() -> void:
	assert_almost_eq(Digging.hardness_of(_world.tuning, TileKind.TOP.RUBBLE) / FLINT, 0.4, 0.001,
		"the tuning appendix's rubble time")
	var digger: Actor = _player_on(1)
	_level.level_tiles.set_top(5, 5, TileKind.TOP.RUBBLE)
	_level.level_tiles.mark_excavated(5, 5)
	_world.dig_requested.emit(digger, _at(Vector2i(5, 5)))
	assert_eq(_top(Vector2i(5, 5)), TileKind.TOP.OPEN, "cleared")
	assert_eq(digger.pack.count_of(&"stone"), 0, "no stone")
	assert_true(_level.level_tiles.is_excavated(5, 5), "still a room somebody made")


# --- burial, not destruction (trap 4) ---

func test_fixtures_and_drops_under_rubble_are_kept_and_come_back() -> void:
	var player: Actor = _player_on(1)
	_dig_room(_level, WIDE)
	_world.place_requested.emit(null, ObjectKind.OBJECT.BRAZIER, _at(Vector2i.ZERO))
	_level.level_drops.add(Vector2i(1, 1), &"timber", 3)
	_world.advance_time(46.0)
	assert_eq(_level.level_fixtures.of_kind(ObjectKind.OBJECT.BRAZIER).size(), 1, "the brazier is kept")
	assert_eq(_level.level_drops.at(Vector2i(1, 1)).get(&"timber", 0), 3, "and the drop")
	assert_false(Vector2i.ZERO in Light.lit_tiles(_level, _world.tuning), "a buried brazier gives no light")

	# Out of reach under the rubble
	player.move_to(_at(Vector2i(2, 2)))
	_world.take_requested.emit(player)
	assert_eq(player.pack.count_of(&"timber"), 0, "can't be taken through the rubble")

	_world.dig_requested.emit(player, _at(Vector2i(1, 1)))
	_world.take_requested.emit(player)
	assert_eq(player.pack.count_of(&"timber"), 3, "cleared, it comes back")


func test_rubble_over_a_ladders_hole_or_landing_makes_it_unusable_not_gone() -> void:
	_level.level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	_world.level_at(2).level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	_world.breach_requested.emit(null, _at(Vector2i.ZERO), 999.0)
	_world.place_requested.emit(null, ObjectKind.OBJECT.LADDER, _at(Vector2i.ZERO, 2))
	var beside: WorldPos = _at(Vector2i(-1, 0))
	_level.level_tiles.set_top(-1, 0, TileKind.TOP.OPEN)
	assert_not_null(Ladder.target_for(_level, beside, Vector2i.RIGHT), "usable to begin with")

	_level.level_tiles.set_top(0, 0, TileKind.TOP.RUBBLE)
	assert_null(Ladder.target_for(_level, beside, Vector2i.RIGHT), "rubble over the hole")
	assert_eq(_world.level_at(2).level_fixtures.of_kind(ObjectKind.OBJECT.LADDER).size(), 1, "kept")
	_level.level_tiles.set_top(0, 0, TileKind.TOP.OPEN)
	assert_not_null(Ladder.target_for(_level, beside, Vector2i.RIGHT), "back when cleared")

	_world.level_at(2).level_tiles.set_top(0, 0, TileKind.TOP.RUBBLE)
	assert_null(Ladder.target_for(_level, beside, Vector2i.RIGHT), "rubble over the landing")


# --- timber props (D-165) ---

func test_a_prop_costs_two_timber_and_blocks_its_tile() -> void:
	var player: Actor = _player_on(1)
	player.pack.add(&"timber", 5)
	_level.level_tiles.set_top(41, 40, TileKind.TOP.OPEN)
	_world.place_requested.emit(player, ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i(41, 40)))
	assert_eq(player.pack.count_of(&"timber"), 3, "two spent")
	assert_eq(_level.level_fixtures.of_kind(ObjectKind.OBJECT.TIMBER_PROP).size(), 1, "placed")
	var box: Rect2 = Rect2(Vector2(41, 40) * TileSpace.TILE_PIXELS + Vector2(4, 4), Vector2(6, 6))
	assert_false(TileCollision.fits(_level.level_tiles, box), "nobody walks onto it")
	assert_true(_level.level_tiles.is_blocked(41, 40), "blocked")


func test_a_prop_is_refused_without_the_timber() -> void:
	var player: Actor = _player_on(1)
	_level.level_tiles.set_top(41, 40, TileKind.TOP.OPEN)
	_world.place_requested.emit(player, ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i(41, 40)))
	assert_signal_emitted(_world, "request_refused")
	assert_eq(_level.level_fixtures.of_kind(ObjectKind.OBJECT.TIMBER_PROP).size(), 0, "none")


func test_a_prop_is_not_set_where_someone_stands() -> void:
	var player: Actor = _player_on(1)
	player.pack.add(&"timber", 5)
	_world.place_requested.emit(player, ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i(40, 40)))
	var args: Variant = get_signal_parameters(_world, "request_refused")
	assert_eq(args[3], World.FIXTURE_REFUSAL.ACTOR_ON_TILE, "it would wall them in")
	assert_eq(player.pack.count_of(&"timber"), 5, "and costs nothing")


func test_a_prop_shares_no_tile_with_the_other_fixtures() -> void:
	_level.level_tiles.set_top(41, 40, TileKind.TOP.OPEN)
	_world.place_requested.emit(null, ObjectKind.OBJECT.BRAZIER, _at(Vector2i(41, 40)))
	_world.place_requested.emit(null, ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i(41, 40)))
	assert_eq(_level.level_fixtures.of_kind(ObjectKind.OBJECT.TIMBER_PROP).size(), 0, "no")


func test_a_removed_prop_holds_nothing_up() -> void:
	_dig_room(_level, WIDE)
	_world.place_requested.emit(null, ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i.ZERO))
	var prop: Fixture = _level.level_fixtures.of_kind(ObjectKind.OBJECT.TIMBER_PROP)[0]
	assert_false(_level.support.has_failing(), "held")
	_world.remove_requested.emit(null, prop.id)
	assert_true(_level.support.has_failing(), "and failing again once it's taken away")
	assert_false(_level.level_tiles.is_blocked(0, 0), "and the tile is open")


func test_a_prop_moved_takes_its_support_and_its_block_with_it() -> void:
	_dig_room(_level, WIDE)
	_world.place_requested.emit(null, ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i.ZERO))
	var prop: Fixture = _level.level_fixtures.of_kind(ObjectKind.OBJECT.TIMBER_PROP)[0]
	_world.move_requested.emit(null, prop.id, _at(Vector2i(0, 8)))
	assert_false(_level.level_tiles.is_blocked(0, 0), "the old tile is open")
	assert_true(_level.level_tiles.is_blocked(0, 8), "the new one isn't")
	assert_eq(_level.support.state_at(Vector2i(0, 8)), LevelSupport.STATE.STABLE, "it holds there")


func test_the_visibility_rule_ignores_the_excavated_bit() -> void:
	_level.level_tiles.mark_excavated(3, 3)
	var bytes: PackedByteArray = Visibility.build(_level, [], [])
	assert_eq(bytes[_level.level_tiles.get_index(3, 3)], Visibility.STATE.UNKNOWN,
		"dug is not seen")
	_level.level_tiles.remember([Vector2i(3, 3)] as Array[Vector2i])
	bytes = Visibility.build(_level, [], [])
	assert_eq(bytes[_level.level_tiles.get_index(3, 3)], Visibility.STATE.REMEMBERED,
		"dug and seen is remembered, not sensed")


# --- saving (D-163: the countdown is saved) ---

func _saved(player: Actor) -> void:
	DirAccess.make_dir_recursive_absolute(SLOT)
	assert_eq(SaveGame.save_game(SLOT, _world, SaveSession.new(player.actor_id), SAVES_ROOT),
		SaveGame.REFUSAL_REASON.NONE, "saved")


# A load runs under the profile the save names, found by its id: the
# default, so this world is built under it too (D-211's R = 3 at -1,
# which fails the wide room's middle 13 x 13).
func test_a_countdown_resumes_after_a_save_not_restarts() -> void:
	_world = autofree(Worlds.with_levels([0, 1, 2, 3, 4, 5, 6, 7]))
	_level = _world.level_at(1)
	var player: Actor = _player_on(1)
	_dig_room(_level, WIDE)
	var failing: int = _level.support.failing_tiles().size()
	assert_eq(failing, 169, "the middle 13 x 13 fails at R = 3")
	_world.advance_time(30.0)
	_saved(player)
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(SLOT)
	if loaded == null:
		fail_test("refused")
		return
	var level: Level = loaded.world.level_at(1)
	assert_eq(level.support.failing_tiles().size(), failing, "the same region")
	assert_almost_eq(level.support.remaining_at(Vector2i.ZERO), 15.0, 0.001, "15 s left, not 45")
	assert_true(level.level_tiles.is_excavated(0, 0), "the excavation came back")
	loaded.free_world()


# Trap 5: a countdown saved at one second left falls when the loaded
# world runs, never while it is being built.
func test_a_countdown_saved_at_one_second_does_not_fall_in_the_load() -> void:
	var player: Actor = _player_on(1)
	_dig_room(_level, WIDE)
	_world.advance_time(44.0)
	_saved(player)
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(SLOT)
	if loaded == null:
		fail_test("refused")
		return
	var level: Level = loaded.world.level_at(1)
	assert_eq(level.level_tiles.get_top(0, 0), TileKind.TOP.OPEN, "still standing after the load")
	assert_almost_eq(level.support.remaining_at(Vector2i.ZERO), 1.0, 0.001, "one second left")
	loaded.world.advance_time(1.5)
	assert_eq(level.level_tiles.get_top(0, 0), TileKind.TOP.RUBBLE, "and it falls once it runs")
	loaded.free_world()


func test_rubble_and_props_survive_a_save() -> void:
	var player: Actor = _player_on(1)
	_dig_room(_level, WIDE)
	_world.advance_time(46.0)
	_world.place_requested.emit(null, ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i(5, 5)))
	_saved(player)
	var loaded: SaveGame.LoadedGame = SaveGame.load_game(SLOT)
	if loaded == null:
		fail_test("refused")
		return
	var level: Level = loaded.world.level_at(1)
	assert_eq(level.level_tiles.get_top(0, 0), TileKind.TOP.RUBBLE, "rubble is a saved kind")
	assert_true(level.level_tiles.is_blocked(5, 5), "the prop blocks again")
	assert_eq(level.support.state_at(Vector2i(5, 5)), LevelSupport.STATE.STABLE,
		"and it holds the room up again")
	loaded.free_world()


# --- presentation ---

func test_cracks_come_in_three_stages() -> void:
	assert_eq(CollapseCracks.stage_for(0.0), 1, "as it begins")
	assert_eq(CollapseCracks.stage_for(0.4), 2, "a third in")
	assert_eq(CollapseCracks.stage_for(0.7), 3, "two thirds in")
	assert_eq(CollapseCracks.stage_for(1.0), 3, "never more than three")


func test_the_overlay_tints_green_amber_and_red_and_toggles() -> void:
	var overlay: SupportOverlay = autofree(SupportOverlay.new())
	assert_false(overlay.active, "off until asked")
	overlay.toggle()
	assert_true(overlay.active and overlay.visible, "on")
	overlay.toggle()
	assert_false(overlay.visible, "off again")
	var green: Color = SupportOverlay.color_for(LevelSupport.STATE.STABLE)
	var amber: Color = SupportOverlay.color_for(LevelSupport.STATE.MARGINAL)
	var red: Color = SupportOverlay.color_for(LevelSupport.STATE.FAILING)
	assert_gt(green.g, green.r, "stable is green")
	assert_gt(amber.r, amber.b, "marginal is amber")
	assert_gt(amber.g, amber.b, "marginal is amber")
	assert_gt(red.r, red.g, "failing is red")
	assert_eq(SupportOverlay.color_for(LevelSupport.STATE.NONE), Color.TRANSPARENT, "unjudged is clear")


# --- the corners ---

func test_a_prop_is_not_set_on_a_ramp() -> void:
	_level.level_tiles.set_top(41, 40, TileKind.TOP.OPEN)
	_level.level_tiles.set_ground(41, 40, TileKind.GROUND.RAMP_DOWN_E)
	assert_eq(FixturePlacement.problem(ObjectKind.OBJECT.TIMBER_PROP, Vector2i(41, 40),
		_level.level_tiles, _level.level_fixtures, null), World.FIXTURE_REFUSAL.TILE_NOT_PASSABLE,
		"a prop would wall the ramp off")


func test_a_prop_is_not_moved_onto_someone() -> void:
	_player_on(1)
	_level.level_tiles.set_top(41, 40, TileKind.TOP.OPEN)
	_world.place_requested.emit(null, ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i(41, 40)))
	var prop: Fixture = _level.level_fixtures.of_kind(ObjectKind.OBJECT.TIMBER_PROP)[0]
	_world.move_requested.emit(null, prop.id, _at(Vector2i(40, 40)))
	assert_eq(get_signal_parameters(_world, "request_refused")[3],
		World.FIXTURE_REFUSAL.ACTOR_ON_TILE, "refused")
	assert_true(_level.level_tiles.is_blocked(41, 40), "and it stays where it was")


func test_a_tile_that_is_not_failing_has_no_progress_or_time() -> void:
	assert_eq(_level.support.progress_at(Vector2i.ZERO), 0.0, "no progress")
	assert_eq(_level.support.remaining_at(Vector2i.ZERO), -1.0, "no time")


func test_a_malformed_saved_countdown_is_skipped_with_a_warning() -> void:
	_dig_room(_level, WIDE)
	_level.support.restore([{"remaining": "soon", "tiles": [0, 0]}, 7,
		{"remaining": 5.0, "tiles": [0, 0, 1]}])
	assert_push_warning_count(3, "each skipped entry says so")
	assert_almost_eq(_level.support.remaining_at(Vector2i.ZERO), 45.0, 0.001,
		"the fresh countdown stands")


func test_a_store_swapped_in_by_a_load_is_judged_again() -> void:
	_dig_room(_level, WIDE)
	var fixtures: LevelFixtures = LevelFixtures.new()
	fixtures.add(Fixture.new(ObjectKind.OBJECT.TIMBER_PROP, _at(Vector2i.ZERO), 77))
	_level.level_fixtures = fixtures
	assert_false(_level.support.has_failing(), "the prop in the new store holds the room")
	assert_true(_level.level_tiles.is_blocked(0, 0), "and blocks")
