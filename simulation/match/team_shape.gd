class_name FootballTeamShape
extends RefCounted

static func analyse(positions: Dictionary, attacking_right: bool = true) -> Dictionary:
	var points: Array[Vector2] = []
	for id in positions.keys():
		var p: Dictionary = positions[id]
		points.append(Vector2(float(p.get("x",0.0)),float(p.get("y",0.0))))
	if points.is_empty():
		return {"centroid":Vector2.ZERO,"hull":[],"width":0.0,"length":0.0,"compactness":0.0,"back_line":0.0,"front_line":0.0}
	var centroid := Vector2.ZERO
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for p in points:
		centroid += p
		min_x = minf(min_x,p.x); max_x = maxf(max_x,p.x)
		min_y = minf(min_y,p.y); max_y = maxf(max_y,p.y)
	centroid /= float(points.size())
	var length := maxf(0.0,max_x-min_x)
	var width := maxf(0.0,max_y-min_y)
	var area := maxf(1.0,length*width)
	var density := float(points.size())/area
	return {
		"centroid":centroid,
		"hull":convex_hull(points),
		"width":width,
		"length":length,
		"compactness":density,
		"back_line":min_x if attacking_right else max_x,
		"front_line":max_x if attacking_right else min_x,
	}

static func convex_hull(points: Array[Vector2]) -> Array[Vector2]:
	if points.size() <= 2:
		return points.duplicate()
	var sorted := points.duplicate()
	sorted.sort_custom(func(a: Vector2,b: Vector2): return a.x < b.x or (is_equal_approx(a.x,b.x) and a.y < b.y))
	var lower: Array[Vector2] = []
	for p in sorted:
		while lower.size() >= 2 and _cross(lower[lower.size()-2],lower[lower.size()-1],p) <= 0.0:
			lower.pop_back()
		lower.append(p)
	var upper: Array[Vector2] = []
	for i in range(sorted.size()-1,-1,-1):
		var p: Vector2 = sorted[i]
		while upper.size() >= 2 and _cross(upper[upper.size()-2],upper[upper.size()-1],p) <= 0.0:
			upper.pop_back()
		upper.append(p)
	lower.pop_back(); upper.pop_back()
	lower.append_array(upper)
	return lower

static func passing_lane_blocked(origin: Vector2, target: Vector2, opponents: Dictionary, corridor_radius: float = 1.6) -> bool:
	var segment := target-origin
	var length2 := segment.length_squared()
	if length2 < 0.001:
		return false
	for id in opponents.keys():
		var raw: Dictionary = opponents[id]
		var p := Vector2(float(raw.get("x",0.0)),float(raw.get("y",0.0)))
		var t := clampf((p-origin).dot(segment)/length2,0.0,1.0)
		var nearest := origin+segment*t
		if p.distance_to(nearest) <= corridor_radius:
			return true
	return false

static func _cross(o: Vector2,a: Vector2,b: Vector2) -> float:
	return (a.x-o.x)*(b.y-o.y)-(a.y-o.y)*(b.x-o.x)
