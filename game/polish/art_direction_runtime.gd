extends Node

## Screen-specific vector artwork and identity layer for Football Dynasty.
## Artwork is drawn with Godot primitives so it is resolution-independent,
## offline, copyright-safe and cheap enough for Android/Web GL compatibility.

const TAB_ART := {
	"Dashboard": "stadium",
	"Squad": "squad",
	"Tactics": "tactics",
	"Transfers": "transfer",
	"Scouting": "scouting",
	"Finances": "finance",
	"Board": "board",
	"Inbox": "inbox",
	"News": "news",
	"Match Analysis": "analysis",
	"Medical": "medical",
	"Training": "training",
	"Competitions": "trophy",
	"Club": "club",
	"Staff": "staff",
	"Youth": "youth",
	"Schedule": "calendar",
	"World History": "history",
}

var _next_scan := 0

class ScreenArtwork:
	extends Control
	var kind := "stadium"
	var accent := Color(0.43, 0.42, 1.0, 1.0)

	func configure(value: String, color: Color) -> void:
		kind = value
		accent = color
		queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		if size.x < 4.0 or size.y < 4.0:
			return
		var rect := Rect2(Vector2.ZERO, size)
		draw_style_box(_background_box(), rect)
		_draw_glow()
		match kind:
			"stadium": _draw_stadium()
			"squad": _draw_squad()
			"tactics": _draw_tactics()
			"transfer": _draw_transfer()
			"scouting": _draw_scouting()
			"finance": _draw_finance()
			"board": _draw_board()
			"inbox": _draw_inbox()
			"news": _draw_news()
			"analysis": _draw_analysis()
			"medical": _draw_medical()
			"training": _draw_training()
			"trophy": _draw_trophy()
			"club": _draw_club()
			"staff": _draw_staff()
			"youth": _draw_youth()
			"calendar": _draw_calendar()
			"history": _draw_history()
			"player": _draw_player()
			"empty": _draw_empty()
			_: _draw_stadium()

	func _background_box() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.026, 0.043, 0.078, 0.94)
		box.border_color = Color(accent.r, accent.g, accent.b, 0.28)
		box.set_border_width_all(1)
		box.set_corner_radius_all(16)
		return box

	func _draw_glow() -> void:
		var c := Color(accent.r, accent.g, accent.b, 0.08)
		draw_circle(Vector2(size.x * 0.82, size.y * 0.35), minf(size.x, size.y) * 0.72, c)
		for i in range(6):
			var x := size.x * (0.08 + float(i) * 0.16)
			draw_line(Vector2(x, size.y), Vector2(x + size.y * 0.65, 0), Color(1, 1, 1, 0.018), 1.0)

	func _line_color(alpha := 0.58) -> Color:
		return Color(accent.r, accent.g, accent.b, alpha)

	func _draw_stadium() -> void:
		var w := size.x; var h := size.y
		var pitch := Rect2(w * 0.08, h * 0.48, w * 0.84, h * 0.40)
		draw_rect(pitch, Color(0.08, 0.24, 0.20, 0.68), true)
		draw_rect(pitch, Color(0.50, 1.0, 0.78, 0.42), false, 2.0)
		draw_line(Vector2(w * 0.50, pitch.position.y), Vector2(w * 0.50, pitch.end.y), Color(0.8,1,0.9,0.35), 2.0)
		draw_circle(Vector2(w * 0.50, pitch.get_center().y), h * 0.075, Color(0.8,1,0.9,0.35), false, 2.0)
		for row in range(3):
			var y := h * (0.14 + row * 0.09)
			draw_arc(Vector2(w * 0.50, y + h * 0.35), w * (0.38 + row * 0.05), PI, TAU, 48, Color(0.55,0.65,0.85,0.18), 5.0)
		for x in [0.18,0.31,0.44,0.57,0.70,0.83]:
			draw_circle(Vector2(w*x, h*0.34), 2.5, Color(1,1,1,0.52))

	func _draw_squad() -> void:
		var w := size.x; var h := size.y
		var positions := [Vector2(.50,.22),Vector2(.28,.40),Vector2(.50,.42),Vector2(.72,.40),Vector2(.20,.61),Vector2(.40,.61),Vector2(.60,.61),Vector2(.80,.61),Vector2(.30,.79),Vector2(.50,.78),Vector2(.70,.79)]
		for p in positions:
			draw_circle(Vector2(w*p.x,h*p.y), 12.0, Color(accent.r,accent.g,accent.b,0.76))
			draw_circle(Vector2(w*p.x,h*p.y), 17.0, Color(1,1,1,0.16), false, 2.0)
		draw_line(Vector2(w*.12,h*.90),Vector2(w*.88,h*.90),Color(1,1,1,.16),2)

	func _draw_tactics() -> void:
		var w := size.x; var h := size.y
		var field := Rect2(w*.10,h*.12,w*.80,h*.76)
		draw_rect(field,Color(.06,.24,.18,.65),true)
		draw_rect(field,Color(.70,1,.86,.32),false,2)
		draw_line(Vector2(w*.5,field.position.y),Vector2(w*.5,field.end.y),Color(.8,1,.9,.25),1)
		var nodes := [Vector2(.22,.28),Vector2(.42,.34),Vector2(.66,.27),Vector2(.30,.57),Vector2(.56,.56),Vector2(.76,.67)]
		for i in range(nodes.size()):
			var p: Vector2 = nodes[i]
			draw_circle(Vector2(w*p.x,h*p.y),9,Color(accent.r,accent.g,accent.b,.85))
			if i < nodes.size()-1:
				var q: Vector2 = nodes[i+1]
				draw_dashed_line(Vector2(w*p.x,h*p.y),Vector2(w*q.x,h*q.y),Color(1,1,1,.28),2,8)

	func _draw_transfer() -> void:
		var w := size.x; var h := size.y
		_draw_person(Vector2(w*.24,h*.50), h*.16)
		_draw_person(Vector2(w*.76,h*.50), h*.16)
		var y := h*.50
		draw_line(Vector2(w*.36,y-h*.08),Vector2(w*.64,y-h*.08),_line_color(.8),5)
		draw_colored_polygon(PackedVector2Array([Vector2(w*.64,y-h*.08),Vector2(w*.59,y-h*.13),Vector2(w*.59,y-h*.03)]),_line_color(.8))
		draw_line(Vector2(w*.64,y+h*.08),Vector2(w*.36,y+h*.08),Color(.25,.88,.75,.75),5)
		draw_colored_polygon(PackedVector2Array([Vector2(w*.36,y+h*.08),Vector2(w*.41,y+h*.03),Vector2(w*.41,y+h*.13)]),Color(.25,.88,.75,.75))

	func _draw_scouting() -> void:
		var w := size.x; var h := size.y
		var center := Vector2(w*.44,h*.48); var r := h*.22
		draw_circle(center,r,Color(accent.r,accent.g,accent.b,.10),true)
		draw_circle(center,r,_line_color(.65),false,5)
		draw_line(center+Vector2(r*.7,r*.7),Vector2(w*.72,h*.82),_line_color(.75),10)
		_draw_person(center,h*.10)
		for a in [0.0,TAU/3.0,2.0*TAU/3.0]:
			var p := center + Vector2(cos(a),sin(a))*r*.72
			draw_circle(p,4,Color(.25,.88,.75,.85))

	func _draw_finance() -> void:
		var w := size.x; var h := size.y
		var base := Vector2(w*.12,h*.82)
		var points := PackedVector2Array([base,Vector2(w*.28,h*.65),Vector2(w*.43,h*.70),Vector2(w*.58,h*.42),Vector2(w*.74,h*.48),Vector2(w*.88,h*.20)])
		for i in range(points.size()-1): draw_line(points[i],points[i+1],_line_color(.88),5)
		for p in points: draw_circle(p,6,Color(.24,.88,.75,1))
		for i in range(5):
			var x := w*(.18+i*.14); var bh := h*(.14+i*.055)
			draw_rect(Rect2(x,h*.82-bh,w*.065,bh),Color(accent.r,accent.g,accent.b,.18),true)

	func _draw_board() -> void:
		var w := size.x; var h := size.y
		draw_rect(Rect2(w*.17,h*.60,w*.66,h*.16),Color(.15,.11,.10,.70),true)
		for x in [.26,.42,.58,.74]: _draw_person(Vector2(w*x,h*.42),h*.095)
		draw_line(Vector2(w*.20,h*.78),Vector2(w*.80,h*.78),_line_color(.38),3)

	func _draw_inbox() -> void:
		var w := size.x; var h := size.y
		var r := Rect2(w*.19,h*.22,w*.62,h*.54)
		draw_rect(r,Color(.08,.12,.21,.88),true)
		draw_rect(r,_line_color(.60),false,4)
		draw_line(r.position,Vector2(r.get_center().x,r.position.y+h*.25),_line_color(.55),4)
		draw_line(Vector2(r.end.x,r.position.y),Vector2(r.get_center().x,r.position.y+h*.25),_line_color(.55),4)

	func _draw_news() -> void:
		var w := size.x; var h := size.y
		draw_rect(Rect2(w*.16,h*.20,w*.68,h*.58),Color(.06,.09,.16,.86),true)
		draw_rect(Rect2(w*.20,h*.26,w*.30,h*.35),Color(accent.r,accent.g,accent.b,.16),true)
		for y in [.29,.39,.49,.59,.69]: draw_line(Vector2(w*.55,h*y),Vector2(w*.78,h*y),Color(1,1,1,.24),3)
		draw_circle(Vector2(w*.35,h*.43),h*.10,_line_color(.55),false,4)

	func _draw_analysis() -> void:
		var w := size.x; var h := size.y
		var field := Rect2(w*.08,h*.16,w*.58,h*.68)
		draw_rect(field,Color(.05,.22,.17,.58),true); draw_rect(field,Color(.7,1,.86,.28),false,2)
		for i in range(14):
			var px := field.position.x + fmod(float(i*83),field.size.x)
			var py := field.position.y + fmod(float(i*47),field.size.y)
			draw_circle(Vector2(px,py),10+float((i%3)*5),Color(accent.r,accent.g,accent.b,.035),true)
		var graph := [Vector2(w*.70,h*.70),Vector2(w*.75,h*.50),Vector2(w*.80,h*.60),Vector2(w*.85,h*.32),Vector2(w*.91,h*.24)]
		for i in range(graph.size()-1): draw_line(graph[i],graph[i+1],Color(.25,.88,.75,.82),4)

	func _draw_medical() -> void:
		var w := size.x; var h := size.y
		var y := h*.52
		var pts := PackedVector2Array([Vector2(w*.10,y),Vector2(w*.28,y),Vector2(w*.35,h*.34),Vector2(w*.43,h*.70),Vector2(w*.51,h*.43),Vector2(w*.61,y),Vector2(w*.90,y)])
		for i in range(pts.size()-1): draw_line(pts[i],pts[i+1],Color(.95,.35,.44,.88),5)
		draw_circle(Vector2(w*.76,h*.38),h*.13,Color(.95,.35,.44,.11),true)
		draw_rect(Rect2(w*.735,h*.27,w*.05,h*.22),Color(.95,.35,.44,.60),true)
		draw_rect(Rect2(w*.69,h*.35,w*.14,h*.06),Color(.95,.35,.44,.60),true)

	func _draw_training() -> void:
		var w := size.x; var h := size.y
		for i in range(5):
			var x := w*(.18+i*.15)
			var cone := PackedVector2Array([Vector2(x,h*.70),Vector2(x+w*.035,h*.42),Vector2(x+w*.07,h*.70)])
			draw_colored_polygon(cone,Color(.98,.65,.20,.72))
			draw_line(Vector2(x-w*.04,h*.78),Vector2(x+w*.11,h*.78),Color(1,1,1,.18),3)
		draw_dashed_line(Vector2(w*.12,h*.28),Vector2(w*.88,h*.28),_line_color(.45),2,10)

	func _draw_trophy() -> void:
		var w := size.x; var h := size.y
		var gold := Color(.96,.72,.24,.88)
		draw_arc(Vector2(w*.50,h*.38),h*.18,0,PI,32,gold,8)
		draw_rect(Rect2(w*.46,h*.38,w*.08,h*.27),gold,true)
		draw_rect(Rect2(w*.39,h*.68,w*.22,h*.07),gold,true)
		draw_arc(Vector2(w*.39,h*.38),h*.12,PI*.55,PI*1.45,24,gold,5)
		draw_arc(Vector2(w*.61,h*.38),h*.12,-PI*.45,PI*.45,24,gold,5)

	func _draw_club() -> void:
		var w := size.x; var h := size.y
		var shield := PackedVector2Array([Vector2(w*.50,h*.15),Vector2(w*.72,h*.25),Vector2(w*.68,h*.62),Vector2(w*.50,h*.84),Vector2(w*.32,h*.62),Vector2(w*.28,h*.25)])
		draw_colored_polygon(shield,Color(accent.r,accent.g,accent.b,.22))
		for i in range(shield.size()): draw_line(shield[i],shield[(i+1)%shield.size()],_line_color(.8),4)
		draw_circle(Vector2(w*.50,h*.45),h*.12,Color(.25,.88,.75,.28),false,5)

	func _draw_staff() -> void:
		var w := size.x; var h := size.y
		_draw_person(Vector2(w*.50,h*.40),h*.13)
		_draw_person(Vector2(w*.28,h*.58),h*.09)
		_draw_person(Vector2(w*.72,h*.58),h*.09)
		draw_line(Vector2(w*.36,h*.63),Vector2(w*.44,h*.53),_line_color(.35),3)
		draw_line(Vector2(w*.64,h*.63),Vector2(w*.56,h*.53),_line_color(.35),3)

	func _draw_youth() -> void:
		var w := size.x; var h := size.y
		draw_line(Vector2(w*.5,h*.78),Vector2(w*.5,h*.30),Color(.30,.85,.58,.72),6)
		for side in [-1,1]:
			draw_arc(Vector2(w*.5,h*.48),h*.19,PI*.25 if side>0 else PI*.75,PI*.75 if side>0 else PI*1.25,24,Color(.30,.85,.58,.62),5)
		draw_circle(Vector2(w*.5,h*.23),h*.06,Color(accent.r,accent.g,accent.b,.8))

	func _draw_calendar() -> void:
		var w := size.x; var h := size.y
		var r := Rect2(w*.22,h*.16,w*.56,h*.66)
		draw_rect(r,Color(.06,.10,.18,.85),true); draw_rect(r,_line_color(.62),false,4)
		draw_rect(Rect2(r.position.x,r.position.y,r.size.x,h*.13),Color(accent.r,accent.g,accent.b,.26),true)
		for row in range(3):
			for col in range(5): draw_circle(Vector2(w*(.30+col*.10),h*(.42+row*.13)),4,Color(1,1,1,.38))

	func _draw_history() -> void:
		var w := size.x; var h := size.y
		draw_line(Vector2(w*.14,h*.50),Vector2(w*.86,h*.50),_line_color(.55),4)
		for i in range(5):
			var x := w*(.18+i*.16); draw_circle(Vector2(x,h*.50),9,Color(accent.r,accent.g,accent.b,.82))
			var top := h*(.27 if i%2==0 else .68); draw_line(Vector2(x,h*.50),Vector2(x,top),Color(1,1,1,.18),2)

	func _draw_player() -> void:
		var w := size.x; var h := size.y
		_draw_person(Vector2(w*.25,h*.46),h*.18)
		for i in range(4):
			var y := h*(.25+i*.16)
			draw_rect(Rect2(w*.48,y,w*.36,h*.055),Color(1,1,1,.08),true)
			draw_rect(Rect2(w*.48,y,w*(.14+i*.045),h*.055),Color(accent.r,accent.g,accent.b,.62),true)
		draw_circle(Vector2(w*.25,h*.46),h*.28,Color(accent.r,accent.g,accent.b,.05),true)

	func _draw_empty() -> void:
		var w := size.x; var h := size.y
		draw_circle(Vector2(w*.5,h*.44),h*.20,Color(accent.r,accent.g,accent.b,.09),true)
		draw_circle(Vector2(w*.5,h*.44),h*.14,_line_color(.45),false,4)
		draw_line(Vector2(w*.42,h*.72),Vector2(w*.58,h*.72),Color(1,1,1,.16),3)

	func _draw_person(center: Vector2, scale: float) -> void:
		draw_circle(center-Vector2(0,scale*.55),scale*.28,Color(0.84,0.89,1.0,.82))
		draw_circle(center+Vector2(0,scale*.15),scale*.52,Color(accent.r,accent.g,accent.b,.42),true)
		draw_arc(center+Vector2(0,scale*.15),scale*.52,PI,TAU,24,_line_color(.62),3)


