class_name SpatialState
extends RefCounted

const PITCH_LENGTH := 105.0
const PITCH_WIDTH := 68.0

static func clamp_position(position: Dictionary) -> Dictionary:
	return {"x":clampf(float(position.get("x", 0.0)), 0.0, PITCH_LENGTH), "y":clampf(float(position.get("y", 0.0)), 0.0, PITCH_WIDTH)}

static func distance(a: Dictionary, b: Dictionary) -> float:
	var dx := float(a.get("x", 0.0)) - float(b.get("x", 0.0))
	var dy := float(a.get("y", 0.0)) - float(b.get("y", 0.0))
	return sqrt(dx * dx + dy * dy)

static func nearest(position: Dictionary, candidates: Dictionary) -> Dictionary:
	var best_id := ""
	var best_distance := INF
	for id in candidates.keys():
		var d := distance(position, candidates[id])
		if d < best_distance:
			best_distance = d
			best_id = String(id)
	return {"id":best_id,"distance":best_distance}

static func advance(position: Dictionary, target: Dictionary, metres: float) -> Dictionary:
	var dx := float(target.get("x", 0.0)) - float(position.get("x", 0.0))
	var dy := float(target.get("y", 0.0)) - float(position.get("y", 0.0))
	var length := sqrt(dx * dx + dy * dy)
	if length <= 0.0001:
		return clamp_position(position)
	var scale := minf(1.0, metres / length)
	return clamp_position({"x":float(position.x)+dx*scale,"y":float(position.y)+dy*scale})
