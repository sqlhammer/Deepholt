class_name Building
extends RefCounted

# What building costs (D-156, D-159): one rule, asked by the fixture
# gatekeeper before it places and by build mode's preview, so the two
# can't disagree (slice 008 trap 4). Stateless; the costs are the
# profile's. A placement with no actor (generation, a load) is free.


# What placing a fixture of `kind` costs, item id -> count. Nothing
# for a kind with no cost.
static func cost_of(tuning: TuningProfile, kind: int) -> Dictionary[StringName, int]:
	match kind:
		ObjectKind.OBJECT.LADDER: return tuning.ladder_cost
	var free: Dictionary[StringName, int] = {}
	return free


static func can_afford(tuning: TuningProfile, actor: Actor, kind: int) -> bool:
	if actor == null: return true
	var cost: Dictionary[StringName, int] = cost_of(tuning, kind)
	for id: StringName in cost:
		if not actor.pack.has(id, cost[id]): return false
	return true


# Takes the cost from the actor's pack. Call only after can_afford.
static func pay(tuning: TuningProfile, actor: Actor, kind: int) -> void:
	if actor == null: return
	var cost: Dictionary[StringName, int] = cost_of(tuning, kind)
	for id: StringName in cost:
		actor.pack.remove(id, cost[id])


# "4 timber", for the preview; "" for a free kind.
static func cost_text(tuning: TuningProfile, kind: int) -> String:
	var cost: Dictionary[StringName, int] = cost_of(tuning, kind)
	var parts: PackedStringArray = []
	for id: StringName in cost:
		var item: Item = ItemRegistry.find(id)
		var name: String = item.display_key.to_lower() if item != null else String(id)
		parts.append("%d %s" % [cost[id], name])
	return ", ".join(parts)
