class_name ContinuousSpatialEngineV3
extends "res://simulation/match/continuous_spatial_engine.gd"

# Release-oriented continuous simulation. Physics still advances at 10 Hz, while
# frame_stride controls how many snapshots are retained for presentation.
func simulate_continuous(home_lineup: Array, away_lineup: Array, seed: int, home_tactic: Dictionary = {}, away_tactic: Dictionary = {}, ticks: int = 540, previous_state: Dictionary = {}, frame_stride: int = 1) -> Dictionary:
	var home_profile := TacticalProfileClass.for_tactic(home_tactic if not home_tactic.is_empty() else _default_tactic())
	var away_profile := TacticalProfileClass.for_tactic(away_tactic if not away_tactic.is_empty() else _default_tactic())
	var home_pos := _anchors(home_lineup, true, home_profile)
	var away_pos := _anchors(away_lineup, false, away_profile)
	if previous_state.has("home_positions"):
		for id in home_pos.keys():
			if previous_state.home_positions.has(id): home_pos[id] = previous_state.home_positions[id].duplicate(true)
	if previous_state.has("away_positions"):
		for id in away_pos.keys():
			if previous_state.away_positions.has(id): away_pos[id] = previous_state.away_positions[id].duplicate(true)
	var loads := {"home":{},"away":{}}
	for player in home_lineup:
		loads.home[String(player.id)] = PhysicalModelClass.initial_load() if not _has_load(previous_state,"home",String(player.id)) else previous_state.loads.home[String(player.id)].duplicate(true)
	for player in away_lineup:
		loads.away[String(player.id)] = PhysicalModelClass.initial_load() if not _has_load(previous_state,"away",String(player.id)) else previous_state.loads.away[String(player.id)].duplicate(true)
	var ball: Dictionary = previous_state.get("ball", {"x":PITCH_LENGTH*0.5,"y":PITCH_WIDTH*0.5}).duplicate(true)
	var ball_target := ball.duplicate(true)
	var possession := String(previous_state.get("possession","home"))
	var starting_lineup := home_lineup if possession=="home" else away_lineup
	var ball_owner := {"side":possession,"id":String(starting_lineup[mini(6,starting_lineup.size()-1)].id) if not starting_lineup.is_empty() else ""}
	var frames: Array=[]; var events:Array=[]; var interceptions:=0; var shots:=0; var goals:=0
	var dt:=1.0/TICK_HZ; var stride:=maxi(1,frame_stride)
	for tick in range(maxi(0,ticks)):
		var marking_home:=_assignments(away_pos,home_pos)
		var marking_away:=_assignments(home_pos,away_pos)
		_move_side(home_lineup,home_pos,away_pos,ball,home_profile,loads.home,marking_home,possession=="home",dt,tick)
		_move_side(away_lineup,away_pos,home_pos,ball,away_profile,loads.away,marking_away,possession=="away",dt,tick)
		_move_goalkeeper(home_pos,home_lineup,ball,true); _move_goalkeeper(away_pos,away_lineup,ball,false)
		ball=SpatialStateClass.advance(ball,ball_target,BALL_TRAVEL_SPEED*dt)
		var travelling:=SpatialStateClass.distance(ball,ball_target)>2.5
		var owner_pos:=_owner_position(ball_owner,home_pos,away_pos,ball)
		var interceptor:={"side":"","id":""}
		if travelling and SpatialStateClass.distance(ball,owner_pos)>2.0: interceptor=_check_interception(ball,home_pos,away_pos,ball_owner)
		if String(interceptor.side)!="" and String(interceptor.side)!=String(ball_owner.side):
			interceptions+=1; possession=String(interceptor.side); ball_owner=interceptor; ball_target=ball.duplicate(true)
			events.append({"type":"interception","side":interceptor.side,"player_id":interceptor.id,"tick":tick,"success":true})
		elif SpatialStateClass.distance(ball,ball_target)<1.2:
			var profile:Dictionary=home_profile if possession=="home" else away_profile
			var interval:=maxi(4,int(roundi(float(profile.decision_interval)*TICK_HZ*2.0)))
			if tick%interval==0:
				var previous_owner:=ball_owner.duplicate(true)
				var outcome:=_decide_action(ball,ball_owner,possession,home_lineup,away_lineup,home_pos,away_pos,home_profile,away_profile,loads,seed,tick)
				possession=String(outcome.get("possession",possession)); ball_owner={"side":possession,"id":String(outcome.get("owner_id",ball_owner.id))}; ball_target=(outcome.get("target",ball) as Dictionary).duplicate(true)
				var event_type:=String(outcome.get("event",""))
				if event_type!="":
					var event:=outcome.duplicate(true); event.erase("event"); event.erase("possession"); event.erase("owner_id"); event.erase("target"); event["type"]=event_type; event["side"]=String(previous_owner.side); event["player_id"]=String(previous_owner.id); event["tick"]=tick
					events.append(event)
					if event_type=="shot":
						shots+=1
						var defending_side := "away" if String(previous_owner.side)=="home" else "home"
						var defending_lineup: Array = away_lineup if defending_side=="away" else home_lineup
						possession=defending_side
						ball_owner={"side":defending_side,"id":String(defending_lineup[0].id) if not defending_lineup.is_empty() else ""}
						ball={"x":PITCH_LENGTH-6.0 if defending_side=="away" else 6.0,"y":PITCH_WIDTH*0.5}
						ball_target=ball.duplicate(true)
					elif event_type=="goal":
						shots+=1; goals+=1
						var kickoff_side := "away" if String(previous_owner.side)=="home" else "home"
						var kickoff_lineup: Array = away_lineup if kickoff_side=="away" else home_lineup
						possession=kickoff_side
						var kickoff_index := mini(6,kickoff_lineup.size()-1)
						ball_owner={"side":kickoff_side,"id":String(kickoff_lineup[kickoff_index].id) if kickoff_index>=0 and not kickoff_lineup.is_empty() else ""}
						ball={"x":PITCH_LENGTH*0.5,"y":PITCH_WIDTH*0.5}
						ball_target=ball.duplicate(true)
		if tick%stride==0 or tick==ticks-1:
			frames.append({"tick":tick,"ball":ball.duplicate(true),"home":_copy_positions(home_pos),"away":_copy_positions(away_pos),"possession":possession,"home_loads":_copy_loads({"home":loads.home}).home,"away_loads":_copy_loads({"away":loads.away}).away})
	var summary:={"ticks":ticks,"shots":shots,"goals":goals,"interceptions":interceptions,"events":events.size(),"home_distance":_total_distance(loads.home),"away_distance":_total_distance(loads.away)}
	return {"frames":frames,"events":events,"summary":summary,"loads":loads,"final":{"home_positions":home_pos,"away_positions":away_pos,"ball":ball,"possession":possession,"loads":loads},"model":"continuous_10hz_sampled","frame_stride":stride}

