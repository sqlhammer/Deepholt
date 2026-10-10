extends GutTest

# CapabilityDig: digging a tile over time (D-071). Progress builds
# while dig() is called each tick, resets on release and when the
# target changes (D-072), and the tile is announced as dug once
# progress reaches its density. Dig time = density / tool speed, so
# rock (5) with a speed-10 tool takes 0.5 s.
#
# The level is all minable rock by default; tests open or re-kind
# the few tiles they need.

const SPEED: float = 10.0
const TICK: float = 0.1  # one tick adds SPEED * TICK = 1.0 progress

const ROCK_TILE: Vector2i = Vector2i(1, 0)
const DIRT_TILE: Vector2i = Vector2i(2, 0)
const OPEN_TILE: Vector2i = Vector2i(3, 0)

var _level: Level
var _actor: Actor
var _dig: CapabilityDig


func before_each() -> void:
	_level = Global.level_packed_scene.instantiate()
	_level.setup(0)
	add_child_autofree(_level)
	_level.level_tiles.set_top(DIRT_TILE.x, DIRT_TILE.y, TileKind.TOP.MINABLE_DIRT)
	_level.level_tiles.set_top(OPEN_TILE.x, OPEN_TILE.y, TileKind.TOP.OPEN)

	_actor = Actor.create(Global.actor_packed_scene, "Digger", WorldPos.new(0, 0, 0))
	add_child_autofree(_actor)
	_dig = _new_capability(_actor)


# A dig capability on `actor`, in the tree so its _ready connects
# to the actor's action_ended and to World.dig_requested.
func _new_capability(actor: Actor) -> CapabilityDig:
	var capability: CapabilityDig = Global.get_capability_packedscene(
		Global.CAPABILITY.DIG).instantiate()
	capability.actor = actor
	actor.get_node("Capabilities").add_child(capability)
	return capability


func _at(tile: Vector2i) -> WorldPos:
	return WorldPos.new(tile.x, tile.y, 0)


func _tick(tile: Vector2i, times: int = 1) -> void:
	for i in range(times):
		_dig.dig(TICK, SPEED, _at(tile), _level)


func _density(kind_name: String) -> float:
	return TileKind.MINABLE_DENSITY[kind_name].density


# --- building progress ---

func test_digging_rock_builds_progress() -> void:
	_tick(ROCK_TILE)
	assert_almost_eq(_dig.progress, SPEED * TICK, 0.0001,
		"one tick adds tool speed x delta")


func test_progress_keeps_building_on_the_same_tile() -> void:
	_tick(ROCK_TILE, 3)
	assert_almost_eq(_dig.progress, 3 * SPEED * TICK, 0.0001,
		"three ticks on one tile add up")


func test_digging_uses_the_tiles_density() -> void:
	_tick(DIRT_TILE)
	assert_eq(_dig.tile_density, _density("MINABLE_DIRT"), "dirt's density")
	_dig._reset_progress()
	_tick(ROCK_TILE)
	assert_eq(_dig.tile_density, _density("MINABLE_ROCK"), "rock's density")


# --- what can't be dug ---

func test_an_open_tile_is_not_dug() -> void:
	_tick(OPEN_TILE, 3)
	assert_eq(_dig.progress, 0.0, "open floor gains no progress")


func test_outside_the_level_is_not_dug() -> void:
	# (90, 1) is inside the array but outside Surface's radial bounds.
	_dig.dig(TICK, SPEED, WorldPos.new(90, 1, 0), _level)
	assert_eq(_dig.progress, 0.0, "the edge of the level can't be dug")


func test_aiming_at_something_undiggable_drops_progress() -> void:
	_tick(ROCK_TILE, 2)
	_tick(OPEN_TILE)
	assert_eq(_dig.progress, 0.0, "progress on rock is lost on open floor")


# TileKind is the one owner of "diggable" (it reads MINABLE_DENSITY).
# The capability's density lookup and LevelTiles.is_diggable must
# agree with it for every top kind, so nothing drifts from the owner.
func test_every_place_agrees_on_what_is_diggable() -> void:
	for kind_name: String in TileKind.TOP:
		var kind: int = TileKind.TOP[kind_name]
		var probe: CapabilityDig = CapabilityDig.new()
		autofree(probe)
		var diggable: bool = TileKind.is_diggable(kind)
		var has_density: bool = probe._set_tile_density(kind)
		_level.level_tiles.set_top(5, 0, kind)
		var level_says: bool = _level.level_tiles.is_diggable(WorldPos.new(5, 0, 0))
		assert_eq(has_density, diggable,
			"%s: diggable and has-a-density agree" % kind_name)
		assert_eq(level_says, diggable,
			"%s: LevelTiles.is_diggable agrees" % kind_name)


# --- finishing a dig ---

func test_a_dig_completes_at_density_over_speed() -> void:
	var ticks: int = ceili(_density("MINABLE_ROCK") / (SPEED * TICK))
	watch_signals(World)
	_tick(ROCK_TILE, ticks - 1)
	assert_signal_not_emitted(World, "dig_requested", "not done one tick early")
	_tick(ROCK_TILE)
	assert_signal_emitted(World, "dig_requested", "done on the tick progress reaches density")


