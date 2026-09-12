extends Node

const MatchViewer = preload("res://game/match_viewer.gd")

var _next_scan := 0

class BroadcastOverlay:
	extends Control
	var viewer: Control
	func setup(target: Control) -> void:
		viewer = target
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		queue_redraw()
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if viewer == null: return
		var w := size.x; var h := size.y
		# Stadium/crowd bands around the playable surface.
		draw_rect(Rect2(0,0,w,34),Color(0.015,0.02,0.04,0.92),true)
		draw_rect(Rect2(0,h-30,w,30),Color(0.015,0.02,0.04,0.84),true)
		for i in range(26):
			var x := 12.0 + float(i) * maxf(18.0,(w-24.0)/26.0)
			var c := Color(0.20,0.86,0.91,0.22) if i%3==0 else Color(1,1,1,0.13)
			draw_circle(Vector2(x,16),2.0,c)
		# Broadcast score bug.
		var result: Dictionary = viewer.get("match_result") if viewer != null else {}
		var home := String(result.get("home_name",result.get("home_team","HOME"))).left(18)
		var away := String(result.get("away_name",result.get("away_team","AWAY"))).left(18)
		var hg := int(result.get("home_goals",result.get("home_score",0)))
		var ag := int(result.get("away_goals",result.get("away_score",0)))
		var minute := int(viewer.call("current_minute")) if viewer.has_method("current_minute") else 0
		var score_rect := Rect2(w*0.5-185,7,370,48)
		draw_rect(score_rect,Color(0.02,0.03,0.07,0.96),true)
		draw_rect(score_rect,Color(0.08,0.86,0.91,0.58),false,2)
		draw_string(ThemeDB.fallback_font,Vector2(score_rect.position.x+16,38),home,HORIZONTAL_ALIGNMENT_LEFT,120,14,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(score_rect.position.x+142,39),"%d  -  %d"%[hg,ag],HORIZONTAL_ALIGNMENT_CENTER,86,20,Color(0.95,0.77,0.28))
		draw_string(ThemeDB.fallback_font,Vector2(score_rect.position.x+238,38),away,HORIZONTAL_ALIGNMENT_RIGHT,116,14,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(score_rect.end.x+12,37),"%d'"%minute,HORIZONTAL_ALIGNMENT_LEFT,48,15,Color(0.08,0.86,0.91))
		# Timeline / match intensity strip.
		var position := float(viewer.call("timeline_position")) if viewer.has_method("timeline_position") else 0.0
		draw_rect(Rect2(18,h-18,w-36,5),Color(1,1,1,0.12),true)
		draw_rect(Rect2(18,h-18,(w-36)*position,5),Color(0.08,0.86,0.91,0.9),true)

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan: return
	_next_scan = now + 800
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if _is_viewer(node): _enhance(node as Control)
	for child in node.get_children(): _scan_node(child)

func _is_viewer(node: Node) -> bool:
	var script = node.get_script()
	return script != null and String(script.resource_path).ends_with("game/match_viewer.gd")

func _enhance(viewer: Control) -> void:
	if viewer.has_meta("ui2_matchday"): return
	viewer.set_meta("ui2_matchday",true)
	viewer.set("show_player_labels",true)
	viewer.set("show_condition_indicators",true)
	var overlay := BroadcastOverlay.new()
	overlay.name = "UI2BroadcastOverlay"
	viewer.add_child(overlay)
	overlay.setup(viewer)
