extends GutTest

# A winch's shaft (D-235, D-236), built the way a player builds it:
# breaches and winches in any order, the build cursor asked first. A
# winch's rope reaches the next winch down or the shaft's foot, and a
# shaft has one crate.

const Worlds = preload("res://tests/worlds.gd")
const X: Vector2i = Vector2i(2, 0)
const BESIDE: Vector2i = Vector2i(1, 0)

var _world: World
# A player on -1 and one on -2, each beside X and facing it
var _up: Actor
var _down: Actor
var _cursors: Dictionary[Actor, BuildCursor] = {}


# Levels 0 to 3 with open floor along y = 0 on -1, -2 and -3.
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2, 3]))
	for depth in [1, 2, 3]:
		for x in range(-6, 7):
			_world.level_at(depth).level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	_up = _player("Up", 1)
	_down = _player("Down", 2)
	watch_signals(_world)


func _player(name: String, depth: int) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, name,
		WorldPos.new(BESIDE.x, BESIDE.y, depth), _world.level_at(depth), ActorKind.ACTOR.PLAYER)
	_world.add_actor(actor)
	actor.facing = Vector2i.RIGHT
	actor.pack.add(&"timber", 60)
	actor.pack.add(&"stone", 60)
	var cursor: BuildCursor = add_child_autofree(BuildCursor.new())
	cursor.actor = actor
	cursor.set_active(true)
	cursor.tile = X
	_cursors[actor] = cursor
	return actor


func _at(depth: int) -> WorldPos:
	return WorldPos.new(X.x, X.y, depth)


func _breach(depth: int) -> World.BREACH_REFUSAL:
	var reason: World.BREACH_REFUSAL = _world.breach_problem(_at(depth), 999.0)
	_world.breach_requested.emit(null, _at(depth), 999.0)
	return reason


# Through the build cursor, as the player places it.
func _winch(actor: Actor) -> BuildCursor.PROBLEM:
	var cursor: BuildCursor = _cursors[actor]
	cursor.tile = X
	var why: BuildCursor.PROBLEM = cursor.problem(ObjectKind.OBJECT.WINCH)
	cursor.place(ObjectKind.OBJECT.WINCH)
	return why


func _winch_on(depth: int) -> Fixture:
	var found: Array[Fixture] = _world.level_at(depth).level_fixtures.of_kind(ObjectKind.OBJECT.WINCH)
	return found[0] if not found.is_empty() else null


func _crates() -> Array[Fixture]:
	var found: Array[Fixture] = []
	for depth: int in [1, 2, 3]:
		found.append_array(_world.level_at(depth).level_fixtures.of_kind(ObjectKind.OBJECT.CRATE))
	return found


func _crank(actor: Actor, seconds: float, step: float = 0.1) -> void:
	for i in roundi(seconds / step):
		_world.crank(actor, step)


# --- any order (D-235, D-236) ---

# Every order a player can do the four steps in: each winch after the
# breach it stands over.
const ORDERS: Array = [
	["b1", "b2", "w1", "w2"],
	["b1", "b2", "w2", "w1"],
	["b1", "w1", "b2", "w2"],
	["b2", "b1", "w1", "w2"],
	["b2", "b1", "w2", "w1"],
	["b2", "w2", "b1", "w1"],
]


func test_breaches_and_winches_go_in_any_order() -> void:
	for order: Array in ORDERS:
		before_each_world_reset()
		var said: Array[String] = []
		for step: String in order:
			match step:
				"b1": said.append("b1 %s" % World.BREACH_REFUSAL.find_key(_breach(1)))
				"b2": said.append("b2 %s" % World.BREACH_REFUSAL.find_key(_breach(2)))
				"w1": said.append("w1 %s" % BuildCursor.PROBLEM.find_key(_winch(_up)))
				"w2": said.append("w2 %s" % BuildCursor.PROBLEM.find_key(_winch(_down)))
		var name: String = ",".join(order)
		for line: String in said:
			assert_true(line.ends_with(" NONE"), "%s: every step allowed (%s)" % [name, line])
		assert_not_null(_winch_on(1), "%s: a winch on -1" % name)
		assert_not_null(_winch_on(2), "%s: a winch on -2" % name)
		assert_eq(_crates().size(), 1, "%s: one crate in the shaft" % name)
		# Lifted all the way: the lower winch first if it's at the foot
		var crate: Fixture = _crates()[0]
		crate.contents.add(&"stone", 5)
		if crate.tile.depth == 3: _crank(_down, 15.0)
		assert_eq(crate.tile.depth, 2, "%s: in the lower winch's hole" % name)
		_crank(_up, 15.0)
		assert_eq(crate.tile.depth, 1, "%s: and up to -1" % name)
		assert_eq(crate.contents.count_of(&"stone"), 5, "%s: still loaded" % name)


