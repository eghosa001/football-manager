class_name FDLandingArt
extends Control

const NAVY := Color("06101d")
const NAVY_2 := Color("0a1a2b")
const CYAN := Color("35d8db")
const TEAL := Color("15959f")
const WHITE := Color("f4f7fb")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return

	# Layered night-sky background. Narrow horizontal bands create a soft
	# gradient without a texture dependency, keeping the landing screen fully
	# deterministic and lightweight on desktop and mobile.
	draw_rect(Rect2(Vector2.ZERO, s), NAVY)
	for i in range(18):
		var t := float(i) / 17.0
		var y := s.y * t
		var c := NAVY.lerp(NAVY_2, t * 0.78)
		draw_rect(Rect2(0, y, s.x, s.y / 17.0 + 2.0), c)

	# Stadium light bloom and angled beams.
	for i in range(7):
		var alpha := 0.045 - float(i) * 0.005
		var x0 := s.x * (0.51 + float(i) * 0.055)
		var beam := PackedVector2Array([
			Vector2(x0, s.y * 0.03),
			Vector2(x0 + s.x * 0.018, s.y * 0.03),
			Vector2(x0 + s.x * 0.19, s.y * 0.78),
			Vector2(x0 + s.x * 0.10, s.y * 0.78),
		])
		draw_colored_polygon(beam, Color(0.35, 0.88, 0.92, alpha))
	for row in range(2):
		for col in range(10):
			var x := s.x * (0.515 + float(col) * 0.047)
			var y := s.y * (0.085 + float(row) * 0.035)
			var r := maxf(1.8, s.y * 0.0045)
			draw_circle(Vector2(x, y), r * 3.2, Color(0.45, 0.92, 0.96, 0.035))
			draw_circle(Vector2(x, y), r, Color(0.78, 1.0, 1.0, 0.42 - row * 0.10))

	# Stadium bowl and crowd bands.
	var bowl := PackedVector2Array([
		Vector2(s.x * 0.43, s.y * 0.36),
		Vector2(s.x, s.y * 0.29),
		Vector2(s.x, s.y * 0.67),
		Vector2(s.x * 0.39, s.y * 0.70),
	])
	draw_colored_polygon(bowl, Color(0.035, 0.115, 0.17, 0.96))
	for i in range(7):
		var yy := s.y * (0.41 + float(i) * 0.038)
		draw_line(Vector2(s.x * 0.43, yy), Vector2(s.x, yy - s.y * 0.043), Color(0.20, 0.58, 0.60, 0.13), 1.5)
	# Crowd glints.
	for i in range(38):
		var gx := s.x * (0.47 + fmod(float(i) * 0.071, 0.52))
		var gy := s.y * (0.40 + fmod(float(i * 7) * 0.013, 0.21))
		var ga := 0.08 + float(i % 4) * 0.025
		draw_circle(Vector2(gx, gy), 1.2 + float(i % 2), Color(0.55, 0.95, 0.87, ga))

	# Pitch perspective at the bottom.
	var pitch := PackedVector2Array([
		Vector2(s.x * 0.33, s.y * 0.73),
		Vector2(s.x, s.y * 0.60),
		Vector2(s.x, s.y),
		Vector2(s.x * 0.25, s.y),
	])
	draw_colored_polygon(pitch, Color(0.018, 0.17, 0.145, 0.70))
	draw_line(Vector2(s.x * 0.33, s.y * 0.73), Vector2(s.x, s.y * 0.60), Color(0.76, 1.0, 0.91, 0.28), 1.5)
	draw_line(Vector2(s.x * 0.62, s.y * 0.68), Vector2(s.x * 0.72, s.y), Color(0.76, 1.0, 0.91, 0.18), 1.5)
	draw_arc(Vector2(s.x * 0.73, s.y * 0.80), s.y * 0.115, -2.25, -0.75, 40, Color(0.76, 1.0, 0.91, 0.15), 1.5)

	# Primary fictional manager/football figure. Keep the lower body cropped so it
	# reads like premium cover photography rather than a block character.
	var px := s.x * 0.77
	var head := Vector2(px, s.y * 0.315)
	var head_r := s.y * 0.050
	# Rim-light glow behind the subject.
	for r in range(7, 0, -1):
		draw_circle(head, head_r + float(r) * 5.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.006 * r))
	# Neck.
	draw_rect(Rect2(px - s.x * 0.018, s.y * 0.355, s.x * 0.036, s.y * 0.055), Color(0.025, 0.04, 0.052, 1.0))
	# Shoulders / jacket silhouette.
	var body := PackedVector2Array([
		Vector2(px - s.x * 0.105, s.y * 0.405),
		Vector2(px - s.x * 0.045, s.y * 0.375),
		Vector2(px + s.x * 0.045, s.y * 0.375),
		Vector2(px + s.x * 0.112, s.y * 0.415),
		Vector2(px + s.x * 0.145, s.y),
		Vector2(px - s.x * 0.155, s.y),
	])
	draw_colored_polygon(body, Color(0.018, 0.032, 0.044, 1.0))
	# Head on top of body with a slightly offset face plane.
	draw_circle(head, head_r, Color(0.022, 0.038, 0.050, 1.0))
	var face_plane := PackedVector2Array([
		Vector2(px - head_r * 0.08, head.y - head_r * 0.92),
		Vector2(px + head_r * 0.72, head.y - head_r * 0.45),
		Vector2(px + head_r * 0.55, head.y + head_r * 0.58),
		Vector2(px - head_r * 0.08, head.y + head_r * 0.85),
	])
	draw_colored_polygon(face_plane, Color(0.032, 0.060, 0.071, 1.0))
	# Jacket lapels and shirt give the silhouette readable anatomy.
	var left_lapel := PackedVector2Array([
		Vector2(px - s.x * 0.045, s.y * 0.385),
		Vector2(px - s.x * 0.006, s.y * 0.48),
		Vector2(px - s.x * 0.055, s.y * 0.63),
		Vector2(px - s.x * 0.085, s.y * 0.44),
	])
	var right_lapel := PackedVector2Array([
		Vector2(px + s.x * 0.045, s.y * 0.385),
		Vector2(px + s.x * 0.006, s.y * 0.48),
		Vector2(px + s.x * 0.052, s.y * 0.62),
		Vector2(px + s.x * 0.087, s.y * 0.44),
	])
	draw_colored_polygon(left_lapel, Color(0.045, 0.105, 0.120, 0.72))
	draw_colored_polygon(right_lapel, Color(0.035, 0.085, 0.102, 0.72))
	draw_colored_polygon(PackedVector2Array([
		Vector2(px - s.x * 0.014, s.y * 0.395),
		Vector2(px + s.x * 0.014, s.y * 0.395),
		Vector2(px + s.x * 0.025, s.y * 0.58),
		Vector2(px - s.x * 0.026, s.y * 0.58),
	]), Color(0.09, 0.25, 0.27, 0.42))
	# Arms are angled instead of vertical rectangles.
	draw_colored_polygon(PackedVector2Array([
		Vector2(px - s.x * 0.094, s.y * 0.43),
		Vector2(px - s.x * 0.125, s.y * 0.48),
		Vector2(px - s.x * 0.116, s.y * 0.78),
		Vector2(px - s.x * 0.079, s.y * 0.77),
	]), Color(0.018, 0.032, 0.044, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(px + s.x * 0.094, s.y * 0.43),
		Vector2(px + s.x * 0.125, s.y * 0.49),
		Vector2(px + s.x * 0.116, s.y * 0.78),
		Vector2(px + s.x * 0.078, s.y * 0.77),
	]), Color(0.018, 0.032, 0.044, 1.0))
	# Cyan rim light suggests stadium lighting and separates the subject.
	draw_arc(head, head_r + 1.5, -1.65, 1.15, 36, Color(CYAN.r, CYAN.g, CYAN.b, 0.58), 2.5)
	draw_line(Vector2(px - s.x * 0.101, s.y * 0.412), Vector2(px - s.x * 0.145, s.y * 0.91), Color(CYAN.r, CYAN.g, CYAN.b, 0.32), 3.0)

	# Distant touchline figure for depth, deliberately soft and unobtrusive.
	var sx := s.x * 0.94
	draw_circle(Vector2(sx, s.y * 0.43), s.y * 0.027, Color(0.015, 0.027, 0.038, 0.70))
	draw_colored_polygon(PackedVector2Array([
		Vector2(sx - s.x * 0.028, s.y * 0.47),
		Vector2(sx + s.x * 0.028, s.y * 0.47),
		Vector2(sx + s.x * 0.040, s.y * 0.72),
		Vector2(sx - s.x * 0.040, s.y * 0.72),
	]), Color(0.015, 0.027, 0.038, 0.70))

	# Left-side vignette reserves crisp contrast for title and controls; a softer
	# middle veil blends it into the stadium without a hard split.
	draw_rect(Rect2(0, 0, s.x * 0.49, s.y), Color(0.009, 0.020, 0.035, 0.86))
	for i in range(8):
		var x := s.x * (0.46 + float(i) * 0.018)
		draw_rect(Rect2(x, 0, s.x * 0.02, s.y), Color(0.009, 0.020, 0.035, 0.30 - float(i) * 0.032))
