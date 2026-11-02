extends GutTest

# Changing depth (D-093) and following it on screen (D-094). An actor
# moves itself onto another level, checking only that it can stand
# there, and announces it as an ordinary change of tile. A View
# follows one actor and owns the depth on screen; nothing else has a
# "current depth" (NOW.md trap 1), and actors on other depths aren't
# drawn (trap 2).

const OPEN_TILE: Vector2i = Vector2i(2, -3)


var _world: World


func before_each() -> void:
	_world = add_child_autofree(World.new())
	for depth in [0, 1, 2]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		_world.add_level(level)
		# Solid rock everywhere but one tile, open on every level.
		level.level_tiles.set_top(OPEN_TILE.x, OPEN_TILE.y, TileKind.TOP.OPEN)


func _actor_at(tile: Vector2i, depth: int) -> Actor:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "Test", WorldPos.new(tile.x, tile.y, depth), _world.level_at(depth), ActorKind.ACTOR.PLAYER)
	_world.add_actor(actor)
	return actor


func _view_following(actor: Actor) -> View:
	var view: View = View.new()
	add_child_autofree(view)
	view.follow(actor)
	return view


# --- the actor (D-093) ---

func test_changing_depth_keeps_x_and_y() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	assert_true(actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1)), "the move is made")
	assert_eq(actor.depth, 1, "the actor is on -1")
	assert_eq(actor.current_WorldPos.x, OPEN_TILE.x, "same x")
	assert_eq(actor.current_WorldPos.y, OPEN_TILE.y, "same y")
	assert_eq(actor.current_WorldPos.depth, 1, "and its WorldPos says -1")
	assert_eq(actor.current_level, _world.level_at(1), "it collides with -1 now")


func test_a_depth_change_is_announced_once_with_the_final_tile() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	watch_signals(actor)
	actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 2))
	assert_signal_emit_count(actor, "actor_worldpos_changed", 1, "one announcement")
	var args: Array = get_signal_parameters(actor, "actor_worldpos_changed")
	assert_eq(args[1].depth, 0, "from the Surface")
	assert_eq(args[2].depth, 2, "to -2")
	assert_eq(Vector2i(args[2].x, args[2].y), OPEN_TILE, "at the same tile")


func test_a_blocked_landing_is_refused_and_changes_nothing() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	_world.level_at(1).level_tiles.set_top(OPEN_TILE.x, OPEN_TILE.y, TileKind.TOP.MINABLE_ROCK)
	var position_before: Vector2 = actor.position
	watch_signals(actor)
	assert_false(actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1)), "refused")
	assert_eq(actor.depth, 0, "still on the Surface")
	assert_eq(actor.position, position_before, "not moved")
	assert_signal_not_emitted(actor, "actor_worldpos_changed", "nothing announced")


func test_a_depth_with_no_level_is_refused() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	assert_false(actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 99)), "no level at 99")
	assert_eq(actor.depth, 0, "still on the Surface")


func test_setting_depth_on_a_placed_actor_announces_it() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	watch_signals(actor)
	actor.depth = 1
	assert_signal_emit_count(actor, "actor_worldpos_changed", 1, "set_depth fires the signal")


# --- the view (D-094) ---

func test_following_an_actor_shows_its_depth() -> void:
	var view: View = _view_following(_actor_at(OPEN_TILE, 1))
	assert_eq(view.shown_depth, 1, "the view shows the actor's depth")


func test_the_view_follows_its_actor_down() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	var view: View = _view_following(actor)
	watch_signals(view)
	actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_eq(view.shown_depth, 1, "the view moved with its actor")
	assert_signal_emitted_with_parameters(view, "shown_depth_changed", [0, 1])


func test_another_actor_changing_depth_does_not_move_the_view() -> void:
	var followed: Actor = _actor_at(OPEN_TILE, 0)
	var other: Actor = _actor_at(OPEN_TILE, 0)
	var view: View = _view_following(followed)
	view.track(other)
	watch_signals(view)
	other.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_eq(view.shown_depth, 0, "the screen stays where the local actor is")
	assert_signal_not_emitted(view, "shown_depth_changed", "no change announced")


