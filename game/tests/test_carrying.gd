extends GutTest

# The weight you feel (D-030, D-158, D-159): the load curve slows
# walking, and past 150% of capacity a ladder can't be climbed. Ramps
# still work.

const Worlds = preload("res://tests/worlds.gd")
const SHAFT: Vector2i = Vector2i(0, 0)

var _world: World


func _tuning() -> TuningProfile:
	return TuningProfile.default_profile()


# --- the curve (tuning appendix §2: 5.0 tiles/s base) ---

func test_the_curve_matches_the_appendix_in_tiles_per_second() -> void:
	var t: TuningProfile = _tuning()
	var cases: Array = [[0.0, 5.0], [0.5, 5.0], [0.8, 4.2], [1.0, 3.6], [1.5, 2.2], [1.6, 1.6],
		[3.0, 1.6]]
	for case: Array in cases:
		assert_almost_eq(5.0 * Carrying.speed_factor(t, case[0]), case[1], 0.001,
			"%d%% load" % int(case[0] * 100))


func test_between_points_it_is_a_straight_line() -> void:
	assert_almost_eq(Carrying.speed_factor(_tuning(), 0.65), 0.92, 0.0001, "halfway, 50-80%")
	assert_almost_eq(Carrying.speed_factor(_tuning(), 1.25), 0.58, 0.0001, "halfway, 100-150%")


func test_a_profile_with_no_curve_never_slows() -> void:
	var t: TuningProfile = _tuning().duplicate()
	t.load_speed_points = []
	assert_eq(Carrying.speed_factor(t, 2.0), 1.0, "no curve, no slowdown")


# --- on an actor ---

# A ladder: a hole on the Surface at the shaft, a ladder under it on
# -1, open floor around both. The actor stands beside the hole.
func before_each() -> void:
	# A blank -2 too: arriving on -1 would otherwise generate the real
	# -2 under this blank -1 (D-143)
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2]))
	for depth in [0, 1]:
		for x in range(-2, 3):
			_world.level_at(depth).level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	_world.level_at(0).level_tiles.set_ground(SHAFT.x, SHAFT.y, TileKind.GROUND.HOLE)
	_world.level_at(1).level_fixtures.add(
		Fixture.new(ObjectKind.OBJECT.LADDER, WorldPos.new(SHAFT.x, SHAFT.y, 1), 1))
	watch_signals(_world)


func _climber(kind: int = ActorKind.ACTOR.PLAYER) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Climber", WorldPos.new(-1, 0, 0),
		_world.level_at(0), kind)
	_world.add_actor(actor)
	actor.facing = Vector2i(1, 0)
	return actor


# 60 kg capacity, stone 3 kg: 30 stone is 150%.
func _load(actor: Actor, stones: int) -> void:
	actor.pack.add(&"stone", stones)


func test_an_actor_walks_slower_loaded() -> void:
	var actor: Actor = _climber()
	var empty: float = actor.speed
	_load(actor, 20)
	assert_almost_eq(actor.speed, empty * 0.72, 0.001, "full: 72% of the empty speed")


func test_at_150_percent_the_ladder_still_climbs() -> void:
	var actor: Actor = _climber()
	_load(actor, 30)
	assert_true(actor.interact(), "exactly 150%")
	assert_eq(actor.depth, 1, "down the ladder")


func test_past_150_percent_the_ladder_refuses_and_says_so() -> void:
	var actor: Actor = _climber()
	_load(actor, 31)
	assert_false(actor.interact(), "too heavy")
	assert_eq(actor.depth, 0, "still on the Surface")
	assert_signal_emitted(_world, "climb_refused", "announced on its world")


func test_an_npc_is_held_to_the_same_rule() -> void:
	var npc: Actor = _climber(ActorKind.ACTOR.NULL)
	_load(npc, 31)
	assert_false(npc.interact(), "P5: the rule asks nobody who they are")


# D-030: other ways down still work. A ramp move is the same move_to.
func test_a_ramp_doesnt_ask_about_load() -> void:
	var actor: Actor = _climber()
	_load(actor, 50)
	assert_true(actor.move_to(WorldPos.new(-1, 0, 1)), "moved down by other means")


func test_the_refusal_is_shown_to_the_player() -> void:
	var view: View = add_child_autofree(View.new())
	var notice: RefusalNotice = add_child_autofree(RefusalNotice.new())
	notice.watch(view)
	var actor: Actor = _climber()
	view.follow(actor)
	_load(actor, 31)
	actor.interact()
	assert_eq(notice.text, "Too heavy to climb.", "with why")
