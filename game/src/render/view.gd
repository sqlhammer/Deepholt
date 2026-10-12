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

# No depth is shown until an actor is followed.
const NO_DEPTH: int = -1

var actor: Actor
var shown_depth: int = NO_DEPTH

# Actors whose visibility follows the shown depth. Keyed by instance
# id, so a freed actor is skipped rather than looked up.
var _tracked: Dictionary[int, bool] = {}


func follow(p_actor: Actor) -> void:
	if actor != null and actor.actor_worldpos_changed.is_connected(_on_followed_actor_moved):
		actor.actor_worldpos_changed.disconnect(_on_followed_actor_moved)
	actor = p_actor
	actor.actor_worldpos_changed.connect(_on_followed_actor_moved)
	track(actor)
	_show(actor.depth)


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
	for id: int in _tracked.keys():
		var tracked: Actor = instance_from_id(id) as Actor
		if tracked == null:
			_tracked.erase(id)
			continue
		_update_visibility(tracked)


func _update_visibility(p_actor: Actor) -> void:
	p_actor.visible = p_actor.depth == shown_depth