func test_an_ordinary_step_does_not_change_the_shown_depth() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	_world.level_at(0).level_tiles.set_top(OPEN_TILE.x + 1, OPEN_TILE.y, TileKind.TOP.OPEN)
	var view: View = _view_following(actor)
	watch_signals(view)
	actor.position.x += TileSpace.TILE_PIXELS
	actor._update_WorldPos()
	assert_signal_not_emitted(view, "shown_depth_changed", "a step on the same level")


func test_an_actor_on_another_depth_is_not_drawn() -> void:
	var followed: Actor = _actor_at(OPEN_TILE, 0)
	var other: Actor = _actor_at(OPEN_TILE, 0)
	var view: View = _view_following(followed)
	view.track(other)
	assert_true(other.visible, "drawn while on the shown depth")
	other.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_false(other.visible, "hidden once it leaves")
	followed.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_true(other.visible, "drawn again when the view reaches its depth")


func test_the_followed_actor_is_always_drawn() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	_view_following(actor)
	actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 2))
	assert_true(actor.visible, "the view is always on its own actor's depth")


# --- digging stays on its depth ---

func test_a_dig_on_one_depth_changes_only_that_depth() -> void:
	var tile: Vector2i = Vector2i(5, 5)
	_world.dig_requested.emit(autofree(Actor.new()), WorldPos.new(tile.x, tile.y, 1))
	assert_eq(_world.level_at(1).level_tiles.get_top(tile.x, tile.y), TileKind.TOP.OPEN,
		"dug on -1")
	for depth in [0, 2]:
		assert_eq(_world.level_at(depth).level_tiles.get_top(tile.x, tile.y),
			TileKind.TOP.MINABLE_ROCK, "untouched at depth %d" % depth)


func test_a_freed_actor_is_dropped_from_the_view() -> void:
	var followed: Actor = _actor_at(OPEN_TILE, 0)
	var other: Actor = Actor.create(Global.actor_packed_scene, "Gone", WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 0), _world.level_at(0), ActorKind.ACTOR.PLAYER)
	_world.add_actor(other)
	var view: View = _view_following(followed)
	view.track(other)
	other.free()
	followed.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_eq(view._tracked.size(), 1, "only the followed actor is still tracked")


# --- a different world (D-129) ---

# An actor at the open tile in a second world, at the same depths.
func _actor_in_other_world(depth: int) -> Actor:
	var other: World = add_child_autofree(World.new())
	for level_depth in [0, 1, 2]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(level_depth)
		level.level_tiles.set_top(OPEN_TILE.x, OPEN_TILE.y, TileKind.TOP.OPEN)
		other.add_level(level)
	var actor: Actor = Actor.create(Global.actor_packed_scene, "Other",
		WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, depth), other.level_at(depth), ActorKind.ACTOR.PLAYER)
	other.add_actor(actor)
	return actor


func test_following_an_actor_in_another_world_announces_the_world() -> void:
	var view: View = _view_following(_actor_at(OPEN_TILE, 0))
	var other: Actor = _actor_in_other_world(0)
	watch_signals(view)
	view.follow(other)
	assert_eq(get_signal_parameters(view, "shown_world_changed"),
		[other.current_level.world, 0], "the world and the depth, together")
	assert_signal_not_emitted(view, "shown_depth_changed", "the depth didn't change")
	assert_eq(view.shown_world, other.current_level.world, "the other world is shown")


func test_following_another_actor_in_the_same_world_doesnt() -> void:
	var view: View = _view_following(_actor_at(OPEN_TILE, 0))
	var second: Actor = _actor_at(OPEN_TILE, 1)
	watch_signals(view)
	view.follow(second)
	assert_signal_not_emitted(view, "shown_world_changed", "same world")
	assert_signal_emitted(view, "shown_depth_changed", "only the depth changed")


