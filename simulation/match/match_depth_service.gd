class_name MatchDepthService
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func enrich_event(event: Dictionary, home: Array, away: Array, home_tactic: Dictionary, away_tactic: Dictionary, seed: int) -> Array:
	var result: Array = []
	var enriched := event.duplicate(true)
	var side := String(enriched.get("side", "home"))
	var team: Array = home if side == "home" else away
	var opposition: Array = away if side == "home" else home
	var player := _player(team, String(enriched.get("player_id", "")))
	var tactic := home_tactic if side == "home" else away_tactic
	_apply_role_signature(enriched, player, tactic)
	_apply_physical_state(enriched, player)
	result.append(enriched)

	match String(enriched.get("type", "")):
		"corner":
			result.append(_set_piece_event(enriched, team, opposition, "corner", seed))
		"foul":
			if bool(enriched.get("advantage", false)):
				return result
			if bool(enriched.get("penalty", false)):
				result.append(_set_piece_event(enriched, team, opposition, "penalty", seed))
			else:
				result.append(_set_piece_event(enriched, team, opposition, "free_kick", seed))
		"throw_in":
			result.append(_set_piece_event(enriched, team, opposition, "throw_in", seed))
		"shot":
			var keeper_event := _goalkeeper_event(enriched, opposition, seed)
			if not keeper_event.is_empty(): result.append(keeper_event)
	return result

func advanced_metrics(events: Array, side: String) -> Dictionary:
	var values := {"xa":0.0,"xt":0.0,"progressive_passes":0,"progressive_carries":0,"pressures":0,"tackles":0,"crosses":0,"set_pieces":0,"turnovers_won":0,"field_tilt_actions":0,"final_third_actions":0,"chances_created":0}
	for event in events:
		if String(event.get("side", "")) != side: continue
		var kind := String(event.get("type", ""))
		var x := float(event.get("x", event.get("start_x", 52.5)))
		var target_x := float(event.get("target_x", event.get("end_x", x)))
		var direction := 1.0 if side == "home" else -1.0
		var progression := (target_x - x) * direction
		if kind in ["pass","through_ball"] and progression >= 10.0:
			values.progressive_passes += 1
		if kind == "dribble" and progression >= 7.0:
			values.progressive_carries += 1
		if kind == "cross": values.crosses += 1
		if kind in ["corner","free_kick","penalty","set_piece"]: values.set_pieces += 1
		if kind in ["pressure","counter_press"]: values.pressures += 1
		if kind == "tackle": values.tackles += 1
		if kind in ["interception","tackle"] and bool(event.get("success", true)): values.turnovers_won += 1
		if target_x * direction > (70.0 if side == "home" else -35.0): values.final_third_actions += 1
		if target_x * direction > (61.0 if side == "home" else -44.0): values.field_tilt_actions += 1
		if bool(event.get("chance_created", false)): values.chances_created += 1
		values.xa += float(event.get("xa", 0.0))
		values.xt += float(event.get("xt", 0.0))
	values.xa = snappedf(float(values.xa), 0.01)
	values.xt = snappedf(float(values.xt), 0.01)
	return values

func _set_piece_event(source: Dictionary, team: Array, opposition: Array, kind: String, seed: int) -> Dictionary:
	var taker := _best_taker(team, kind)
	var targets := _aerial_targets(team, taker)
	var marker := _best_aerial_defender(opposition)
	var routine := "mixed"
	var key := int(source.get("minute", 0)) * 131 + _stable_key(String(taker.get("id", "")))
	var roll := SeededRngClass.unit_for(seed, key)
	if kind == "corner": routine = ["near_post","far_post","edge_of_box","short_corner"][mini(3, int(floor(roll * 4.0)))]
	elif kind == "free_kick": routine = "direct" if _quality(taker,["free_kicks","technique","finishing"]) > 0.62 and roll < 0.45 else "delivery"
	elif kind == "penalty": routine = "placed" if _quality(taker,["composure","finishing"]) >= 0.58 else "power"
	elif kind == "throw_in": routine = "long_throw" if _quality(taker,["strength","technique"]) > 0.62 else "retain_possession"
	return {"type":"set_piece","side":String(source.get("side","home")),"minute":int(source.get("minute",0)),"set_piece_type":kind,"routine":routine,"taker_id":String(taker.get("id","")),"primary_target_id":String(targets[0].get("id","")) if not targets.is_empty() else "","marker_id":String(marker.get("id","")),"marking":"zonal_plus_man" if not marker.is_empty() else "zonal","success":true,"reason_codes":["set_piece_routine_selected","specialist_taker_selected","aerial_matchup_selected"]}

