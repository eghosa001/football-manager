class_name MatchViewer
extends Control

signal frame_changed(index: int, minute: int)
signal playback_finished

var match_result: Dictionary = {}
var frame_index := 0
var playing := false
var playback_speed := 1.0
var frame_interval := 0.8
var _elapsed := 0.0
var show_player_labels := false
var show_pressing_overlay := false
var show_marking_overlay := false
var show_condition_indicators := true
var interpolated_position := 0.0
var ball_trail: Array = []
const MAX_TRAIL := 12

func _ready() -> void:
	set_process(true)

func set_match(result: Dictionary) -> void:
	match_result = result.duplicate(true)
	frame_index = 0
	playing = false
	_elapsed = 0.0
	queue_redraw()
	_emit_frame()

func set_frame(index: int) -> void:
	var frames: Array = _frames()
	frame_index = clampi(index, 0, maxi(0, frames.size() - 1))
	_elapsed = 0.0
	interpolated_position = 0.0
	_push_trail()
	queue_redraw()
	_emit_frame()

func next_frame() -> void:
	set_frame(frame_index + 1)

func previous_frame() -> void:
	set_frame(frame_index - 1)

func play() -> void:
	if _frames().is_empty(): return
	playing = true

func pause() -> void:
	playing = false

func toggle_playback() -> void:
	playing = not playing if not _frames().is_empty() else false

func set_speed(multiplier: float) -> void:
	playback_speed = clampf(multiplier, 0.25, 8.0)

func set_frame_interval(seconds: float) -> void:
	frame_interval = clampf(seconds, 0.05, 3.0)

func set_overlays(pressing: bool, marking: bool, conditions: bool) -> void:
	show_pressing_overlay = pressing
	show_marking_overlay = marking
	show_condition_indicators = conditions
	queue_redraw()

func timeline_size() -> int:
	return _frames().size()

func timeline_position() -> float:
	if _frames().is_empty():
		return 0.0
	return float(frame_index) / float(maxi(1, _frames().size() - 1))

func current_minute() -> int:
	var frames := _frames()
	if frames.is_empty(): return 0
	return int(frames[frame_index].get("minute", 0))

func seek_minute(minute: int) -> void:
	var frames := _frames()
	if frames.is_empty(): return
	var best_index := 0
	var best_distance := 9999
	for i in range(frames.size()):
		var distance := absi(int(frames[i].get("minute", 0)) - minute)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	set_frame(best_index)

func _process(delta: float) -> void:
	if not playing: return
	var frames := _frames()
	if frames.is_empty():
		playing = false
		return
	_elapsed += delta * playback_speed
	# Smooth interpolation within frame interval for continuous ball animation.
	interpolated_position = clampf(_elapsed / maxf(frame_interval, 0.001), 0.0, 1.0)
	queue_redraw()
	if _elapsed < frame_interval: return
	_elapsed = 0.0
	interpolated_position = 0.0
	if frame_index >= frames.size() - 1:
		playing = false
		playback_finished.emit()
		return
	frame_index += 1
	_push_trail()
	queue_redraw()
	_emit_frame()

func _push_trail() -> void:
	var frames := _frames()
	if frames.is_empty() or frame_index >= frames.size():
		return
	var frame: Dictionary = frames[frame_index]
	if frame.has("ball"):
		ball_trail.append((frame.ball as Dictionary).duplicate(true))
		while ball_trail.size() > MAX_TRAIL:
			ball_trail.pop_front()

func _draw() -> void:
	var pitch := Rect2(Vector2(8, 8), Vector2(maxf(1.0, size.x - 16.0), maxf(1.0, size.y - 16.0)))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.075, 0.055), true)
	draw_rect(pitch, Color(0.08, 0.32, 0.14), true)
	draw_rect(pitch, Color.WHITE, false, 2.0)
	var middle_x := pitch.position.x + pitch.size.x / 2.0
	draw_line(Vector2(middle_x, pitch.position.y), Vector2(middle_x, pitch.end.y), Color.WHITE, 2.0)
	draw_circle(Vector2(middle_x, pitch.position.y + pitch.size.y / 2.0), minf(pitch.size.x, pitch.size.y) * 0.10, Color.WHITE, false, 2.0)
	_draw_penalty_boxes(pitch)
	var frames: Array = _frames()
	if frames.is_empty(): return
	var frame: Dictionary = _display_frame(frames)
	_draw_team(frame.get("home", {}), Color(0.3, 0.6, 1.0), pitch, frame.get("home_loads", {}))
	_draw_team(frame.get("away", {}), Color(1.0, 0.35, 0.35), pitch, frame.get("away_loads", {}))
	if show_pressing_overlay:
		_draw_pressing(frame, pitch)
	if show_marking_overlay:
		_draw_marking(frame, pitch)
	_draw_ball_trail(pitch)
	if frame.has("ball"):
		var ball_point := _to_screen(frame.ball, pitch)
		draw_circle(ball_point, 4.0, Color.WHITE)
		draw_circle(ball_point, 4.0, Color.BLACK, false, 1.0)

