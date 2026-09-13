class_name FootballSpatialHash
extends RefCounted

const DEFAULT_CELL_SIZE := 6.0

var cell_size: float = DEFAULT_CELL_SIZE
var _cells: Dictionary = {}
var _positions: Dictionary = {}

func _init(size: float = DEFAULT_CELL_SIZE) -> void:
	cell_size = maxf(2.0, size)

func clear() -> void:
	_cells.clear()
	_positions.clear()

func rebuild(home: Dictionary, away: Dictionary) -> void:
	clear()
	for id in home.keys():
		insert(String(id), home[id], "home")
	for id in away.keys():
		insert(String(id), away[id], "away")

func insert(id: String, position: Dictionary, side: String) -> void:
	var p := Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))
	_positions[id] = {"position":p,"side":side}
	var key := _cell_key(p)
	if not _cells.has(key):
		_cells[key] = []
	_cells[key].append(id)

func query_radius(position: Dictionary, radius: float, exclude_id: String = "", side_filter: String = "") -> Array:
	var p := Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))
	var r := maxf(0.0, radius)
	var min_cell := Vector2i(floori((p.x-r)/cell_size), floori((p.y-r)/cell_size))
	var max_cell := Vector2i(floori((p.x+r)/cell_size), floori((p.y+r)/cell_size))
	var found: Array = []
	var r2 := r*r
	for cx in range(min_cell.x, max_cell.x+1):
		for cy in range(min_cell.y, max_cell.y+1):
			for id in _cells.get(Vector2i(cx,cy), []):
				if String(id) == exclude_id:
					continue
				var item: Dictionary = _positions.get(String(id), {})
				if item.is_empty():
					continue
				if side_filter != "" and String(item.get("side", "")) != side_filter:
					continue
				var q: Vector2 = item.position
				if p.distance_squared_to(q) <= r2:
					found.append({"id":String(id),"side":String(item.side),"distance":p.distance_to(q),"position":{"x":q.x,"y":q.y}})
	found.sort_custom(func(a: Dictionary, b: Dictionary):
		if is_equal_approx(float(a.distance), float(b.distance)):
			return String(a.id) < String(b.id)
		return float(a.distance) < float(b.distance)
	)
	return found

func nearest_opponent(position: Dictionary, own_side: String, radius: float = 30.0) -> Dictionary:
	var target_side := "away" if own_side == "home" else "home"
	var rows := query_radius(position, radius, "", target_side)
	return {} if rows.is_empty() else rows[0]

func _cell_key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/cell_size), floori(p.y/cell_size))