# D-132: a world is shown without anyone to follow, and the actor
# followed before is let go.
func test_showing_a_world_follows_nobody() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	var view: View = _view_following(actor)
	var other: Actor = _actor_in_other_world(2)
	watch_signals(view)
	view.show_world(other.current_level.world, 1)
	assert_eq(get_signal_parameters(view, "shown_world_changed"),
		[other.current_level.world, 1], "the world, at the depth given")
	assert_null(view.actor, "nobody is followed")
	actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 2))
	assert_eq(view.shown_depth, 1, "the old actor's moves no longer move the view")


# After a swap has shown the world, following its player moves only
# the depth (D-132).
func test_following_an_actor_in_the_shown_world_moves_only_the_depth() -> void:
	var view: View = View.new()
	add_child_autofree(view)
	view.show_world(_world, 0)
	watch_signals(view)
	view.follow(_actor_at(OPEN_TILE, 2))
	assert_signal_not_emitted(view, "shown_world_changed", "the world was already shown")
	assert_eq(get_signal_parameters(view, "shown_depth_changed"), [0, 2], "only the depth")


# --- the fade (D-142) ---

func _fading_view(actor: Actor) -> View:
	var view: View = _view_following(actor)
	view.transitions = true
	return view


func test_a_view_without_transitions_switches_at_once() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	var view: View = _view_following(actor)
	actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_false(view.is_transitioning(), "no fade")
	assert_eq(view.shown_depth, 1, "the depth switches")


func test_a_move_within_a_level_starts_no_fade() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	var view: View = _fading_view(actor)
	watch_signals(view)
	actor.actor_worldpos_changed.emit(actor, WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 0),
		WorldPos.new(OPEN_TILE.x + 1, OPEN_TILE.y, 0))
	assert_signal_not_emitted(view, "transition_started")


func test_the_fade_is_announced_start_and_end() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	var view: View = _fading_view(actor)
	watch_signals(view)
	actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_signal_emitted(view, "transition_started")
	view.advance_transition(_world.tuning.level_change_fade_seconds)
	assert_signal_emitted(view, "transition_ended")
	assert_eq(view.shown_depth, 1, "on the new depth")


# Down again before the fade switched: the fade goes on, and switches
# to the latest depth.
func test_a_second_change_mid_fade_switches_to_the_latest_depth() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	var view: View = _fading_view(actor)
	watch_signals(view)
	actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 2))
	assert_signal_emit_count(view, "transition_started", 1, "one fade")
	view.finish_transition()
	assert_eq(view.shown_depth, 2, "the latest depth")


# Past the midpoint a level is already on screen, so another change
# switches at once, and the fade carries on.
func test_a_change_after_the_midpoint_switches_at_once() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	var view: View = _fading_view(actor)
	actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	view.advance_transition(_world.tuning.level_change_fade_seconds * 0.75)
	assert_eq(view.shown_depth, 1, "switched at the midpoint")
	actor.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 2))
	assert_eq(view.shown_depth, 2, "the next change shows at once")
	assert_true(view.is_transitioning(), "while the fade finishes")


# An actor that isn't followed changes nothing on screen.
func test_another_actors_level_change_starts_no_fade() -> void:
	var view: View = _fading_view(_actor_at(OPEN_TILE, 0))
	var other: Actor = _actor_at(OPEN_TILE, 0)
	view.track(other)
	other.move_to(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_false(view.is_transitioning(), "no fade")
	assert_false(other.visible, "and it's hidden on a depth not shown")


func test_the_first_follow_announces_the_world() -> void:
	var view: View = View.new()
	add_child_autofree(view)
	watch_signals(view)
	var actor: Actor = _actor_at(OPEN_TILE, 1)
	view.follow(actor)
	assert_signal_emitted_with_parameters(view, "shown_world_changed", [_world, 1])
