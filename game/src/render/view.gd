class_name View
extends Node

# What is on screen (D-094). Follows one actor, the locally controlled
# one, and owns the depth being shown. Presentation only: the
# simulation never asks what is shown, and there is no "current
# depth" anywhere else (NOW.md trap 1).
#
# Also decides which actors are drawn: an actor on another depth is
# hidden, or it would stand in the shown level's rock (trap 2).

signal shown_depth_changed(old_depth: int, new_depth: int)
# A different world is shown (D-129, D-132). The world and the depth
# come together, even when the depth is the one already shown, so a
# listener re-points to both at once. shown_depth_changed isn't also
# emitted for the same move.
signal shown_world_changed(world: World, depth: int)

# No depth is shown until a world is.
const NO_DEPTH: int = -1

# Null while nobody is followed: a world can be shown without one
# (D-132).
var actor: Actor
var shown_depth: int = NO_DEPTH
# The world on screen. Null until one is shown.
var shown_world: World

# Actors whose visibility follows the shown depth. Keyed by instance
# id, so a freed actor is skipped rather than looked up.
var _tracked: Dictionary[int, bool] = {}


# Shows a world at a depth, following nobody (D-132). A swap calls it
# first, so a world is shown even when none of its actors is a
# player.
func show_world(world: World, depth: int) -> void:
	_stop_following()
	_show_world(world, depth)


# Follows an actor. In the world already shown, only the depth
# changes; an actor in another world brings its world with it
# (D-129), reached through its level (D-126).
func follow(p_actor: Actor) -> void:
	_stop_following()
	actor = p_actor
	actor.actor_worldpos_changed.connect(_on_followed_actor_moved)
	track(actor)
	var world: World = actor.current_level.world if actor.current_level else null
	if world != shown_world:
		_show_world(world, actor.depth)
		return
	_show(actor.depth)


# The actor followed before may have been freed with its world.
func _stop_following() -> void:
	if is_instance_valid(actor) and actor.actor_worldpos_changed.is_connected(_on_followed_actor_moved):
		actor.actor_worldpos_changed.disconnect(_on_followed_actor_moved)
	actor = null


# Draws the actor only while it is on the shown depth.
func track(p_actor: Actor) -> void:
	var id: int = p_actor.get_instance_id()
	if not _tracked.has(id):
		_tracked[id] = true
		p_actor.actor_worldpos_changed.connect(_on_tracked_actor_moved)
	_update_visibility(p_actor)


# Called on every tile step; only a change of depth matters here.
func _on_followed_actor_moved(_actor: Actor, _old_pos: WorldPos, new_pos: WorldPos) -> void:
	_show(new_pos.depth)


func _on_tracked_actor_moved(moved: Actor, _old_pos: WorldPos, _new_pos: WorldPos) -> void:
	_update_visibility(moved)


func _show(depth: int) -> void:
	if depth == shown_depth: return
	var old_depth: int = shown_depth
	shown_depth = depth
	shown_depth_changed.emit(old_depth, shown_depth)
	_update_all_visibility()


func _show_world(world: World, depth: int) -> void:
	shown_world = world
	shown_depth = depth
	shown_world_changed.emit(shown_world, shown_depth)
	_update_all_visibility()


func _update_all_visibility() -> void:
	for id: int in _tracked.keys():
		var tracked: Actor = instance_from_id(id) as Actor
		if tracked == null:
			_tracked.erase(id)
			continue
		_update_visibility(tracked)


func _update_visibility(p_actor: Actor) -> void:
	p_actor.visible = p_actor.depth == shown_depth
