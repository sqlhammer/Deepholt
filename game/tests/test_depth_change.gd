extends GutTest

# Changing depth (D-093) and following it on screen (D-094). An actor
# moves itself onto another level, checking only that it can stand
# there, and announces it as an ordinary change of tile. A View follows
# one actor and owns the depth on screen; nothing else has a "current
# depth" (NOW.md trap 1), and actors on other depths aren't drawn
# (trap 2).

const OPEN_TILE: Vector2i = Vector2i(2, -3)


func before_each() -> void:
	for depth in [0, 1, 2]:
		var level: Level = Global.level_packed_scene.instantiate()
		level.setup(depth)
		add_child_autofree(level)
		# Solid rock everywhere but one tile, open on every level.
		level.level_tiles.set_top(OPEN_TILE.x, OPEN_TILE.y, TileKind.TOP.OPEN)


func _actor_at(tile: Vector2i, depth: int) -> Actor:
	var actor: Actor = Actor.create(
		Global.actor_packed_scene, "Test", WorldPos.new(tile.x, tile.y, depth))
	add_child_autofree(actor)
	return actor


func _view_following(actor: Actor) -> View:
	var view: View = View.new()
	add_child_autofree(view)
	view.follow(actor)
	return view


# --- the actor (D-093) ---

func test_changing_depth_keeps_x_and_y() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	assert_true(actor.change_depth(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1)), "the move is made")
	assert_eq(actor.depth, 1, "the actor is on -1")
	assert_eq(actor.current_WorldPos.x, OPEN_TILE.x, "same x")
	assert_eq(actor.current_WorldPos.y, OPEN_TILE.y, "same y")
	assert_eq(actor.current_WorldPos.depth, 1, "and its WorldPos says -1")
	assert_eq(actor.current_level, World.get_level_by_depth(1), "it collides with -1 now")


func test_a_depth_change_is_announced_once_with_the_final_tile() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	watch_signals(actor)
	actor.change_depth(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 2))
	assert_signal_emit_count(actor, "actor_worldpos_changed", 1, "one announcement")
	var args: Array = get_signal_parameters(actor, "actor_worldpos_changed")
	assert_eq(args[1].depth, 0, "from the Surface")
	assert_eq(args[2].depth, 2, "to -2")
	assert_eq(Vector2i(args[2].x, args[2].y), OPEN_TILE, "at the same tile")


func test_a_blocked_landing_is_refused_and_changes_nothing() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	World.get_level_by_depth(1).level_tiles.set_top(OPEN_TILE.x, OPEN_TILE.y, TileKind.TOP.MINABLE_ROCK)
	var position_before: Vector2 = actor.position
	watch_signals(actor)
	assert_false(actor.change_depth(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1)), "refused")
	assert_eq(actor.depth, 0, "still on the Surface")
	assert_eq(actor.position, position_before, "not moved")
	assert_signal_not_emitted(actor, "actor_worldpos_changed", "nothing announced")


func test_a_depth_with_no_level_is_refused() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	assert_false(actor.change_depth(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 99)), "no level at 99")
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
	actor.change_depth(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_eq(view.shown_depth, 1, "the view moved with its actor")
	assert_signal_emitted_with_parameters(view, "shown_depth_changed", [0, 1])


func test_another_actor_changing_depth_does_not_move_the_view() -> void:
	var followed: Actor = _actor_at(OPEN_TILE, 0)
	var other: Actor = _actor_at(OPEN_TILE, 0)
	var view: View = _view_following(followed)
	view.track(other)
	watch_signals(view)
	other.change_depth(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_eq(view.shown_depth, 0, "the screen stays where the local actor is")
	assert_signal_not_emitted(view, "shown_depth_changed", "no change announced")


func test_an_ordinary_step_does_not_change_the_shown_depth() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	World.get_level_by_depth(0).level_tiles.set_top(OPEN_TILE.x + 1, OPEN_TILE.y, TileKind.TOP.OPEN)
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
	other.change_depth(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_false(other.visible, "hidden once it leaves")
	followed.change_depth(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 1))
	assert_true(other.visible, "drawn again when the view reaches its depth")


func test_the_followed_actor_is_always_drawn() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	_view_following(actor)
	actor.change_depth(WorldPos.new(OPEN_TILE.x, OPEN_TILE.y, 2))
	assert_true(actor.visible, "the view is always on its own actor's depth")


# --- digging stays on its depth ---

func test_a_dig_on_one_depth_changes_only_that_depth() -> void:
	var tile: Vector2i = Vector2i(5, 5)
	World.dig_requested.emit(autofree(Actor.new()), WorldPos.new(tile.x, tile.y, 1))
	assert_eq(World.get_level_by_depth(1).level_tiles.get_top(tile.x, tile.y), TileKind.TOP.OPEN,
		"dug on -1")
	for depth in [0, 2]:
		assert_eq(World.get_level_by_depth(depth).level_tiles.get_top(tile.x, tile.y),
			TileKind.TOP.MINABLE_ROCK, "untouched at depth %d" % depth)


# --- the debug key ---

func test_the_debug_key_steps_down_and_up() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	var debug_depth: DebugDepth = DebugDepth.new()
	add_child_autofree(debug_depth)
	debug_depth.setup(actor)
	assert_true(debug_depth.step(1), "down to -1")
	assert_eq(actor.depth, 1, "on -1")
	assert_true(debug_depth.step(-1), "back up")
	assert_eq(actor.depth, 0, "on the Surface")


func test_the_debug_key_refuses_a_blocked_landing() -> void:
	var actor: Actor = _actor_at(OPEN_TILE, 0)
	World.get_level_by_depth(1).level_tiles.set_top(OPEN_TILE.x, OPEN_TILE.y, TileKind.TOP.MINABLE_ROCK)
	var debug_depth: DebugDepth = DebugDepth.new()
	add_child_autofree(debug_depth)
	debug_depth.setup(actor)
	assert_false(debug_depth.step(1), "refused")
	assert_eq(actor.depth, 0, "still on the Surface")
