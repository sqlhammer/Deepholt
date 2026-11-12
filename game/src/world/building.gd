class_name Building
extends RefCounted

# What building costs (D-156, D-159): one rule, asked by the fixture
# gatekeeper before it places and by build mode's preview, so the two
# can't disagree (slice 008 trap 4). Stateless; the costs are the
# profile's. A placement with no actor (generation, a load) is free.
#
# What a build slot holds, and what a placement asks for, is a build
# entry. An entry is a fixture kind, except where one kind has more
# than one cost: each cost is its own entry, and the player picks which
# to pay (D-241). The smelter is the one so far.

# The smelter, paid for in stone and timber rather than stone and
# copper ore (D-240, D-241). Saved in build slots, so never reused;
# entries past the kinds start at 1000, clear of any kind id.
const SMELTER_FROM_TIMBER: int = 1001

# What each entry that isn't a kind of its own builds.
const ENTRY_KINDS: Dictionary = {
	SMELTER_FROM_TIMBER: ObjectKind.OBJECT.SMELTER,
}

# What each such entry is called, and the plain kind when it has a
# twin: "Smelter (ore)" beside "Smelter (timber)".
const ENTRY_NAMES: Dictionary = {
	ObjectKind.OBJECT.SMELTER: "Smelter (ore)",
	SMELTER_FROM_TIMBER: "Smelter (timber)",
}

# A line for the BUILD tab's detail pane (D-252), by entry.
const DESCRIPTIONS: Dictionary = {
	ObjectKind.OBJECT.LADDER: "Goes under a hole. Climbing takes time, longer loaded.",
	ObjectKind.OBJECT.TIMBER_PROP: "Holds the ceiling up around it.",
	ObjectKind.OBJECT.CHUTE: "Over a hole. What you drop into it lands on the level below.",
	ObjectKind.OBJECT.WINCH: "Over a hole. Crank its crate up from the level below.",
	ObjectKind.OBJECT.WORKBENCH: "Bronze tools, lamp oil and the lantern are made near it.",
	ObjectKind.OBJECT.SMELTER: "Drop in ore and coal; take out ingots. It works while you're away.",
	SMELTER_FROM_TIMBER: "Drop in ore and coal; take out ingots. It works while you're away.",
	ObjectKind.OBJECT.FORGE: "Iron tools are made near it.",
	ObjectKind.OBJECT.BED: "Your own. Where you wake when you join.",
	ObjectKind.OBJECT.STORAGE_CRATE: "Holds 200 kg. Drop into it; take from it.",
}


# The fixture kind an entry builds.
static func kind_of(entry: int) -> int:
	return ENTRY_KINDS.get(entry, entry)


# What an entry is called on screen: build mode and the inventory.
static func entry_name(entry: int) -> String:
	return ENTRY_NAMES.get(entry, ObjectKind.display_name(entry))


static func description(entry: int) -> String:
	return DESCRIPTIONS.get(entry, "")


# What placing an entry costs, item id -> count. Nothing for an entry
# with no cost.
static func cost_of(tuning: TuningProfile, entry: int) -> Dictionary[StringName, int]:
	match entry:
		ObjectKind.OBJECT.LADDER: return tuning.ladder_cost
		ObjectKind.OBJECT.TIMBER_PROP: return tuning.prop_cost
		ObjectKind.OBJECT.CHUTE: return tuning.chute_cost
		ObjectKind.OBJECT.WINCH: return tuning.winch_cost
		ObjectKind.OBJECT.WORKBENCH: return tuning.workbench_cost
		ObjectKind.OBJECT.FORGE: return tuning.forge_cost
		ObjectKind.OBJECT.SMELTER: return tuning.smelter_ore_cost
		SMELTER_FROM_TIMBER: return tuning.smelter_timber_cost
		ObjectKind.OBJECT.BED: return tuning.bed_cost
		ObjectKind.OBJECT.STORAGE_CRATE: return tuning.storage_crate_cost
	var free: Dictionary[StringName, int] = {}
	return free


static func can_afford(tuning: TuningProfile, actor: Actor, entry: int) -> bool:
	if actor == null: return true
	var cost: Dictionary[StringName, int] = cost_of(tuning, entry)
	for id: StringName in cost:
		if not actor.pack.has(id, cost[id]): return false
	return true


# Takes the cost from the actor's pack. Call only after can_afford.
static func pay(tuning: TuningProfile, actor: Actor, entry: int) -> void:
	if actor == null: return
	var cost: Dictionary[StringName, int] = cost_of(tuning, entry)
	for id: StringName in cost:
		actor.pack.remove(id, cost[id])


# "4 timber", for the preview; "" for a free entry.
static func cost_text(tuning: TuningProfile, entry: int) -> String:
	var cost: Dictionary[StringName, int] = cost_of(tuning, entry)
	var parts: PackedStringArray = []
	for id: StringName in cost:
		var item: Item = ItemRegistry.find(id)
		var name: String = item.display_key.to_lower() if item != null else String(id)
		parts.append("%d %s" % [cost[id], name])
	return ", ".join(parts)
