class_name Winch
extends RefCounted

# The hand winch's rules (D-224, D-225), apart from the world that
# carries them out. Stateless; the numbers are the profile's. A winch
# stands over a hole; its crate rests at the foot of the hole on the
# level below, or hangs in the hole at the top, and is on one level or
# the other, never between.


# Why a winch's crate can't be set down at the foot of its hole on
# `below`, or NONE: the tile must be floor that holds nothing, so the
# crate has room to stand. Asked when a winch is built and each time
# the crate is lowered.
static func landing_problem(below: Level, tile: Vector2i) -> World.FIXTURE_REFUSAL:
	if below == null: return World.FIXTURE_REFUSAL.LEVEL_NOT_EXISTS
	var tiles: LevelTiles = below.level_tiles
	var ground: int = tiles.get_ground(tile.x, tile.y)
	if not TileKind.is_passable(tiles.get_top(tile.x, tile.y), ground) or TileKind.is_ramp(ground):
		return World.FIXTURE_REFUSAL.LANDING_BLOCKED
	if not below.level_fixtures.at(tile).is_empty():
		return World.FIXTURE_REFUSAL.LANDING_BLOCKED
	return World.FIXTURE_REFUSAL.NONE


# Seconds one player's cranking takes to move the crate: a lift when
# it is at the bottom, a lowering when it is at the top.
static func seconds(tuning: TuningProfile, lifting: bool) -> float:
	return tuning.winch_lift_seconds if lifting else tuning.winch_lower_seconds


# How many of `count` items of `id` fit in a crate, by its capacity.
static func room_for(tuning: TuningProfile, crate: Fixture, id: StringName, count: int) -> int:
	var limit: float = tuning.crate_capacity_kg / tuning.carry_capacity_kg
	return Carrying.fits(tuning, crate.contents, id, count, limit)