func _ready() -> void:
	set_process(true)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 1200
	_scan()

func _on_node_added(_node: Node) -> void:
	call_deferred("_scan")

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		_decorate_tabs(node as TabContainer)
	if node is AcceptDialog:
		_decorate_player_dialog(node as AcceptDialog)
	if _is_match_viewer(node):
		_decorate_match_viewer(node)
	if node is Label:
		_decorate_empty_state(node as Label)
	for child in node.get_children():
		_scan_node(child)

func _decorate_tabs(tabs: TabContainer) -> void:
	for i in range(tabs.get_tab_count()):
		var title := tabs.get_tab_title(i)
		if not TAB_ART.has(title):
			continue
		var page := tabs.get_tab_control(i)
		if page == null or page.has_meta("screen_art_complete"):
			continue
		var box := _first_vbox(page)
		if box == null:
			continue
		page.set_meta("screen_art_complete", true)
		var art := ScreenArtwork.new()
		art.name = "%sHeroArt" % title.replace(" ", "")
		art.custom_minimum_size = Vector2(360, 138 if OS.has_feature("mobile") else 172)
		art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		art.configure(String(TAB_ART[title]), _accent_for(title))
		box.add_child(art)
		var target := mini(1, box.get_child_count()-1)
		box.move_child(art, target)