func _move_side(lineup: Array, own: Dictionary, opp: Dictionary, ball: Dictionary, profile: Dictionary, loads: Dictionary, marking: Dictionary, in_possession: bool, dt: float, tick: int) -> void:
	var by_id := {}
	for player in lineup:
		by_id[String(player.id)] = player
	for i in range(lineup.size()):
		var player: Dictionary = lineup[i]
		var id := String(player.id)
		if i == 0:
			continue
		var pos: Dictionary = own[id]
		var anchor: Dictionary = _role_anchor(player, i, profile)
		var target := anchor.duplicate(true)
		var instruction: Dictionary = player.get("match_instruction", {})
		var press_trigger: float = float(profile.press_trigger)
		if in_possession:
			target = _blend(target, {"x": float(anchor.x) + (6.0 if _is_home_side(own, pos) else -6.0), "y": anchor.y}, 0.35)
			match String(instruction.get("width", "normal")):
				"stay_wider": target.y = clampf(float(target.y) + (7.0 if float(target.y) >= PITCH_WIDTH * 0.5 else -7.0), 2.0, PITCH_WIDTH - 2.0)
				"sit_narrower": target.y = lerpf(float(target.y), PITCH_WIDTH * 0.5, 0.45)
			if marking.has(id):
				target = _blend(target, ball, 0.15)
		else:
			var work_rate := _quality(player,["work_rate","stamina","anticipation"])
			press_trigger *= lerpf(0.82,1.18,work_rate)
			match String(instruction.get("pressing", "normal")):
				"press_more": press_trigger *= 1.4
				"press_less": press_trigger *= 0.65
			var ball_d := SpatialStateClass.distance(pos, ball)
			if ball_d < press_trigger:
				target = ball.duplicate(true)
			elif marking.has(id):
				var aid: String = marking[id]
				var mark_pos: Dictionary = _opp_position(opp, aid, pos)
				target = _blend(anchor, mark_pos, lerpf(0.42,0.68,_quality(player,["marking","positioning","anticipation"])))
			else:
				target = _blend(anchor, ball, 0.25)
		var energy := PhysicalModelClass.energy_factor(loads.get(id, {"energy": 1.0}))
		var athleticism := _quality(player,["pace","acceleration","agility"])
		var endurance := _quality(player,["stamina","natural_fitness"])
		var speed: float = float(profile.closing_speed) * lerpf(0.78,1.18,athleticism) * (0.55 + 0.45 * energy) * lerpf(0.92,1.06,endurance) * float(profile.execution)
		var step := speed * dt
		var before := pos.duplicate(true)
		var moved: Dictionary = SpatialStateClass.advance(pos, target, step)
		own[id] = moved
		var dist := SpatialStateClass.distance(before, moved)
		var pressing := (not in_possession) and SpatialStateClass.distance(before, ball) < press_trigger if not in_possession else false
		loads[id] = PhysicalModelClass.update(loads.get(id, PhysicalModelClass.initial_load()), dist, dist / maxf(dt, 0.001), pressing, by_id.get(id, {}), false)

