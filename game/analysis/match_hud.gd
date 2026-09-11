class_name MatchHud
extends VBoxContainer

var viewer
var result: Dictionary = {}
var _score: Label
var _stats: Label
var _commentary: Label

func setup(match_viewer, match_result: Dictionary) -> void:
	viewer = match_viewer
	result = match_result.duplicate(true)
	_build()
	if viewer.has_signal("frame_changed"):
		viewer.frame_changed.connect(_on_frame_changed)
	_on_frame_changed(int(viewer.get("frame_index")), int(viewer.call("current_minute")))

func _build() -> void:
	var title := Label.new(); title.text = tr("MATCH HUD"); title.add_theme_font_size_override("font_size",18); add_child(title)
	_score = Label.new(); _score.add_theme_font_size_override("font_size",20); add_child(_score)
	_stats = Label.new(); add_child(_stats)
	_commentary = Label.new(); _commentary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(_commentary)
	var overlays := HBoxContainer.new(); add_child(overlays)
	var labels := CheckBox.new(); labels.text=tr("Player labels"); labels.button_pressed=bool(viewer.get("show_player_labels")); labels.toggled.connect(func(value): viewer.set("show_player_labels",value); viewer.queue_redraw()); overlays.add_child(labels)
	var pressing := CheckBox.new(); pressing.text=tr("Pressing overlay"); pressing.button_pressed=bool(viewer.get("show_pressing_overlay")); pressing.toggled.connect(func(value): viewer.call("set_overlays",value,bool(viewer.get("show_marking_overlay")),bool(viewer.get("show_condition_indicators")))); overlays.add_child(pressing)
	var marking := CheckBox.new(); marking.text=tr("Marking overlay"); marking.button_pressed=bool(viewer.get("show_marking_overlay")); marking.toggled.connect(func(value): viewer.call("set_overlays",bool(viewer.get("show_pressing_overlay")),value,bool(viewer.get("show_condition_indicators")))); overlays.add_child(marking)
	var condition := CheckBox.new(); condition.text=tr("Condition indicators"); condition.button_pressed=bool(viewer.get("show_condition_indicators")); condition.toggled.connect(func(value): viewer.call("set_overlays",bool(viewer.get("show_pressing_overlay")),bool(viewer.get("show_marking_overlay")),value)); overlays.add_child(condition)

func _on_frame_changed(_index: int, minute: int) -> void:
	var live := _live_stats(minute)
	_score.text = tr("%d'   HOME %d — %d AWAY") % [minute,int(live.home_goals),int(live.away_goals)]
	_stats.text = tr("Shots %d–%d   xG %.2f–%.2f   Possession %.0f%%–%.0f%%") % [int(live.home_shots),int(live.away_shots),float(live.home_xg),float(live.away_xg),float(live.home_possession),float(live.away_possession)]
	_commentary.text = _commentary_at(minute)

func _live_stats(minute: int) -> Dictionary:
	var home_goals:=0; var away_goals:=0; var home_shots:=0; var away_shots:=0; var home_xg:=0.0; var away_xg:=0.0
	for event in result.get("events",[]):
		if int(event.get("minute",0))>minute: continue
		var side:=String(event.get("side","home")); var type:=String(event.get("type",""))
		if type=="shot":
			if side=="home": home_shots+=1; home_xg+=float(event.get("xg",0.0))
			else: away_shots+=1; away_xg+=float(event.get("xg",0.0))
			if String(event.get("outcome",""))=="goal":
				if side=="home": home_goals+=1
				else: away_goals+=1
		elif type=="goal":
			if side=="home": home_goals+=1
			else: away_goals+=1
	var possession := _possession_to_minute(minute)
	return {"home_goals":home_goals,"away_goals":away_goals,"home_shots":home_shots,"away_shots":away_shots,"home_xg":home_xg,"away_xg":away_xg,"home_possession":possession.home,"away_possession":possession.away}

func _possession_to_minute(minute: int) -> Dictionary:
	var home:=0; var away:=0
	for frame in result.get("spatial",{}).get("frames",[]):
		if int(float(frame.get("minute",0.0)))>minute: break
		if String(frame.get("possession",frame.get("possession_side","home")))=="away": away+=1
		else: home+=1
	var total:=maxi(1,home+away)
	return {"home":float(home)*100.0/float(total),"away":float(away)*100.0/float(total)}

func _commentary_at(minute: int) -> String:
	var best: Dictionary = {}; var best_minute:=-999
	for event in result.get("events",[]):
		var m:=int(event.get("minute",0))
		if m<=minute and m>=best_minute: best=event; best_minute=m
	if best.is_empty(): return tr("The match is settling into its shape.")
	var side:=String(best.get("side","home")).capitalize(); var player:=String(best.get("player_id","Player")); var event_type:=String(best.get("type","play"))
	match event_type:
		"shot":
			var outcome:=String(best.get("outcome","shot")); return tr("%d' %s: %s takes a %.2f xG shot — %s.") % [best_minute,side,player,float(best.get("xg",0.0)),outcome]
		"goal": return tr("%d' GOAL for %s — %s finishes the move.") % [best_minute,side,player]
		"card": return tr("%d' %s card for %s (%s).") % [best_minute,String(best.get("card","yellow")).capitalize(),player,side]
		"substitution": return tr("%d' %s substitution: %s off, %s on.") % [best_minute,side,String(best.get("player_out","")),String(best.get("player_in",""))]
		"corner": return tr("%d' Corner to %s.") % [best_minute,side]
		"free_kick": return tr("%d' Free kick to %s.") % [best_minute,side]
		"interception": return tr("%d' %s regains possession through %s.") % [best_minute,side,player]
		_: return tr("%d' %s — %s.") % [best_minute,side,event_type.replace("_"," ")]