func _decorate_player_dialog(dialog: AcceptDialog) -> void:
	if dialog.has_meta("player_art_complete"):
		return
	var script = dialog.get_script()
	if script == null or not String(script.resource_path).ends_with("game/presentation/player_profile_dialog.gd"):
		return
	var tabs := _first_tabs(dialog)
	if tabs == null:
		return
	var overview := _tab_page(tabs, "Overview")
	if overview == null:
		return
	var box := _first_vbox(overview)
	if box == null:
		return
	dialog.set_meta("player_art_complete", true)
	var art := ScreenArtwork.new()
	art.name = "PlayerProfileHeroArt"
	art.custom_minimum_size = Vector2(500, 185)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.configure("player", Color(0.37,0.61,1.0,1.0))
	box.add_child(art)
	box.move_child(art, 0)

func _decorate_match_viewer(viewer: Node) -> void:
	if viewer.has_meta("match_art_complete"):
		return
	if not viewer is Control:
		return
	viewer.set_meta("match_art_complete", true)
	var frame := ScreenArtwork.new()
	frame.name = "MatchdayAtmosphereArt"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.z_index = -50
	frame.configure("stadium", Color(0.20,0.88,0.76,1.0))
	(viewer as Control).add_child(frame)
	(viewer as Control).move_child(frame, 0)

