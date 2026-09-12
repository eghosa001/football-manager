class_name MatchAnalysisPanel
extends Control

const AdvancedMatchAnalyticsClass = preload("res://game/analysis/advanced_match_analytics.gd")

const MODES := ["xG timeline", "Shot map", "Average positions", "Passing network", "Heat map", "Possession zones", "Advanced"]

var match_result: Dictionary = {}
var analysis_mode := "xG timeline"
var advanced_cache := {}

func _init() -> void:
	custom_minimum_size = Vector2(900, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_result(result: Dictionary) -> void:
	match_result = result.duplicate(true)
	advanced_cache = AdvancedMatchAnalyticsClass.new().analyze(match_result.get("events", []))
	queue_redraw()

func set_analysis(mode: String) -> void:
	analysis_mode = mode if mode in MODES else MODES[0]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025,0.04,0.065), true)
	draw_string(ThemeDB.fallback_font, Vector2(18,28), analysis_mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if match_result.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(18,58), "No match data", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8,0.8,0.8))
		return
	match analysis_mode:
		"xG timeline": _draw_xg()
		"Shot map": _draw_shot_map()
		"Average positions": _draw_average_positions(false)
		"Passing network": _draw_passing_network()
		"Heat map": _draw_heat_map()
		"Possession zones": _draw_possession_zones()
		"Advanced": _draw_advanced()

func _plot_rect() -> Rect2:
	return Rect2(Vector2(52,48), Vector2(maxf(100.0,size.x-76.0), maxf(100.0,size.y-76.0)))

