class_name AdvancedMatchAnalytics
extends RefCounted

func analyze(events: Array, pitch_length: float = 105.0) -> Dictionary:
	return {"home": _side(events, "home", pitch_length), "away": _side(events, "away", pitch_length)}

func team_summary(events: Array, side: String, pitch_length: float = 105.0) -> Dictionary:
	var detail := _side(events, side, pitch_length)
	var shots := 0
	var shots_on_target := 0
	var goals := 0
	var xg := 0.0
	var passes := 0
	var completed := 0
	for event in events:
		if String(event.get("side", "")) != side:
			continue
		match String(event.get("type", "")):
			"shot":
				shots += 1
				xg += float(event.get("xg", 0.0))
				if String(event.get("outcome", "")) in ["goal", "saved"]:
					shots_on_target += 1
				if String(event.get("outcome", "")) == "goal":
					goals += 1
			"pass", "through_ball", "cross":
				passes += 1
				if bool(event.get("success", false)):
					completed += 1
	detail["shots"] = shots
	detail["shots_on_target"] = shots_on_target
	detail["goals"] = goals
	detail["xg"] = snappedf(xg, 0.01)
	detail["xg_per_shot"] = snappedf(xg / maxf(1.0, float(shots)), 0.01)
	detail["pass_accuracy"] = snappedf(float(completed) / maxf(1.0, float(passes)) * 100.0, 0.1)
	detail["cross_accuracy"] = snappedf(float(detail.get("crosses_completed", detail.get("crosses", 0))) / maxf(1.0, float(detail.get("crosses", 0))) * 100.0, 0.1) if int(detail.get("crosses", 0)) > 0 else 0.0
	return detail

func _side(events: Array, side: String, pitch_length: float) -> Dictionary:
	var out := {"xa": 0.0, "xt": 0.0, "chances_created": 0, "progressive_passes": 0, "progressive_carries": 0, "pressures": 0, "tackles": 0, "crosses": 0, "crosses_completed": 0, "set_pieces": 0, "turnovers_won": 0, "final_third_actions": 0, "field_tilt_actions": 0, "passes_into_box": 0, "box_entries": 0, "shot_creating_actions": 0, "deep_completions": 0, "ppda_denominator": 0}
	var previous: Dictionary = {}
	for event in events:
		if String(event.get("side","")) != side: continue
		var kind:=String(event.get("type",""))
		var start_x:=_x(event,"start_x","x",pitch_length*0.5)
		var end_x:=_x(event,"target_x","end_x",start_x)
		var direction:=1.0 if side=="home" else -1.0
		var progress:=(end_x-start_x)*direction
		var attacking_x:=end_x if side=="home" else pitch_length-end_x
		var start_attacking_x:=start_x if side=="home" else pitch_length-start_x
		if kind in ["pass","through_ball"]:
			if progress>=10.0 or (start_attacking_x<0.6*pitch_length and attacking_x>=0.75*pitch_length): out.progressive_passes+=1
			if attacking_x>=0.83*pitch_length: out.passes_into_box+=1
			var completion:=1.0 if bool(event.get("success",false)) else 0.0
			var threat_gain:=maxf(0.0,_zone_value(attacking_x/pitch_length)-_zone_value(start_attacking_x/pitch_length))*completion
			out.xt+=threat_gain
			if previous.get("type","")=="shot" and int(previous.get("minute",-99))-int(event.get("minute",0))<=1:
				out.xa+=float(previous.get("xg",0.0)); out.chances_created+=1
		elif kind=="dribble":
			if progress>=7.0: out.progressive_carries+=1
			if start_attacking_x<0.83*pitch_length and attacking_x>=0.83*pitch_length: out.box_entries+=1
			out.xt+=maxf(0.0,_zone_value(attacking_x/pitch_length)-_zone_value(start_attacking_x/pitch_length))
		elif kind in ["pressure","counter_press"]: out.pressures+=1
		elif kind=="tackle": out.tackles+=1; out.turnovers_won+=1 if bool(event.get("success",false)) else 0
		elif kind=="interception": out.turnovers_won+=1
		elif kind == "cross":
			out.crosses += 1
			if bool(event.get("success", false)):
				out.crosses_completed += 1
		elif kind in ["corner", "free_kick", "penalty_awarded", "set_piece"]:
			out.set_pieces += 1
		if attacking_x >= 0.67 * pitch_length:
			out.final_third_actions += 1
		if attacking_x >= 0.80 * pitch_length and start_attacking_x < 0.80 * pitch_length and kind in ["pass", "through_ball", "cross", "dribble"]:
			out.deep_completions += 1
		if kind in ["pass", "through_ball", "cross", "dribble"]:
			out.ppda_denominator += 1
		if attacking_x>=0.58*pitch_length: out.field_tilt_actions+=1
		if kind=="shot":
			if not previous.is_empty() and int(event.get("minute",0))-int(previous.get("minute",0))<=1: out.shot_creating_actions+=1
		previous=event
	out.xa=snappedf(float(out.xa),0.01); out.xt=snappedf(float(out.xt),0.01)
	return out

func field_tilt(analysis: Dictionary) -> Dictionary:
	var h := float(analysis.get("home", {}).get("field_tilt_actions", 0)); var a := float(analysis.get("away", {}).get("field_tilt_actions", 0)); var total := maxf(1.0, h + a)
	return {"home": snappedf(h / total * 100.0, 0.1), "away": snappedf(a / total * 100.0, 0.1)}

func ppda(analysis: Dictionary, opponent_passes: Dictionary) -> Dictionary:
	# Passes per defensive action: lower = more intense press.
	var result := {}
	for side in ["home", "away"]:
		var actions := float(analysis.get(side, {}).get("pressures", 0)) + float(analysis.get(side, {}).get("tackles", 0)) + float(analysis.get(side, {}).get("turnovers_won", 0))
		var passes := float(opponent_passes.get("away" if side == "home" else "home", 100.0))
		result[side] = snappedf(passes / maxf(1.0, actions), 0.1)
	return result

func _zone_value(progress:float)->float:
	var p:=clampf(progress,0.0,1.0)
	return p*p*0.55 + (0.25 if p>=0.75 else 0.0) + (0.20 if p>=0.90 else 0.0)

func _x(event:Dictionary,primary:String,secondary:String,fallback:float)->float:
	if event.has(primary): return float(event[primary])
	if event.has(secondary): return float(event[secondary])
	var position=event.get("position",{})
	if typeof(position)==TYPE_DICTIONARY and position.has("x"): return float(position.x)
	var target=event.get("target",{})
	if primary=="target_x" and typeof(target)==TYPE_DICTIONARY and target.has("x"): return float(target.x)
	return fallback
