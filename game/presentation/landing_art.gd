class_name FDLandingArt
extends Control

const NAVY := Color("07111f")
const NAVY_2 := Color("0c1a2c")
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

	# Deep stadium backdrop.
	draw_rect(Rect2(Vector2.ZERO, s), NAVY)
	for i in range(9):
		var y := s.y * (0.08 + float(i) * 0.075)
		var alpha := 0.10 - float(i) * 0.006
		draw_line(Vector2(s.x * 0.42, y), Vector2(s.x, y + s.y * 0.03), Color(0.22, 0.58, 0.65, alpha), 1.0)

	# Floodlights / atmosphere.
	for row in range(3):
		for col in range(9):
			var x := s.x * (0.52 + float(col) * 0.052)
			var y := s.y * (0.10 + float(row) * 0.035)
			var glow := 0.30 - float(row) * 0.07
			draw_circle(Vector2(x, y), maxf(1.5, s.y * 0.004), Color(0.72, 0.98, 1.0, glow))

	# Stadium bowl tiers.
	var tier_points := PackedVector2Array([
		Vector2(s.x * 0.40, s.y * 0.38),
		Vector2(s.x, s.y * 0.29),
		Vector2(s.x, s.y * 0.63),
		Vector2(s.x * 0.43, s.y * 0.70)
	])
	draw_colored_polygon(tier_points, Color(0.04, 0.14, 0.21, 0.95))
	for i in range(5):
		var yy := s.y * (0.43 + float(i) * 0.047)
		draw_line(Vector2(s.x * 0.45, yy), Vector2(s.x, yy - s.y * 0.055), Color(0.16, 0.48, 0.51, 0.24), 2.0)

	# Pitch perspective and touchlines.
	var pitch := PackedVector2Array([
		Vector2(s.x * 0.36, s.y * 0.73),
		Vector2(s.x, s.y * 0.58),
		Vector2(s.x, s.y),
		Vector2(s.x * 0.28, s.y)
	])
	draw_colored_polygon(pitch, Color(0.025, 0.20, 0.17, 0.72))
	draw_polyline(PackedVector2Array([
		Vector2(s.x * 0.36, s.y * 0.73),
		Vector2(s.x, s.y * 0.58),
		Vector2(s.x, s.y)
	]), Color(0.74, 1.0, 0.90, 0.34), 2.0)
	draw_line(Vector2(s.x * 0.64, s.y * 0.66), Vector2(s.x * 0.72, s.y), Color(0.74, 1.0, 0.90, 0.22), 2.0)

	# Fictional player silhouette — intentionally generic and original.
	var px := s.x * 0.72
	var head := Vector2(px, s.y * 0.31)
	var head_r := s.y * 0.055
	draw_circle(head, head_r, Color(0.035, 0.055, 0.072, 1.0))
	var torso := PackedVector2Array([
		Vector2(px - s.x * 0.055, s.y * 0.38),
		Vector2(px + s.x * 0.052, s.y * 0.38),
		Vector2(px + s.x * 0.085, s.y * 0.67),
		Vector2(px + s.x * 0.038, s.y * 0.74),
		Vector2(px - s.x * 0.045, s.y * 0.73),
		Vector2(px - s.x * 0.083, s.y * 0.58)
	])
	draw_colored_polygon(torso, Color(0.045, 0.075, 0.095, 1.0))
	var shirt := PackedVector2Array([
		Vector2(px - s.x * 0.052, s.y * 0.39),
		Vector2(px + s.x * 0.050, s.y * 0.39),
		Vector2(px + s.x * 0.063, s.y * 0.57),
		Vector2(px - s.x * 0.065, s.y * 0.57)
	])
	draw_colored_polygon(shirt, Color(CYAN.r, CYAN.g, CYAN.b, 0.18))
	draw_line(Vector2(px - s.x * 0.052, s.y * 0.40), Vector2(px + s.x * 0.061, s.y * 0.56), Color(CYAN.r, CYAN.g, CYAN.b, 0.28), 3.0)

	# Legs and stance.
	draw_colored_polygon(PackedVector2Array([
		Vector2(px - s.x * 0.041, s.y * 0.70),
		Vector2(px + s.x * 0.005, s.y * 0.70),
		Vector2(px - s.x * 0.015, s.y * 0.98),
		Vector2(px - s.x * 0.055, s.y * 0.98)
	]), Color(0.025, 0.04, 0.055, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(px + s.x * 0.010, s.y * 0.70),
		Vector2(px + s.x * 0.052, s.y * 0.70),
		Vector2(px + s.x * 0.102, s.y * 0.98),
		Vector2(px + s.x * 0.061, s.y * 0.98)
	]), Color(0.025, 0.04, 0.055, 1.0))

	# Secondary manager silhouette to give the scene depth.
	var mx := s.x * 0.91
	draw_circle(Vector2(mx, s.y * 0.43), s.y * 0.035, Color(0.02, 0.035, 0.05, 0.86))
	draw_colored_polygon(PackedVector2Array([
		Vector2(mx - s.x * 0.035, s.y * 0.47),
		Vector2(mx + s.x * 0.035, s.y * 0.47),
		Vector2(mx + s.x * 0.052, s.y * 0.74),
		Vector2(mx - s.x * 0.045, s.y * 0.74)
	]), Color(0.02, 0.035, 0.05, 0.86))

	# Cyan edge light sells the premium sports-cover treatment.
	draw_arc(head, head_r + 2.0, -1.6, 1.45, 32, Color(CYAN.r, CYAN.g, CYAN.b, 0.50), 3.0)
	draw_line(Vector2(px - s.x * 0.075, s.y * 0.39), Vector2(px - s.x * 0.092, s.y * 0.68), Color(CYAN.r, CYAN.g, CYAN.b, 0.35), 4.0)

	# Vignette blocks reserve clean contrast for menu copy.
	draw_rect(Rect2(0, 0, s.x * 0.51, s.y), Color(0.015, 0.028, 0.05, 0.84))
	draw_rect(Rect2(s.x * 0.40, 0, s.x * 0.20, s.y), Color(0.015, 0.028, 0.05, 0.26))