func _draw_xg() -> void:
	var rect := _plot_rect()
	draw_line(Vector2(rect.position.x,rect.end.y), rect.end, Color(0.7,0.7,0.7), 1.0)
	draw_line(rect.position, Vector2(rect.position.x,rect.end.y), Color(0.7,0.7,0.7), 1.0)
	var events: Array = match_result.get("events", [])
	var max_xg := 1.0
	var home_total := 0.0; var away_total := 0.0
	for event in events:
		if String(event.get("type","")) != "shot": continue
		if String(event.get("side","home")) == "home": home_total += float(event.get("xg",0.0))
		else: away_total += float(event.get("xg",0.0))
	max_xg = maxf(max_xg, maxf(home_total, away_total))
	var home_points := PackedVector2Array([Vector2(rect.position.x,rect.end.y)])
	var away_points := PackedVector2Array([Vector2(rect.position.x,rect.end.y)])
	home_total = 0.0; away_total = 0.0
	for event in events:
		if String(event.get("type","")) != "shot": continue
		var minute := clampf(float(event.get("minute",0.0)),0.0,90.0)
		if String(event.get("side","home")) == "home":
			home_total += float(event.get("xg",0.0)); home_points.append(_timeline_point(rect, minute, home_total, max_xg))
		else:
			away_total += float(event.get("xg",0.0)); away_points.append(_timeline_point(rect, minute, away_total, max_xg))
	home_points.append(_timeline_point(rect,90.0,home_total,max_xg)); away_points.append(_timeline_point(rect,90.0,away_total,max_xg))
	if home_points.size() > 1: draw_polyline(home_points, Color(0.3,0.65,1.0), 2.5)
	if away_points.size() > 1: draw_polyline(away_points, Color(1.0,0.4,0.4), 2.5)
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x,rect.position.y-8), "Home %.2f xG   Away %.2f xG" % [home_total,away_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _timeline_point(rect: Rect2, minute: float, xg: float, max_xg: float) -> Vector2:
	return Vector2(rect.position.x + minute/90.0*rect.size.x, rect.end.y - clampf(xg/maxf(max_xg,0.01),0.0,1.0)*rect.size.y)

func _draw_pitch() -> Rect2:
	var rect := Rect2(Vector2(90,48), Vector2(maxf(200.0,size.x-180.0),maxf(150.0,size.y-72.0)))
	draw_rect(rect, Color(0.06,0.28,0.12), true)
	draw_rect(rect, Color.WHITE, false, 1.5)
	draw_line(Vector2(rect.position.x+rect.size.x/2.0,rect.position.y),Vector2(rect.position.x+rect.size.x/2.0,rect.end.y),Color.WHITE,1.0)
	draw_circle(rect.get_center(),minf(rect.size.x,rect.size.y)*0.08,Color.WHITE,false,1.0)
	return rect

func _draw_shot_map() -> void:
	var rect := _draw_pitch()
	for event in match_result.get("events", []):
		if String(event.get("type","")) != "shot": continue
		var pos: Dictionary = event.get("position", {})
		var p := _pitch_point(rect,pos)
		var xg := clampf(float(event.get("xg",0.02)),0.01,0.8)
		var scored := String(event.get("outcome","")) == "goal"
		var color := Color(1.0,0.9,0.2) if scored else (Color(0.3,0.65,1.0) if String(event.get("side","home"))=="home" else Color(1.0,0.4,0.4))
		draw_circle(p,4.0+xg*12.0,color,true)
		draw_circle(p,4.0+xg*12.0,Color.WHITE,false,1.0)

func _draw_average_positions(draw_labels: bool) -> void:
	var rect := _draw_pitch()
	var averages := _average_positions()
	for side in ["home","away"]:
		var color := Color(0.3,0.65,1.0) if side=="home" else Color(1.0,0.4,0.4)
		for id in averages[side].keys():
			var p := _pitch_point(rect,averages[side][id])
			draw_circle(p,7.0,color)
			if draw_labels: draw_string(ThemeDB.fallback_font,p+Vector2(8,4),String(id).right(5),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)

func _draw_passing_network() -> void:
	var rect := _draw_pitch()
	var averages := _average_positions()
	var links := {}
	for event in match_result.get("events", []):
		if String(event.get("type", "")) not in ["pass", "through_ball", "cross"] or not bool(event.get("success", true)):
			continue
		var from := String(event.get("player_id", "")); var to := String(event.get("target_id", event.get("receiver_id", "")))
		if from == "" or to == "":
			continue
		var side := String(event.get("side", "home")); var key := "%s|%s|%s" % [side, from, to]
		links[key] = int(links.get(key, 0)) + (2 if String(event.get("type", "")) != "pass" else 1)
	for key in links.keys():
		var parts := String(key).split("|"); if parts.size()!=3: continue
		var side := String(parts[0]); var from := String(parts[1]); var to := String(parts[2])
		if not averages[side].has(from) or not averages[side].has(to): continue
		var color := Color(0.3,0.65,1.0,0.55) if side=="home" else Color(1.0,0.4,0.4,0.55)
		draw_line(_pitch_point(rect,averages[side][from]),_pitch_point(rect,averages[side][to]),color,clampf(1.0+float(links[key])*0.25,1.0,5.0))
	for side in ["home","away"]:
		var color := Color(0.3,0.65,1.0) if side=="home" else Color(1.0,0.4,0.4)
		for id in averages[side].keys(): draw_circle(_pitch_point(rect,averages[side][id]),5.0,color)

func _draw_heat_map() -> void:
	var rect := _draw_pitch()
	var frames: Array = match_result.get("spatial",{}).get("frames",[])
	var step := maxi(1,int(frames.size()/220.0))
	for i in range(0,frames.size(),step):
		var frame: Dictionary = frames[i]
		for side in ["home","away"]:
			var color := Color(0.2,0.55,1.0,0.035) if side=="home" else Color(1.0,0.3,0.3,0.035)
			for pos in frame.get(side,{}).values(): draw_circle(_pitch_point(rect,pos),16.0,color)

func _draw_possession_zones() -> void:
	var rect := _draw_pitch()
	var zones := []
	for i in range(9): zones.append({"home":0,"away":0})
	for frame in match_result.get("spatial",{}).get("frames",[]):
		var ball: Dictionary = frame.get("ball",{}); if ball.is_empty(): continue
		var x := clampi(int(float(ball.get("x",0.0))/105.0*3.0),0,2); var y := clampi(int(float(ball.get("y",0.0))/68.0*3.0),0,2)
		var index := y*3+x; var side := String(frame.get("possession","home")); if side not in ["home","away"]: side="home"
		zones[index][side] = int(zones[index][side])+1
	for y in range(3):
		for x in range(3):
			var cell := Rect2(rect.position+Vector2(rect.size.x*x/3.0,rect.size.y*y/3.0),Vector2(rect.size.x/3.0,rect.size.y/3.0))
			var z: Dictionary = zones[y*3+x]; var total := maxi(1,int(z.home)+int(z.away)); var home_share := float(z.home)/float(total)
			draw_rect(cell,Color(0.2+0.35*home_share,0.15,0.2+0.35*(1.0-home_share),0.42),true)
			draw_rect(cell,Color.WHITE,false,1.0)
			draw_string(ThemeDB.fallback_font,cell.get_center()+Vector2(-24,4),"%d/%d" % [int(z.home),int(z.away)],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)

func _average_positions() -> Dictionary:
	var sums := {"home":{},"away":{}}; var counts := {"home":{},"away":{}}
	for frame in match_result.get("spatial",{}).get("frames",[]):
		for side in ["home","away"]:
			for id in frame.get(side,{}).keys():
				var pos: Dictionary = frame[side][id]
				if not sums[side].has(id): sums[side][id] = Vector2.ZERO; counts[side][id]=0
				sums[side][id] += Vector2(float(pos.get("x",0.0)),float(pos.get("y",0.0))); counts[side][id]=int(counts[side][id])+1
	var out := {"home":{},"away":{}}
	for side in ["home","away"]:
		for id in sums[side].keys():
			var avg: Vector2 = sums[side][id]/float(maxi(1,int(counts[side][id]))); out[side][id]={"x":avg.x,"y":avg.y}
	return out

func _pitch_point(rect: Rect2, pos: Dictionary) -> Vector2:
	var x := float(pos.get("x", 52.5)); var y := float(pos.get("y", 34.0))
	if x <= 1.01 and y <= 1.01:
		return Vector2(rect.position.x + clampf(x, 0.0, 1.0) * rect.size.x, rect.position.y + clampf(y, 0.0, 1.0) * rect.size.y)
	return Vector2(rect.position.x + clampf(x / 105.0, 0.0, 1.0) * rect.size.x, rect.position.y + clampf(y / 68.0, 0.0, 1.0) * rect.size.y)

func _draw_advanced() -> void:
	var y := 58.0
	for side in ["home", "away"]:
		var detail: Dictionary = advanced_cache.get(side, {})
		var line := "%s  xA %.2f  xT %.2f  prog %d/%d  crosses %d  pressures %d  tilt %d  box %d" % [side.capitalize(), float(detail.get("xa", 0.0)), float(detail.get("xt", 0.0)), int(detail.get("progressive_passes", 0)), int(detail.get("progressive_carries", 0)), int(detail.get("crosses", 0)), int(detail.get("pressures", 0)), int(detail.get("field_tilt_actions", 0)), int(detail.get("passes_into_box", 0))]
		draw_string(ThemeDB.fallback_font, Vector2(18, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		y += 22.0
		var line2 := "  chances %d  SCA %d  deep %d  turnovers %d  set pieces %d" % [int(detail.get("chances_created", 0)), int(detail.get("shot_creating_actions", 0)), int(detail.get("deep_completions", 0)), int(detail.get("turnovers_won", 0)), int(detail.get("set_pieces", 0))]
		draw_string(ThemeDB.fallback_font, Vector2(18, y), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.85, 0.9))
		y += 26.0
