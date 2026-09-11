extends Node

const HistoryService = preload("res://application/career/world_history_service.gd")
const MatchViewModes = preload("res://game/analysis/match_view_modes.gd")
const MatchAnalysisPanel = preload("res://game/analysis/match_analysis_panel.gd")

var _scan_at := 0
var _cue_player: AudioStreamPlayer
var _seen_events := {}

func _ready() -> void:
	_cue_player = AudioStreamPlayer.new(); add_child(_cue_player); set_process(true); call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _scan_at: return
	_scan_at = now + 900; _scan()

func _scan() -> void: _scan_node(get_tree().root)
func _scan_node(node: Node) -> void:
	if node is Control: _apply_accessibility(node)
	if node is TabContainer: _complete_history_tab(node); _complete_match_analysis(node)
	if _is_match_viewer(node): _wire_match_cues(node)
	for child in node.get_children(): _scan_node(child)

func _apply_accessibility(control: Control) -> void:
	if control is BaseButton:
		control.focus_mode=Control.FOCUS_ALL
		if control.tooltip_text.is_empty() and not String(control.text).is_empty(): control.tooltip_text=String(control.text)
	elif control is LineEdit:
		control.focus_mode=Control.FOCUS_ALL
		if control.tooltip_text.is_empty() and not control.placeholder_text.is_empty(): control.tooltip_text=control.placeholder_text
	elif control is OptionButton or control is Range: control.focus_mode=Control.FOCUS_ALL

func _complete_history_tab(tabs: TabContainer) -> void:
	if tabs.has_meta("completion_history"): return
	var history_tab:Control=null
	for child in tabs.get_children():
		if String(child.name)=="World History": history_tab=child; break
	if history_tab==null: return
	var session=_career_session(tabs); if session==null: return
	var box:=_first_vbox(history_tab); if box==null: return
	tabs.set_meta("completion_history",true)
	var history:Dictionary=HistoryService.new().build(session.world,session.history)
	_add_heading(box,tr("League-position history")); _add_rows(box,history.get("league_positions",[]),func(row): return tr("%s — %s: %s finished %d%s (%d pts)")%[String(row.get("season","")),String(row.get("competition","")),String(row.get("club","")),int(row.get("position",0)),_ordinal_suffix(int(row.get("position",0))),int(row.get("points",0))])
	_add_heading(box,tr("Player biographies")); _add_rows(box,history.get("biographies",[]),func(row): return "%s — %s"%[String(row.get("name","")),String(row.get("summary",""))])

func _complete_match_analysis(tabs: TabContainer) -> void:
	if tabs.has_meta("completion_analysis"): return
	var analysis_tab:Control=null
	for child in tabs.get_children():
		if String(child.name)=="Match Analysis": analysis_tab=child; break
	if analysis_tab==null: return
	var session=_career_session(tabs)
	if session==null or not session.world.has("last_managed_match"): return
	var box:=_first_vbox(analysis_tab); var viewer:=_find_match_viewer(analysis_tab)
	if box==null or viewer==null: return
	tabs.set_meta("completion_analysis",true)
	var original:Dictionary=session.world.last_managed_match.get("result",{}).duplicate(true)
	_add_heading(box,tr("Viewing mode")); var viewing:=OptionButton.new()
	for mode in MatchViewModes.MODES: viewing.add_item(tr(String(mode)))
	viewing.tooltip_text=tr("Choose how much of the match timeline to replay"); box.add_child(viewing)
	viewing.item_selected.connect(func(index:int): var mode:=String(MatchViewModes.MODES[clampi(index,0,MatchViewModes.MODES.size()-1)]); viewer.set_match(MatchViewModes.new().filtered(original,mode)); if mode=="Instant": viewer.pause())
	_add_heading(box,tr("Event-derived analysis")); var analysis_choice:=OptionButton.new()
	for mode in MatchAnalysisPanel.MODES: analysis_choice.add_item(tr(String(mode)))
	box.add_child(analysis_choice); var panel=MatchAnalysisPanel.new(); panel.set_result(original); box.add_child(panel)
	analysis_choice.item_selected.connect(func(index:int): panel.set_analysis(String(MatchAnalysisPanel.MODES[clampi(index,0,MatchAnalysisPanel.MODES.size()-1)])))
	var summary:=Label.new(); summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; summary.text=_analysis_summary(original); box.add_child(summary)

