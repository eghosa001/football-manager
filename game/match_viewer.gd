class_name MatchViewer
extends Control

var match_result: Dictionary = {}
var frame_index := 0

func set_match(result: Dictionary) -> void:
	match_result = result.duplicate(true)
	frame_index = 0
	queue_redraw()

func set_frame(index: int) -> void:
	var frames: Array = match_result.get("spatial", {}).get("frames", [])
	frame_index = clampi(index, 0, maxi(0, frames.size() - 1))
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.08, 0.32, 0.14), true)
	draw_rect(rect.grow(-8.0), Color.WHITE, false, 2.0)
	draw_line(Vector2(size.x / 2.0, 8), Vector2(size.x / 2.0, size.y - 8), Color.WHITE, 2.0)
	draw_circle(Vector2(size.x / 2.0, size.y / 2.0), minf(size.x, size.y) * 0.10, Color.WHITE, false, 2.0)
	var frames: Array = match_result.get("spatial", {}).get("frames", [])
	if frames.is_empty(): return
	var frame: Dictionary = frames[frame_index]
	_draw_team(frame.get("home", {}), Color(0.3, 0.6, 1.0))
	_draw_team(frame.get("away", {}), Color(1.0, 0.35, 0.35))

func _draw_team(positions: Dictionary, color: Color) -> void:
	for position in positions.values():
		var point := Vector2(float(position.x) * size.x, float(position.y) * size.y)
		draw_circle(point, 5.0, color)
