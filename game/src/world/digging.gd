class_name Digging
extends RefCounted

# Every digging rule (D-150): mining a wall and breaching a floor.
# Stateless; each rule takes the TuningProfile it reads its numbers
# from, so the rules stay put while the numbers are tuned per world
# (D-135). Whether a tile kind can be dug at all is TileKind's to say.


# How hard a wall's top kind is to dig, or -1 if it can't be dug.
static func hardness_of(tuning: TuningProfile, top_kind: int) -> float:
	if not TileKind.is_diggable(top_kind): return -1.0
	if not tuning.hardness.has(top_kind):
		push_error("Tuning profile \"%s\" has no hardness for top kind %d." % [
			tuning.id, top_kind])
		return -1.0
	return tuning.hardness[top_kind]


# How hard a tile is to dig, counting its ore: the top kind's
# hardness, times the profile's ore multiplier when the tile holds
# ore. -1 when the top kind can't be dug.
static func dig_hardness(tuning: TuningProfile, top_kind: int, ore_kind: int) -> float:
	var value: float = hardness_of(tuning, top_kind)
	if value < 0.0: return value
	if ore_kind != TileKind.ORE.NONE and ore_kind != TileKind.ORE.NULL:
		value *= tuning.ore_dig_multiplier
	return value


# The item each ore kind is mined as. Content, not tuning: it moves to
# an OreType resource (content-schema §3) when there's a second ore.
const ORE_ITEMS: Dictionary = {
	TileKind.ORE.COPPER: &"copper_ore",
}


# What mining a wall yields, item id -> count (D-156, D-158): an ore
# vein gives its ore, between the profile's minimum and maximum; a rock
# wall gives stone; a dirt wall gives nothing. `rng` draws the ore's
# count, so a world's yields repeat for the same seed.
static func yield_of(tuning: TuningProfile, top_kind: int, ore_kind: int,
		rng: RandomNumberGenerator) -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	if ORE_ITEMS.has(ore_kind):
		found[ORE_ITEMS[ore_kind]] = rng.randi_range(tuning.ore_yield_min, tuning.ore_yield_max)
		return found
	if top_kind == TileKind.TOP.MINABLE_ROCK and tuning.rock_wall_stone > 0:
		found[&"stone"] = tuning.rock_wall_stone
	return found


# How hard the floor of the level at `depth` is: its stratum's number
# (D-151). -1 for a depth the profile doesn't cover.
static func floor_hardness(tuning: TuningProfile, depth: int) -> float:
	if depth < 0 or depth >= tuning.floor_hardness_by_depth.size(): return -1.0
	return tuning.floor_hardness_by_depth[depth]


# The work a breach takes: progress, at the tool's power per second,
# reaches this when the floor gives way. So breach seconds =
# hardness x multiplier / tool power (tuning appendix §4).
static func breach_work(tuning: TuningProfile, hardness: float) -> float:
	return hardness * tuning.breach_time_multiplier


static func breach_seconds(tuning: TuningProfile, hardness: float, tool_power: float) -> float:
	return breach_work(tuning, hardness) / tool_power


# The one hard tool gate on descent (digging-and-structure §1): a
# tool must be this much stronger than the floor.
static func can_breach(tuning: TuningProfile, hardness: float, tool_power: float) -> bool:
	return hardness >= 0.0 and tool_power >= hardness * tuning.breach_tool_multiplier
