class_name Light
extends RefCounted

# Where light reaches (D-144, D-149). Derived from a level's light
# fixtures and never saved: recomputed whenever it's needed. A light
# floods like the senses (Senses.flood), with its own radius, so it
# never passes through rock. A tile is lit or not; there are no
# brightness levels. Stateless, so presentation and, later,
# simulation (ore identification, crafting speed) ask the same rule.


# The Surface is lit throughout by daylight (D-144). Exposure and the
# sun are out of scope until they're built.
static func is_daylit(level: Level) -> bool:
	return level.depth == 0


# How far a fixture of `kind` lights, in steps, or -1 if it gives no
# light.
static func radius_of(kind: int, tuning: TuningProfile) -> int:
	match kind:
		ObjectKind.OBJECT.BRAZIER: return tuning.brazier_light_radius
	return -1


# Every tile some light fixture on the level reaches, each once. Not
# meaningful on a daylit level, where everything is lit.
static func lit_tiles(level: Level, tuning: TuningProfile) -> Array[Vector2i]:
	var lit: Dictionary[Vector2i, bool] = {}
	for fixture: Fixture in level.level_fixtures.all():
		var radius: int = radius_of(fixture.kind, tuning)
		if radius < 0: continue
		var from: Vector2i = Vector2i(fixture.tile.x, fixture.tile.y)
		for tile: Vector2i in Senses.flood(level.level_tiles, from, radius):
			lit[tile] = true
	var found: Array[Vector2i] = []
	found.assign(lit.keys())
	return found