func _analysis_summary(result:Dictionary)->String:
	var home_xg:=0.0; var away_xg:=0.0; var home_shots:=0; var away_shots:=0; var cards:=0
	for event in result.get("events",[]):
		match String(event.get("type","")):
			"shot":
				if String(event.get("side","home"))=="home": home_shots+=1; home_xg+=float(event.get("xg",0.0))
				else: away_shots+=1; away_xg+=float(event.get("xg",0.0))
			"card": cards+=1
	return tr("Shot quality: home %d shots / %.2f xG, away %d shots / %.2f xG. Cards: %d. All visualisations above are calculated from recorded match events and spatial frames.")%[home_shots,home_xg,away_shots,away_xg,cards]

func _first_vbox(node:Node)->VBoxContainer:
	if node is VBoxContainer: return node
	for child in node.get_children(): var found:=_first_vbox(child); if found!=null: return found
	return null
func _find_match_viewer(node:Node):
	if _is_match_viewer(node): return node
	for child in node.get_children(): var found=_find_match_viewer(child); if found!=null: return found
	return null
func _add_heading(parent:VBoxContainer,text:String)->void:
	var label:=Label.new(); label.text=text; label.add_theme_font_size_override("font_size",18); parent.add_child(label)
func _add_rows(parent:VBoxContainer,rows:Array,formatter:Callable)->void:
	if rows.is_empty(): var empty:=Label.new(); empty.text=tr("No historical records yet."); parent.add_child(empty); return
	for row in rows: var label:=Label.new(); label.text=String(formatter.call(row)); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label)
func _is_match_viewer(node:Node)->bool:
	var script=node.get_script(); return script!=null and String(script.resource_path).ends_with("game/match_viewer.gd")

func _wire_match_cues(viewer:Node)->void:
	if viewer.has_meta("completion_cues"): return
	viewer.set_meta("completion_cues",true)
	if viewer.has_signal("frame_changed"): viewer.frame_changed.connect(_on_match_frame.bind(viewer))
	if viewer.has_signal("playback_finished"): viewer.playback_finished.connect(_whistle.bind(2))

func _on_match_frame(_index:int,minute:int,viewer:Node)->void:
	if minute==45 or minute>=90:
		var whistle_key:="%s:whistle:%d"%[str(viewer.get_instance_id()),minute]
		if not _seen_events.has(whistle_key): _seen_events[whistle_key]=true; _whistle(1 if minute==45 else 2)
	var result:Dictionary=viewer.get("match_result")
	for event in result.get("events",[]):
		if int(event.get("minute",-1))!=minute: continue
		var type:=String(event.get("type",""))
		if type=="substitution":
			var sub_key:="%s:sub:%d:%s:%s"%[str(viewer.get_instance_id()),minute,String(event.get("player_out","")),String(event.get("player_in",""))]
			if not _seen_events.has(sub_key): _seen_events[sub_key]=true; _play_tone(760.0,0.08,0.18)
		var is_goal:=type=="goal" or (type=="shot" and String(event.get("outcome",""))=="goal")
		if is_goal:
			var goal_key:="%s:goal:%d:%s"%[str(viewer.get_instance_id()),minute,String(event.get("player_id",""))]
			if not _seen_events.has(goal_key): _seen_events[goal_key]=true; _play_tone(1320.0,0.30,0.30)

func _whistle(repeats:int=1)->void: _play_tone(1850.0 if repeats<=1 else 1650.0,0.12 if repeats<=1 else 0.22,0.24)
func _play_tone(frequency:float,seconds:float,amplitude:float)->void:
	var polish=get_node_or_null("/root/PolishRuntime")
	if polish!=null:
		var settings=polish.get("audio_settings")
		if typeof(settings)==TYPE_DICTIONARY:
			if bool(settings.get("mute",false)): return
			var linear:=clampf(float(settings.get("master",0.8))*float(settings.get("match",0.75)),0.001,1.0); _cue_player.volume_db=linear_to_db(linear)
	_cue_player.stream=_tone(frequency,seconds,amplitude); _cue_player.play()
func _tone(frequency:float,seconds:float,amplitude:float)->AudioStreamWAV:
	var rate:=22050; var samples:=maxi(1,int(rate*seconds)); var bytes:=PackedByteArray(); bytes.resize(samples*2)
	for i in range(samples): var envelope:=1.0-float(i)/float(samples); var value:=int(sin(TAU*frequency*float(i)/float(rate))*amplitude*envelope*32767.0); bytes.encode_s16(i*2,value)
	var stream:=AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=rate; stream.stereo=false; stream.data=bytes; return stream
func _career_session(node:Node):
	var current:Node=node
	while current!=null:
		var script=current.get_script(); if script!=null and String(script.resource_path).ends_with("game/career/career_app.gd"): return current.get("session"); current=current.get_parent()
	return null
func _ordinal_suffix(value:int)->String:
	var mod100:=value%100; if mod100 in [11,12,13]: return "th"
	match value%10: 1: return "st"; 2: return "nd"; 3: return "rd"; _: return "th"
