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
	if _elapsed < frame_interval: return
	_elapsed = 0.0
	if frame_index >= frames.size() - 1:
		playing = false
		playback_finished.emit()
		return
	frame_index += 1
	queue_redraw()
	_emit_frame()

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
	var frame: Dictionary = frames[frame_index]
	_draw_team(frame.get("home", {}), Color(0.3, 0.6, 1.0), pitch)
	_draw_team(frame.get("away", {}), Color(1.0, 0.35, 0.35), pitch)
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

func _draw_team(positions: Dictionary, color: Color, pitch: Rect2) -> void:
	for id in positions.keys():
		var point := _to_screen(positions[id], pitch)
		draw_circle(point, 6.0, color)
		draw_circle(point, 6.0, Color.WHITE, false, 1.0)
		if show_player_labels:
			draw_string(ThemeDB.fallback_font, point + Vector2(8, 4), String(id).right(6), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

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