# A fresh world for each order, inside one test.
func before_each_world_reset() -> void:
	_cursors.clear()
	_world.queue_free()
	before_each()


# --- the rope (D-235) ---

func test_a_winch_over_two_holes_reaches_the_foot_and_takes_the_time_of_both() -> void:
	_breach(2)
	_breach(1)
	assert_eq(_winch(_up), BuildCursor.PROBLEM.NONE, "over a hole over a hole")
	var crate: Fixture = _crates()[0]
	assert_eq(crate.tile.depth, 3, "the crate on the shaft's foot")
	_crank(_up, 29.0)
	assert_eq(crate.tile.depth, 3, "two levels of rope: not up at 29 s")
	_crank(_up, 1.5)
	assert_eq(crate.tile.depth, 1, "up at 30 s")
	_crank(_up, 10.0)
	assert_eq(crate.tile.depth, 3, "and down again in 10 s")


func test_cranking_a_winch_whose_crate_is_at_another_says_so() -> void:
	_breach(1)
	_breach(2)
	_winch(_down)
	_winch(_up)
	_world.begin_crank(_up)
	assert_eq(get_signal_parameters(_world, "crank_refused")[1], World.CRANK_REFUSAL.CRATE_ELSEWHERE,
		"the crate is at the foot, the lower winch's to lift")


func test_the_foot_of_a_deep_shaft_is_marked_while_the_crate_is_up() -> void:
	_breach(2)
	_breach(1)
	_winch(_up)
	_crank(_up, 30.5)
	var bottom: Actor = _player("Bottom", 3)
	var view: View = add_child_autofree(View.new())
	view.follow(bottom)
	var renderer: FixtureRenderer = add_child_autofree(FixtureRenderer.new())
	renderer.watch(view)
	assert_eq(renderer.crate_landings(), [X] as Array[Vector2i], "on -3, two levels down")


# --- breaching through a shaft (D-236) ---

func test_a_crate_standing_on_the_floor_falls_when_it_is_breached() -> void:
	_breach(1)
	_winch(_up)
	assert_eq(_crates()[0].tile.depth, 2, "on -2's floor")
	assert_eq(_breach(2), World.BREACH_REFUSAL.NONE, "the floor under the crate can be breached")
	assert_eq(_crates()[0].tile.depth, 3, "and the crate falls to the new foot")


func test_a_crate_wont_fall_on_someone() -> void:
	_breach(1)
	_winch(_up)
	_player("Under", 3).move_to(_at(3), &"test")
	assert_eq(_world.breach_problem(_at(2), 999.0), World.BREACH_REFUSAL.LANDING_BLOCKED, "someone below")


func test_a_winch_shaft_wont_join_a_chute() -> void:
	_breach(2)
	_world.place_requested.emit(null, ObjectKind.OBJECT.CHUTE, _at(2))
	assert_eq(_world.breach_problem(_at(1), 999.0), World.BREACH_REFUSAL.LANDING_BLOCKED,
		"a chute's hole below")


func test_two_shafts_with_a_crate_each_wont_join() -> void:
	# The -2 winch's crate at -3, and another standing on -1's floor
	# over its shaft, as a winch on 0 would have left it
	_breach(2)
	_winch(_down)
	_world.level_at(1).level_fixtures.add(Fixture.new(ObjectKind.OBJECT.CRATE, WorldPos.new(X.x, X.y, 1), 900))
	assert_eq(_world.breach_problem(_at(1), 999.0), World.BREACH_REFUSAL.SHAFTS_CANT_JOIN,
		"a shaft holds one crate")


func test_a_ladder_wont_go_at_the_foot_of_a_winch_shaft() -> void:
	_breach(2)
	_breach(1)
	_winch(_up)
	_crank(_up, 30.5)
	_world.place_requested.emit(null, ObjectKind.OBJECT.LADDER, _at(3))
	assert_eq(get_signal_parameters(_world, "request_refused")[3], World.FIXTURE_REFUSAL.WINCH_SHAFT,
		"the rope runs there")


# --- saying why (the message fix) ---

func test_a_winch_with_no_room_for_its_crate_says_why() -> void:
	_breach(1)
	_down.move_to(_at(2), &"test")
	assert_eq(_winch(_up), BuildCursor.PROBLEM.CRATE_NEEDS_FLOOR, "someone at the foot")
	assert_eq(BuildCursor.REASONS[BuildCursor.PROBLEM.CRATE_NEEDS_FLOOR],
		"The crate needs clear floor at the bottom of the shaft.")
	assert_eq(RefusalNotice.PLACE_REASONS[World.FIXTURE_REFUSAL.LANDING_BLOCKED],
		BuildCursor.REASONS[BuildCursor.PROBLEM.CRATE_NEEDS_FLOOR], "the world's refusal says the same")