func _goalkeeper_event(shot: Dictionary, defending_team: Array, seed: int) -> Dictionary:
	if defending_team.is_empty(): return {}
	var keeper: Dictionary = defending_team[0]
	var outcome := String(shot.get("outcome", "missed"))
	var keeper_quality := _quality(keeper,["reflexes","one_on_ones","goalkeeper_positioning","handling","aerial_reach"])
	var key := 900000 + int(shot.get("minute",0))*17 + _stable_key(String(keeper.get("id","")))
	var roll := SeededRngClass.unit_for(seed,key)
	var action := "set_position"
	if float(shot.get("xg",0.0)) >= 0.32: action = "close_angle"
	if bool(shot.get("cross_origin",false)): action = "claim_cross" if keeper_quality > 0.55 else "punch_cross"
	if bool(shot.get("through_ball",false)): action = "sweep_out" if keeper_quality > 0.58 else "hold_line"
	var handling := "clean"
	if outcome == "saved" and roll > lerpf(0.45,0.88,keeper_quality): handling = "rebound"
	elif outcome == "goal" and roll > 0.88 and keeper_quality < 0.48: handling = "handling_error"
	return {"type":"goalkeeper_action","side":"away" if String(shot.get("side","home"))=="home" else "home","minute":int(shot.get("minute",0)),"player_id":String(keeper.get("id","")),"action":action,"handling":handling,"shot_outcome":outcome,"distribution_intent":"quick_counter" if action in ["claim_cross","set_position"] and keeper_quality>0.62 else "secure_possession","success":outcome!="goal","reason_codes":["keeper_positioning","keeper_decision","keeper_handling"]}

func _apply_role_signature(event: Dictionary, player: Dictionary, tactic: Dictionary) -> void:
	var role := String(player.get("role", player.get("match_role", ""))).to_lower()
	var tags: Array = []
	match role:
		"mezzala": tags=["half_space","late_box_arrival","wide_drift"]
		"regista": tags=["deep_creator","switch_play","tempo_control"]
		"false_nine": tags=["drop_between_lines","link_play","create_space"]
		"target_forward": tags=["aerial_reference","hold_up","layoff"]
		"inverted_fullback","inverted_wing_back": tags=["invert_midfield","rest_defence","inside_support"]
		"ball_winning_midfielder": tags=["press_aggressively","screen_centre","duel_focus"]
		"advanced_playmaker": tags=["find_pockets","risk_pass","receive_between_lines"]
		"sweeper_keeper": tags=["high_start","sweep_space","short_distribution"]
		_: tags=["role_shape"]
	event["role_signature"] = tags
	var instructions: Array = []
	for key in ["width","directness","tempo","pressing","counter","counter_press","regroup","overlap","underlap","crossing","time_wasting","defensive_line","marking","offside_trap"]:
		if tactic.has(key): instructions.append({"instruction":key,"value":tactic[key]})
	event["instruction_context"] = instructions

func _apply_physical_state(event: Dictionary, player: Dictionary) -> void:
	event["body_orientation"] = String(player.get("body_orientation","open"))
	event["current_action"] = String(event.get("type",""))
	event["tactical_target"] = String(event.get("target_id", event.get("receiver_id", "")))
	if not event.has("ball_velocity"):
		var kind := String(event.get("type",""))
		event["ball_velocity"] = 27.0 if kind=="shot" else (18.0 if kind in ["pass","through_ball","cross"] else 8.0)

func _best_taker(team: Array, kind: String) -> Dictionary:
	var best := {}
	var best_score := -1.0
	for player in team:
		var score := _quality(player,["corners","crossing","technique"]) if kind=="corner" else (_quality(player,["penalties","finishing","composure"]) if kind=="penalty" else _quality(player,["free_kicks","passing","technique"]))
		if score > best_score:
			best = player; best_score = score
	return best

func _aerial_targets(team: Array, taker: Dictionary) -> Array:
	var rows: Array = []
	for player in team:
		if String(player.get("id","")) == String(taker.get("id","")): continue
		rows.append(player)
	rows.sort_custom(func(a:Dictionary,b:Dictionary): return _quality(a,["heading","jumping_reach","strength"]) > _quality(b,["heading","jumping_reach","strength"]))
	return rows.slice(0, mini(3, rows.size()))

func _best_aerial_defender(team: Array) -> Dictionary:
	var rows := _aerial_targets(team,{})
	return rows[0] if not rows.is_empty() else {}

func _player(team: Array, id: String) -> Dictionary:
	for player in team:
		if String(player.get("id","")) == id: return player
	return {}

func _quality(player: Dictionary, keys: Array) -> float:
	if player.is_empty(): return 0.5
	var attrs: Dictionary = player.get("attributes", player)
	var total := 0.0
	var count := 0
	for key in keys:
		if attrs.has(key): total += float(attrs[key]); count += 1
	if count == 0: return clampf(float(player.get("current_ability",50))/100.0,0.0,1.0)
	var average := total / float(count)
	return clampf(average / (20.0 if average <= 20.0 else 100.0),0.0,1.0)

func _stable_key(text: String) -> int:
	var value := 97
	for c in text.to_utf8_buffer(): value = posmod(value*193+int(c),2_147_483_647)
	return value
