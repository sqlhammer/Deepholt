class_name Carrying
extends RefCounted

# What a load does to the one who carries it (D-030, D-158, tuning
# appendix §2): the load curve, the only thing that changes walking
# speed. Stateless; the numbers are the profile's. Load is a share of
# capacity: 1.0 is full.


# Walking speed's multiplier at a load: 1 up to the curve's first
# point, straight lines between points, and the profile's
# beyond-the-curve value past the last.
static func speed_factor(tuning: TuningProfile, load_ratio: float) -> float:
	var points: Array[Vector2] = tuning.load_speed_points
	if points.is_empty(): return 1.0
	if load_ratio <= points[0].x: return points[0].y
	for i in range(1, points.size()):
		if load_ratio <= points[i].x:
			var a: Vector2 = points[i - 1]
			var b: Vector2 = points[i]
			return lerpf(a.y, b.y, (load_ratio - a.x) / (b.x - a.x))
	return tuning.load_speed_beyond
