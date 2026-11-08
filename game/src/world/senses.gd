class_name Senses
extends RefCounted

# What can be sensed from a tile (D-145), and what a light reaches
# (D-149): a breadth-first flood through open space, up to `radius`
# steps, plus the rock faces bordering the open tiles it reaches. Rock
# behind a face is never reached, so untouched rock stays black
# (D-033). Stateless, and handed a position rather than an actor, so
# nothing here resolves to "the" player (D-045).

const STEPS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


# The tiles reached from `from`, the start first. Open means the top
# is open, holes and ramps included: you can sense across a shaft you
# can't walk over. The start is always reached; a flood that starts
# in rock (a broken save, a test) reaches only that tile. Sentinels
# (outside the array or the level's disc) are neither open nor faces.
static func flood(tiles: LevelTiles, from: Vector2i, radius: int) -> Array[Vector2i]:
	var reached: Dictionary[Vector2i, int] = {from: 0}
	var found: Array[Vector2i] = [from]
	if tiles.get_top(from.x, from.y) != TileKind.TOP.OPEN: return found
	# A read index rather than pop_front, which shifts the whole array
	var frontier: Array[Vector2i] = [from]
	var next: int = 0
	while next < frontier.size():
		var tile: Vector2i = frontier[next]
		next += 1
		var steps: int = reached[tile]
		for step: Vector2i in STEPS:
			var neighbor: Vector2i = tile + step
			if reached.has(neighbor): continue
			var top: int = tiles.get_top(neighbor.x, neighbor.y)
			if TileKind.is_sentinel(top): continue
			if top != TileKind.TOP.OPEN:
				# A face: reached, never spread through
				reached[neighbor] = steps + 1
				found.append(neighbor)
				continue
			if steps + 1 > radius: continue
			reached[neighbor] = steps + 1
			found.append(neighbor)
			frontier.append(neighbor)
	return found