func _decorate_empty_state(label: Label) -> void:
	if label.has_meta("empty_art_checked"):
		return
	label.set_meta("empty_art_checked", true)
	var text := label.text.strip_edges().to_lower()
	if not (text.begins_with("no ") or text.contains("nothing to show") or text.contains("no current")):
		return
	var parent := label.get_parent()
	if parent == null or not parent is Container or parent.has_meta("empty_art_added"):
		return
	parent.set_meta("empty_art_added", true)
	var art := ScreenArtwork.new()
	art.name = "EmptyStateArt"
	art.custom_minimum_size = Vector2(200, 88)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.configure("empty", Color(0.43,0.42,1.0,1.0))
	parent.add_child(art)
	parent.move_child(art, maxi(0, label.get_index()))

func _accent_for(title: String) -> Color:
	match title:
		"Match Analysis": return Color(0.20,0.88,0.76,1.0)
		"Transfers", "Scouting": return Color(0.98,0.68,0.24,1.0)
		"Medical": return Color(0.96,0.38,0.44,1.0)
		"Training", "Youth": return Color(0.28,0.84,0.58,1.0)
		"Finances", "Board": return Color(0.63,0.49,1.0,1.0)
		"News", "Inbox": return Color(0.32,0.67,1.0,1.0)
		"Competitions", "World History": return Color(0.96,0.72,0.24,1.0)
		_: return Color(0.43,0.42,1.0,1.0)

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		return node
	for child in node.get_children():
		var found := _first_vbox(child)
		if found != null:
			return found
	return null

func _first_tabs(node: Node) -> TabContainer:
	if node is TabContainer:
		return node
	for child in node.get_children():
		var found := _first_tabs(child)
		if found != null:
			return found
	return null

func _tab_page(tabs: TabContainer, title: String) -> Control:
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i) == title:
			return tabs.get_tab_control(i)
	return null

func _is_match_viewer(node: Node) -> bool:
	var script = node.get_script()
	return script != null and String(script.resource_path).ends_with("game/match_viewer.gd")
