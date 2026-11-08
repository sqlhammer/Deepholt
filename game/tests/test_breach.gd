extends GutTest

# Breaching a floor (D-150 to D-153). Digging's rules give the time
# and the tool gate from the floor's level; the world's tile
# gatekeeper turns the floor into a hole and clears the landing below,
# whole or not at all; the capability does the work while the breach
# input is held, and asks.

const Worlds = preload("res://tests/worlds.gd")
const TICK: float = 1.0 / 60.0
const FLINT: float = 16.0
const SPOT: Vector2i = Vector2i(3, 0)

var _world: World


# Blank levels (solid rock) at the Surface, -1 and -2, with a strip of
# open floor along y = 0 on each.
func before_each() -> void:
	_world = add_child_autofree(Worlds.with_levels([0, 1, 2]))
	for depth in [0, 1, 2]:
		for x in range(-5, 6):
			_world.level_at(depth).level_tiles.set_top(x, 0, TileKind.TOP.OPEN)
	watch_signals(_world)


func _tuning() -> TuningProfile:
	return _world.tuning


func _at(depth: int, tile: Vector2i = SPOT) -> WorldPos:
	return WorldPos.new(tile.x, tile.y, depth)


func _breach(depth: int, tile: Vector2i = SPOT, power: float = FLINT) -> void:
	_world.breach_requested.emit(null, _at(depth, tile), power)


func _reason() -> int:
	var args: Variant = get_signal_parameters(_world, "breach_refused")
	return args[2] if args != null else -1


# --- Digging's rules (D-150, D-151) ---

func test_flint_breaches_the_surface_and_minus_one_but_not_minus_two() -> void:
	var t: TuningProfile = _tuning()
	assert_almost_eq(Digging.breach_seconds(t, Digging.floor_hardness(t, 0), FLINT), 3.0, 0.001,
		"the Surface in 3 s")
	assert_almost_eq(Digging.breach_seconds(t, Digging.floor_hardness(t, 1), FLINT), 5.0, 0.001,
		"-1 in 5 s (tuning appendix)")
	assert_true(Digging.can_breach(t, Digging.floor_hardness(t, 1), FLINT), "-1: 16 >= 12")
	assert_false(Digging.can_breach(t, Digging.floor_hardness(t, 2), FLINT), "-2: 16 < 21.6")
	assert_true(Digging.can_breach(t, Digging.floor_hardness(t, 2), 30.0), "bronze opens -2")


func test_every_recipe_depth_has_a_floor_hardness() -> void:
	for depth in range(LevelRecipes.TABLE.rows.size()):
		assert_gt(Digging.floor_hardness(_tuning(), depth), 0.0, "depth %d" % depth)
	assert_eq(Digging.floor_hardness(_tuning(), 99), -1.0, "none past the table")


# --- the gatekeeper (D-152) ---

func test_a_breach_makes_a_hole_and_clears_the_landing() -> void:
	var below: LevelTiles = _world.level_at(2).level_tiles
	below.set_top(SPOT.x, SPOT.y, TileKind.TOP.MINABLE_ROCK)
	below.set_ore(SPOT.x, SPOT.y, TileKind.ORE.COPPER)
	_breach(1)
	assert_eq(_world.level_at(1).level_tiles.get_ground(SPOT.x, SPOT.y), TileKind.GROUND.HOLE,
		"a hole on -1")
	assert_eq(below.get_top(SPOT.x, SPOT.y), TileKind.TOP.OPEN, "open floor below")
	assert_eq(below.get_ore(SPOT.x, SPOT.y), TileKind.ORE.NONE, "the ore went with the rock")
	var args: Array = get_signal_parameters(_world, "tile_breached")
	assert_true((args[1] as WorldPos).equals(_at(1)), "announced, with the floor")


func test_under_tier_is_refused_and_changes_nothing() -> void:
	var below: LevelTiles = _world.level_at(2).level_tiles
	_breach(1, SPOT, 10.0)
	assert_eq(_reason(), World.BREACH_REFUSAL.TOOL_TOO_WEAK, "too weak for -1")
	assert_eq(_world.level_at(1).level_tiles.get_ground(SPOT.x, SPOT.y), TileKind.GROUND.ROCK,
		"no hole")
	assert_signal_not_emitted(_world, "tile_breached")
	assert_eq(below.get_ground(SPOT.x, SPOT.y), TileKind.GROUND.ROCK, "nothing below either")


