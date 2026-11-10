class_name WorldLog
extends RefCounted

# The world's answers, ceilings, and generation, in the debug log
# (D-193, D-196), heard through the world's own signals: nothing in
# the world calls the log. Watched once per world, when the game takes
# it in. Actors by id, reasons by name.
#
# Answers, not requests: the world answers a request inside its own
# handler, before a listener added later hears the request, so the
# request's line would follow its answer's. Every dig, breach, chop
# and placement ends in exactly one result or refusal, which carries
# the actor and the tile.


static func watch(world: World) -> void:
	if not Log.enabled or world == null: return
	var w: StringName = Log.WORLD
	world.tile_dug.connect(func(a: Actor, t: WorldPos) -> void:
		Log.event(w, &"dug", {"actor": Log.actor_id(a), "tile": Log.pos(t)}))
	world.dig_refused.connect(func(a: Actor, t: WorldPos, r: int) -> void:
		Log.event(w, &"dig_refused", {"actor": Log.actor_id(a), "tile": Log.pos(t),
			"reason": World.DIG_REFUSAL.find_key(r)}))
	world.tile_breached.connect(func(a: Actor, t: WorldPos) -> void:
		Log.event(w, &"breached", {"actor": Log.actor_id(a), "tile": Log.pos(t)}))
	world.breach_refused.connect(func(a: Actor, t: WorldPos, r: int) -> void:
		Log.event(w, &"breach_refused", {"actor": Log.actor_id(a), "tile": Log.pos(t),
			"reason": World.BREACH_REFUSAL.find_key(r)}))
	world.tree_felled.connect(func(a: Actor, t: WorldPos) -> void:
		Log.event(w, &"felled", {"actor": Log.actor_id(a), "tile": Log.pos(t)}))
	world.chop_refused.connect(func(a: Actor, t: WorldPos, r: int) -> void:
		Log.event(w, &"chop_refused", {"actor": Log.actor_id(a), "tile": Log.pos(t),
			"reason": World.CHOP_REFUSAL.find_key(r)}))
	world.items_dropped.connect(func(a: Actor, t: WorldPos, id: StringName, count: int) -> void:
		Log.event(w, &"dropped", {"actor": Log.actor_id(a), "tile": Log.pos(t), "item": id,
			"count": count}))
	world.items_picked_up.connect(func(a: Actor, t: WorldPos, id: StringName, count: int) -> void:
		Log.event(w, &"picked_up", {"actor": Log.actor_id(a), "tile": Log.pos(t), "item": id,
			"count": count}))
	world.took.connect(func(a: Actor, items: Dictionary) -> void:
		Log.event(w, &"took", {"actor": Log.actor_id(a), "items": items.duplicate()}))
	world.climb_refused.connect(func(a: Actor, t: WorldPos) -> void:
		Log.event(w, &"climb_refused", {"actor": Log.actor_id(a), "tile": Log.pos(t)}))
	world.fixture_placed.connect(func(a: Actor, f: Fixture) -> void:
		Log.event(w, &"placed", {"actor": Log.actor_id(a), "fixture": f.id,
			"kind": ObjectKind.display_name(f.kind), "tile": Log.pos(f.tile)}))
	world.fixture_removed.connect(func(a: Actor, f: Fixture) -> void:
		Log.event(w, &"removed", {"actor": Log.actor_id(a), "fixture": f.id,
			"kind": ObjectKind.display_name(f.kind), "tile": Log.pos(f.tile)}))
	world.request_refused.connect(func(a: Actor, verb: int, t: WorldPos, r: int) -> void:
		Log.event(w, &"request_refused", {"actor": Log.actor_id(a),
			"verb": World.FIXTURE_VERB.find_key(verb), "tile": Log.pos(t),
			"reason": World.FIXTURE_REFUSAL.find_key(r)}))
	var s: StringName = Log.SUPPORT
	world.ceiling_failing.connect(func(depth: int, tiles: Array[Vector2i]) -> void:
		Log.event(s, &"failing", {"depth": depth, "tiles": tiles.size(),
			"first": [tiles[0].x, tiles[0].y] if not tiles.is_empty() else []}))
	world.collapsed.connect(func(depth: int, tiles: Array[Vector2i]) -> void:
		Log.event(s, &"collapsed", {"depth": depth, "tiles": tiles.size(),
			"first": [tiles[0].x, tiles[0].y] if not tiles.is_empty() else []}))
	world.actor_moved_clear.connect(func(a: Actor, from: WorldPos, to: WorldPos) -> void:
		Log.event(s, &"moved_clear", {"actor": Log.actor_id(a), "from": Log.pos(from),
			"to": Log.pos(to)}))
	# Announced before the world records how long it took: read after
	world.level_added.connect(func(level: Level) -> void:
		var depth: int = level.depth
		(func() -> void:
			if is_instance_valid(world):
				Log.event(Log.PERF, &"level_generated", {"depth": depth,
					"msec": world.last_generation_msec})).call_deferred())