func _decide_action(ball: Dictionary, owner: Dictionary, possession: String, home_lineup: Array, away_lineup: Array, home_pos: Dictionary, away_pos: Dictionary, home_profile: Dictionary, away_profile: Dictionary, loads: Dictionary, seed: int, tick: int) -> Dictionary:
	var team: Array = home_lineup if possession == "home" else away_lineup
	var opposition: Array = away_lineup if possession == "home" else home_lineup
	var owner_player := _player_by_id(team, String(owner.get("id", "")))
	var instruction: Dictionary = owner_player.get("match_instruction", {})
	var home_adjusted := home_profile.duplicate(true)
	var away_adjusted := away_profile.duplicate(true)
	var active_profile: Dictionary = home_adjusted if possession == "home" else away_adjusted
	var decision_quality := _quality(owner_player,["decisions","vision","composure"])
	var passing_quality := _quality(owner_player,["passing","technique","vision"])
	active_profile.execution = clampf(float(active_profile.execution) * lerpf(0.82,1.12,(decision_quality+passing_quality)*0.5),0.55,1.35)
	match String(instruction.get("risk", "normal")):
		"take_more_risks": active_profile.directness = clampf(float(active_profile.directness) + 0.22, 0.0, 1.5)
		"take_fewer_risks": active_profile.directness = clampf(float(active_profile.directness) - 0.22, 0.0, 1.5)
	active_profile.directness = clampf(float(active_profile.directness) + (decision_quality-0.5)*0.14,0.0,1.5)
	var outcome: Dictionary = super._decide_action(ball,owner,possession,home_lineup,away_lineup,home_pos,away_pos,home_adjusted,away_adjusted,loads,seed,tick)
	var event_type := String(outcome.get("event", ""))
	var finishing := _quality(owner_player,["finishing","composure","technique"])
	var goalkeeper: Dictionary = opposition[0] if not opposition.is_empty() else {}
	var keeper_quality := _quality(goalkeeper,["reflexes","one_on_ones","goalkeeper_positioning","handling"])
	if event_type in ["shot","goal"]:
		var base_xg := float(outcome.get("xg",0.05))
		var adjusted_xg := clampf(base_xg*lerpf(0.72,1.34,finishing),0.01,0.72)
		outcome["xg"] = adjusted_xg
		var conversion := clampf(adjusted_xg*lerpf(1.16,0.76,keeper_quality),0.008,0.72)
		var scored := SeededRngClass.unit_for(seed,27000+tick) < conversion
		outcome["event"] = "goal" if scored else "shot"
		event_type = String(outcome.event)
	var shooting := String(instruction.get("shooting", "normal"))
	if shooting == "shoot_less" and event_type in ["shot", "goal"] and SeededRngClass.unit_for(seed, 25000 + tick) < 0.7:
		var direction := 1.0 if possession == "home" else -1.0
		outcome["event"] = "dribble"
		outcome["target"] = SpatialStateClass.clamp_position({"x":float(ball.x)+direction*lerpf(3.0,6.5,_quality(owner_player,["dribbling","pace","balance"])),"y":float(ball.y)})
		outcome["owner_id"] = String(owner.get("id", ""))
		outcome["success"] = true
		outcome.erase("xg")
		outcome.erase("outcome")
	elif shooting == "shoot_more" and event_type not in ["shot", "goal"]:
		var goal_x := PITCH_LENGTH if possession == "home" else 0.0
		var dist_goal := absf(goal_x - float(ball.x))
		if dist_goal < 34.0 and SeededRngClass.unit_for(seed, 26000 + tick) < 0.28:
			var xg := clampf((0.34 - dist_goal / 120.0) * float(active_profile.execution) * lerpf(0.72,1.34,finishing), 0.015, 0.46)
			var scored := SeededRngClass.unit_for(seed, 26100 + tick) < xg*lerpf(1.16,0.76,keeper_quality)
			outcome = {"possession":possession,"owner_id":String(owner.get("id", "")),"target":{"x":goal_x,"y":PITCH_WIDTH*0.5},"event":"goal" if scored else "shot","xg":xg,"outcome":"goal" if scored else "missed","success":scored}
	if String(outcome.get("event",""))=="":
		var next_owner:=String(outcome.get("owner_id",owner.get("id","")))
		if next_owner!=String(owner.get("id","")):
			outcome["event"]="pass"; outcome["receiver_id"]=next_owner; outcome["target_id"]=next_owner; outcome["success"]=true
		elif SpatialStateClass.distance(ball,outcome.get("target",ball))>1.5:
			outcome["event"]="dribble"; outcome["success"]=true
	elif String(outcome.event)=="goal":
		outcome["outcome"]="goal"; outcome["success"]=true
	elif String(outcome.event)=="shot":
		var save_chance:=clampf(0.18+keeper_quality*0.52-finishing*0.16,0.10,0.72)
		var saved:=SeededRngClass.unit_for(seed,24000+tick)<save_chance
		outcome["outcome"]="saved" if saved else "missed"; outcome["success"]=false
	return outcome

func _player_by_id(team: Array, player_id: String) -> Dictionary:
	for player in team:
		if String(player.get("id", "")) == player_id:
			return player
	return {}

func _quality(player: Dictionary, keys: Array) -> float:
	if player.is_empty():
		return 0.5
	var attrs: Dictionary = player.get("attributes", player.get("player_attributes", {}))
	var total := 0.0
	var count := 0
	for key in keys:
		var value = attrs.get(String(key), player.get(String(key), null))
		if value == null:
			continue
		var numeric := float(value)
		if numeric <= 20.0:
			numeric *= 5.0
		total += clampf(numeric,1.0,100.0)
		count += 1
	if count == 0:
		return clampf(float(player.get("current_ability",50))/100.0,0.15,1.0)
	return clampf(total/float(count)/100.0,0.05,1.0)