func test_rock_ramps_and_holes_are_not_plain_floor() -> void:
	var tiles: LevelTiles = _world.level_at(1).level_tiles
	_breach(1, Vector2i(3, 3))
	assert_eq(_reason(), World.BREACH_REFUSAL.NOT_PLAIN_FLOOR, "rock")
	tiles.set_ground(1, 0, TileKind.GROUND.RAMP_DOWN_E)
	_breach(1, Vector2i(1, 0))
	assert_eq(_reason(), World.BREACH_REFUSAL.NOT_PLAIN_FLOOR, "a ramp")
	tiles.set_ground(2, 0, TileKind.GROUND.HOLE)
	_breach(1, Vector2i(2, 0))
	assert_eq(_reason(), World.BREACH_REFUSAL.NOT_PLAIN_FLOOR, "a hole")


func test_a_fixture_or_an_actor_on_the_floor_refuses_it() -> void:
	_world.level_at(1).level_fixtures.add(Fixture.new(ObjectKind.OBJECT.BRAZIER, _at(1), 50))
	_breach(1)
	assert_eq(_reason(), World.BREACH_REFUSAL.FIXTURE_ON_TILE, "a brazier on it")
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Stander", _at(1, Vector2i(-3, 0)),
		_world.level_at(1), ActorKind.ACTOR.NULL)
	_world.add_actor(actor)
	_breach(1, Vector2i(-3, 0))
	assert_eq(_reason(), World.BREACH_REFUSAL.ACTOR_ON_TILE, "nobody falls")


func test_the_landing_must_be_plain_floor_with_nothing_on_it() -> void:
	_world.level_at(2).level_tiles.set_ground(SPOT.x, SPOT.y, TileKind.GROUND.RAMP_UP_E)
	_breach(1)
	assert_eq(_reason(), World.BREACH_REFUSAL.LANDING_BLOCKED, "a ramp below")
	_world.level_at(2).level_fixtures.add(Fixture.new(ObjectKind.OBJECT.LADDER, _at(2, Vector2i(-2, 0)), 51))
	_breach(1, Vector2i(-2, 0))
	assert_eq(_reason(), World.BREACH_REFUSAL.LANDING_BLOCKED, "a fixture below")


func test_no_level_below_and_no_landing_are_refused() -> void:
	_breach(2, SPOT, 999.0)
	assert_eq(_reason(), World.BREACH_REFUSAL.NO_LEVEL_BELOW, "nothing under -2 here")
	# The Surface (radius 90) reaches past -1's disc (radius 64)
	_world.level_at(0).level_tiles.set_top(70, 0, TileKind.TOP.OPEN)
	_breach(0, Vector2i(70, 0))
	assert_eq(_reason(), World.BREACH_REFUSAL.LANDING_NOT_EXISTS, "below is outside -1")


func test_outside_the_level_or_a_missing_level_is_refused() -> void:
	_breach(1, Vector2i(500, 0))
	assert_eq(_reason(), World.BREACH_REFUSAL.TILE_NOT_EXISTS, "past the edge")
	_breach(6)
	assert_eq(_reason(), World.BREACH_REFUSAL.LEVEL_NOT_EXISTS, "no -6 in this world")


func test_a_second_world_is_untouched() -> void:
	var other: World = add_child_autofree(Worlds.with_levels([0, 1, 2]))
	other.level_at(1).level_tiles.set_top(SPOT.x, SPOT.y, TileKind.TOP.OPEN)
	_breach(1)
	assert_eq(other.level_at(1).level_tiles.get_ground(SPOT.x, SPOT.y), TileKind.GROUND.ROCK,
		"the other world's floor")


# --- the capability (D-153) ---

func _breacher(kind: int = ActorKind.ACTOR.PLAYER) -> Actor:
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Breacher", _at(1, SPOT - Vector2i(1, 0)),
		_world.level_at(1), kind)
	_world.add_actor(actor)
	var capability: CapabilityBreach = load("res://src/entity/capabilities/capability_breach.tscn").instantiate()
	capability.actor = actor
	actor.get_node("Capabilities").add_child(capability)
	actor.facing = Vector2i(1, 0)
	return actor


func _capability(actor: Actor) -> CapabilityBreach:
	return actor.get_node("Capabilities/CapabilityBreach")