func _draw_penalty_boxes(pitch: Rect2) -> void:
	var box_width := pitch.size.x * (16.5 / 105.0)
	var box_height := pitch.size.y * (40.32 / 68.0)
	var y := pitch.position.y + (pitch.size.y - box_height) / 2.0
	draw_rect(Rect2(Vector2(pitch.position.x, y), Vector2(box_width, box_height)), Color.WHITE, false, 1.5)
	draw_rect(Rect2(Vector2(pitch.end.x - box_width, y), Vector2(box_width, box_height)), Color.WHITE, false, 1.5)

func _draw_team(positions: Dictionary, color: Color, pitch: Rect2, loads: Dictionary = {}) -> void:
	for id in positions.keys():
		var point := _to_screen(positions[id], pitch)
		draw_circle(point, 6.0, color)
		draw_circle(point, 6.0, Color.WHITE, false, 1.0)
		if show_condition_indicators and loads.has(id):
			var energy := clampf(float((loads[id] as Dictionary).get("energy", 1.0)), 0.0, 1.0)
			var ring := Color(0.3, 1.0, 0.3) if energy > 0.7 else (Color(1.0, 0.85, 0.2) if energy > 0.5 else Color(1.0, 0.3, 0.2))
			draw_arc(point, 8.5, -PI / 2.0, -PI / 2.0 + TAU * energy, 12, ring, 2.0)
		if show_player_labels:
			draw_string(ThemeDB.fallback_font, point + Vector2(8, 4), String(id).right(6), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _display_frame(frames: Array) -> Dictionary:
	var current: Dictionary = frames[frame_index]
	if interpolated_position <= 0.01 or frame_index + 1 >= frames.size():
		return current
	var nxt: Dictionary = frames[frame_index + 1]
	var merged := {"ball": _lerp_pos(current.get("ball", {}), nxt.get("ball", {}), interpolated_position), "home": _lerp_team(current.get("home", {}), nxt.get("home", {}), interpolated_position), "away": _lerp_team(current.get("away", {}), nxt.get("away", {}), interpolated_position)}
	return merged

func _lerp_pos(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {"x": lerpf(float(a.get("x", 0.0)), float(b.get("x", 0.0)), t), "y": lerpf(float(a.get("y", 0.0)), float(b.get("y", 0.0)), t)}

func _lerp_team(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var result := {}
	for id in a.keys():
		result[id] = _lerp_pos(a[id], b.get(id, a[id]), t)
	return result

func _draw_ball_trail(pitch: Rect2) -> void:
	for i in range(ball_trail.size()):
		var alpha := float(i + 1) / float(maxi(1, ball_trail.size()))
		draw_circle(_to_screen(ball_trail[i], pitch), 2.0 + alpha * 2.0, Color(1, 1, 1, 0.15 + alpha * 0.35))

func _draw_pressing(frame: Dictionary, pitch: Rect2) -> void:
	if not frame.has("ball"):
		return
	var ball_point := _to_screen(frame.ball, pitch)
	draw_arc(ball_point, 26.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.2, 0.7), 1.5)

func _draw_marking(frame: Dictionary, pitch: Rect2) -> void:
	var home: Dictionary = frame.get("home", {})
	var away: Dictionary = frame.get("away", {})
	for hid in home.keys():
		var best := ""
		var best_d := INF
		for aid in away.keys():
			var d := _screen_dist(_to_screen(home[hid], pitch), _to_screen(away[aid], pitch))
			if d < best_d:
				best_d = d
				best = aid
		if best != "" and best_d < 60.0:
			draw_line(_to_screen(home[hid], pitch), _to_screen(away[best], pitch), Color(1, 1, 1, 0.25), 1.0)

func _screen_dist(a: Vector2, b: Vector2) -> float:
	return (a - b).length()

func _to_screen(position: Dictionary, pitch: Rect2) -> Vector2:
	var x := float(position.get("x", 0.0))
	var y := float(position.get("y", 0.0))
	var spatial: Dictionary = match_result.get("spatial", {})
	var length := float(spatial.get("pitch_length", 1.0))
	var width := float(spatial.get("pitch_width", 1.0))
	# Phase 8 legacy frames are normalized; Match Engine v2 frames use metres.
	if length <= 1.01 and width <= 1.01:
		return Vector2(pitch.position.x + clampf(x, 0.0, 1.0) * pitch.size.x, pitch.position.y + clampf(y, 0.0, 1.0) * pitch.size.y)
	return Vector2(pitch.position.x + clampf(x / maxf(length, 1.0), 0.0, 1.0) * pitch.size.x, pitch.position.y + clampf(y / maxf(width, 1.0), 0.0, 1.0) * pitch.size.y)

func _frames() -> Array:
	return match_result.get("spatial", {}).get("frames", [])

func _emit_frame() -> void:
	frame_changed.emit(frame_index, current_minute())