func test_a_completed_dig_names_the_actor_and_the_tile() -> void:
	watch_signals(World)
	_tick(ROCK_TILE, ceili(_density("MINABLE_ROCK") / (SPEED * TICK)))
	var params: Array = get_signal_parameters(World, "dig_requested")
	assert_eq(params.size(), 2, "dig_requested carries (actor, tile)")
	if params.size() == 2:
		assert_eq(params[0], _actor, "the digging actor")
		assert_true(params[1].equals(_at(ROCK_TILE)), "the dug tile")


func test_softer_ground_digs_faster() -> void:
	var dirt_ticks: int = ceili(_density("MINABLE_DIRT") / (SPEED * TICK))
	watch_signals(World)
	_tick(DIRT_TILE, dirt_ticks)
	assert_signal_emitted(World, "dig_requested", "dirt is done in fewer ticks than rock")


func test_progress_resets_after_completing_a_dig() -> void:
	_tick(ROCK_TILE, ceili(_density("MINABLE_ROCK") / (SPEED * TICK)))
	assert_eq(_dig.progress, 0.0, "the next tile starts from zero")


func test_another_actors_completed_dig_leaves_progress_alone() -> void:
	_tick(ROCK_TILE, 2)
	var other: Actor = Actor.create(Global.actor_packed_scene, "Other", WorldPos.new(0, 0, 0))
	autofree(other)
	_dig._on_tile_dug(other, _at(DIRT_TILE))
	assert_almost_eq(_dig.progress, 2 * SPEED * TICK, 0.0001,
		"someone else finishing a tile doesn't reset this actor")


# --- resets (D-071, D-072) ---

func test_changing_target_resets_progress() -> void:
	_tick(ROCK_TILE, 3)
	_dig.dig(TICK, SPEED, WorldPos.new(ROCK_TILE.x, ROCK_TILE.y + 1, 0), _level)
	assert_almost_eq(_dig.progress, SPEED * TICK, 0.0001,
		"a new tile starts from zero, plus this tick")


func test_releasing_the_dig_resets_progress() -> void:
	_tick(ROCK_TILE, 3)
	_actor.action_ended.emit("dig")
	assert_eq(_dig.progress, 0.0, "letting go loses the progress")


func test_ending_some_other_action_leaves_progress_alone() -> void:
	_tick(ROCK_TILE, 3)
	_dig.action_ended("swing")
	assert_almost_eq(_dig.progress, 3 * SPEED * TICK, 0.0001,
		"only the dig verb's release resets digging")


func test_after_a_release_the_same_tile_starts_over() -> void:
	_tick(ROCK_TILE, 3)
	_actor.action_ended.emit("dig")
	_tick(ROCK_TILE)
	assert_almost_eq(_dig.progress, SPEED * TICK, 0.0001,
		"pressing again on the same tile counts from zero")


# --- end to end: outcome 3, the data half ---

# Holding dig on rock until it finishes leaves the tile open in the
# level's data. (The screen half is LevelRenderer's job.)
func test_digging_rock_to_completion_opens_it() -> void:
	_tick(ROCK_TILE, ceili(_density("MINABLE_ROCK") / (SPEED * TICK)))
	assert_eq(_level.level_tiles.get_top(ROCK_TILE.x, ROCK_TILE.y), TileKind.TOP.OPEN,
		"the rock is gone")


func test_digging_on_after_completion_does_nothing_more() -> void:
	_tick(ROCK_TILE, ceili(_density("MINABLE_ROCK") / (SPEED * TICK)))
	watch_signals(World)
	_tick(ROCK_TILE, 3)
	assert_signal_not_emitted(World, "dig_requested",
		"the tile is open now, so holding on asks for nothing")
	assert_eq(_dig.progress, 0.0, "and builds no progress")


# --- refusals (D-078) ---

func test_a_refused_dig_resets_progress() -> void:
	_tick(ROCK_TILE, 3)
	World.dig_refused.emit(_actor, _at(ROCK_TILE),
		World.REFUSAL_REASON.TILE_NOT_DIGGABLE)
	assert_eq(_dig.progress, 0.0,
		"refused, so it doesn't sit at full progress and ask every tick")


func test_another_actors_refusal_leaves_progress_alone() -> void:
	_tick(ROCK_TILE, 3)
	var other: Actor = autofree(Actor.new())
	World.dig_refused.emit(other, _at(ROCK_TILE),
		World.REFUSAL_REASON.TILE_NOT_DIGGABLE)
	assert_almost_eq(_dig.progress, 3 * SPEED * TICK, 0.0001,
		"someone else's refusal is not this actor's")


# --- the completion check itself ---

func test_dig_is_complete_exactly_at_density() -> void:
	_dig.tile_density = 5.0
	_dig.progress = 4.999
	assert_false(_dig._is_dig_complete(), "just under is not done")
	_dig.progress = 5.0
	assert_true(_dig._is_dig_complete(), "reaching density is done")
