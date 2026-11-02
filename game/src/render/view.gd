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
# The followed actor changed depth, and the screen fades through black
# while the shown depth switches (D-142). Input waits for the end.
signal transition_started
signal transition_ended
# 0 is clear, 1 is black. Whatever draws the fade follows this.
signal fade_changed(fade: float)

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

# Whether a depth change fades (D-142). The game turns it on; a view
# made on its own switches at once, which is what most tests want.
var transitions: bool = false
var fade: float = 0.0
# The fade in progress: how far in, how long in all, and the depth it
# switches to at the midpoint. NO_DEPTH once it has switched.
var _transition_elapsed: float = -1.0
var _transition_seconds: float = 0.0
var _transition_depth: int = NO_DEPTH


# Shows a world at a depth, following nobody (D-132). A swap calls it
# first, so a world is shown even when none of its actors is a
# player.
func show_world(world: World, depth: int) -> void:
	_stop_following()
	_end_transition()
	_show_world(world, depth)


# Follows an actor. In the world already shown, only the depth
# changes; an actor in another world brings its world with it
# (D-129), reached through its level (D-126).
func follow(p_actor: Actor) -> void:
	_stop_following()
	_end_transition()
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
func _on_followed_actor_moved(_actor: Actor, old_pos: WorldPos, new_pos: WorldPos) -> void:
	if old_pos != null and old_pos.depth == new_pos.depth: return
	var seconds: float = shown_world.tuning.level_change_fade_seconds if shown_world else 0.0
	if not transitions or seconds <= 0.0:
		_show(new_pos.depth)
		return
	_start_transition(new_pos.depth, seconds)


# --- the fade (D-142) ---

func is_transitioning() -> bool:
	return _transition_elapsed >= 0.0


func _start_transition(depth: int, seconds: float) -> void:
	var already: bool = is_transitioning()
	# Moved again mid-fade: past the midpoint, the screen is already
	# showing a level, so switch to the new one now
	if already and _transition_depth == NO_DEPTH:
		_show(depth)
		return
	_transition_depth = depth
	if already: return
	_transition_seconds = seconds
	_transition_elapsed = 0.0
	transition_started.emit()


func _process(delta: float) -> void:
	if is_transitioning(): advance_transition(delta)


# Moves the fade on by `delta` seconds. Called each frame; a test
# calls it directly.
func advance_transition(delta: float) -> void:
	if not is_transitioning(): return
	_transition_elapsed += delta
	var half: float = _transition_seconds / 2.0
	if _transition_elapsed < half:
		_set_fade(_transition_elapsed / half)
		return
	if _transition_depth != NO_DEPTH:
		_show(_transition_depth)
		_transition_depth = NO_DEPTH
	if _transition_elapsed < _transition_seconds:
		_set_fade(1.0 - (_transition_elapsed - half) / half)
		return
	_end_transition()


# Ends a fade at once, switching to its depth if it hadn't yet. A
# swap ends one this way, since its new world is shown at once.
func _end_transition() -> void:
	if not is_transitioning(): return
	_transition_elapsed = -1.0
	_transition_depth = NO_DEPTH
	_set_fade(0.0)
	transition_ended.emit()


func finish_transition() -> void:
	if _transition_depth != NO_DEPTH: _show(_transition_depth)
	_end_transition()


func _set_fade(value: float) -> void:
	fade = clampf(value, 0.0, 1.0)
	fade_changed.emit(fade)


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


# The followed actor is always drawn, even while a fade still shows
# the depth it left (D-142).
func _update_visibility(p_actor: Actor) -> void:
	p_actor.visible = p_actor.depth == shown_depth or p_actor == actor