func _hold(actor: Actor, ticks: int) -> void:
	for i in range(ticks):
		_capability(actor).breach(TICK, FLINT, _at(1), _world.level_at(1))


func test_a_held_breach_takes_its_time_then_asks() -> void:
	var actor: Actor = _breacher()
	var ticks: int = ceili(5.0 / TICK)
	_hold(actor, ticks - 2)
	assert_signal_not_emitted(_world, "tile_breached", "not yet, at 5 s less two ticks")
	_hold(actor, 3)
	assert_signal_emitted(_world, "tile_breached", "about 5 s with flint on -1")
	assert_eq(_capability(actor).progress, 0.0, "and the work starts over")


func test_releasing_loses_the_work() -> void:
	var actor: Actor = _breacher()
	_hold(actor, 30)
	actor.breach_intent = true
	actor.breach(false)
	assert_eq(_capability(actor).progress, 0.0, "released")


# Under-tier is refused at once, and once: not after five seconds, and
# not every tick.
func test_an_under_tier_floor_is_refused_at_once_and_once() -> void:
	var actor: Actor = _breacher()
	for i in range(10):
		_capability(actor).breach(TICK, 10.0, _at(1), _world.level_at(1))
	assert_signal_emit_count(_world, "breach_refused", 1, "one refusal")
	assert_eq(_reason(), World.BREACH_REFUSAL.TOOL_TOO_WEAK, "with the reason")
	assert_eq(_capability(actor).progress, 0.0, "and no work done")


func test_an_npc_breaches_too() -> void:
	var npc: Actor = _breacher(ActorKind.ACTOR.NULL)
	_hold(npc, ceili(5.0 / TICK) + 1)
	assert_eq(_world.level_at(1).level_tiles.get_ground(SPOT.x, SPOT.y), TileKind.GROUND.HOLE,
		"the rule asks nobody who they are")


func test_the_actor_breaches_what_it_faces_while_held() -> void:
	var actor: Actor = _breacher()
	actor.breach(true)
	for i in range(ceili(5.0 / TICK) + 2):
		actor._physics_process(TICK)
	assert_eq(_world.level_at(1).level_tiles.get_ground(SPOT.x, SPOT.y), TileKind.GROUND.HOLE,
		"the faced floor")


# --- telling the player (D-141, D-152) ---

func test_the_followed_actors_refusal_is_shown_and_others_are_not() -> void:
	var view: View = add_child_autofree(View.new())
	var notice: RefusalNotice = add_child_autofree(RefusalNotice.new())
	notice.watch(view)
	var actor: Actor = _breacher()
	view.follow(actor)
	_world.breach_refused.emit(null, _at(1), World.BREACH_REFUSAL.TOOL_TOO_WEAK)
	assert_eq(notice.text, "", "someone else's refusal")
	_world.breach_refused.emit(actor, _at(1), World.BREACH_REFUSAL.TOOL_TOO_WEAK)
	assert_string_contains(notice.text, "too hard", "the player's own, with why")
	notice._process(RefusalNotice.SHOW_SECONDS + 0.1)
	assert_eq(notice.text, "", "and it goes")


# --- showing it work (D-153) ---

func test_cracks_grow_in_stages_with_the_work() -> void:
	assert_eq(BreachCracks.stage_for(0.0, 80.0), 0, "nothing yet")
	assert_eq(BreachCracks.stage_for(1.0, 80.0), 1, "the first crack at once")
	assert_eq(BreachCracks.stage_for(40.0, 80.0), 3, "halfway")
	assert_eq(BreachCracks.stage_for(79.0, 80.0), BreachCracks.STAGES, "all of them near the end")
	assert_eq(BreachCracks.stage_for(5.0, 0.0), 0, "no work, no cracks")


func test_cracks_follow_the_followed_actors_breach() -> void:
	var view: View = add_child_autofree(View.new())
	var cracks: BreachCracks = add_child_autofree(BreachCracks.new())
	cracks.watch(view)
	var actor: Actor = _breacher()
	view.follow(actor)
	_hold(actor, 60)
	cracks._process(TICK)
	assert_gt(cracks.stage, 0, "cracking")
	assert_eq(cracks.tile, SPOT, "on the floor being breached")
	# Drawn for a frame while they show
	await get_tree().process_frame
	actor.breach_intent = true
	actor.breach(false)
	cracks._process(TICK)
	assert_eq(cracks.stage, 0, "gone on release")
