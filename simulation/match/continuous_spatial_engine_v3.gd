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
			var interval:=maxi(4,int(roundi(float(profile.decision_interval)*TICK_HZ*0.5)))
			if tick%interval==0:
				var previous_owner:=ball_owner.duplicate(true)
				var outcome:=_decide_action(ball,ball_owner,possession,home_lineup,away_lineup,home_pos,away_pos,home_profile,away_profile,loads,seed,tick)
				possession=String(outcome.get("possession",possession)); ball_owner={"side":possession,"id":String(outcome.get("owner_id",ball_owner.id))}; ball_target=(outcome.get("target",ball) as Dictionary).duplicate(true)
				var event_type:=String(outcome.get("event",""))
				if event_type!="":
					var event:=outcome.duplicate(true); event.erase("event"); event.erase("possession"); event.erase("owner_id"); event.erase("target"); event["type"]=event_type; event["side"]=String(previous_owner.side); event["player_id"]=String(previous_owner.id); event["tick"]=tick
					events.append(event)
					if event_type=="shot": shots+=1
					elif event_type=="goal": shots+=1; goals+=1
		if tick%stride==0 or tick==ticks-1:
			frames.append({"tick":tick,"ball":ball.duplicate(true),"home":_copy_positions(home_pos),"away":_copy_positions(away_pos),"possession":possession,"home_loads":_copy_loads({"home":loads.home}).home,"away_loads":_copy_loads({"away":loads.away}).away})
	var summary:={"ticks":ticks,"shots":shots,"goals":goals,"interceptions":interceptions,"events":events.size(),"home_distance":_total_distance(loads.home),"away_distance":_total_distance(loads.away)}
	return {"frames":frames,"events":events,"summary":summary,"loads":loads,"final":{"home_positions":home_pos,"away_positions":away_pos,"ball":ball,"possession":possession,"loads":loads},"model":"continuous_10hz_sampled","frame_stride":stride}

func _decide_action(ball: Dictionary, owner: Dictionary, possession: String, home_lineup: Array, away_lineup: Array, home_pos: Dictionary, away_pos: Dictionary, home_profile: Dictionary, away_profile: Dictionary, loads: Dictionary, seed: int, tick: int) -> Dictionary:
	var outcome: Dictionary = super._decide_action(ball,owner,possession,home_lineup,away_lineup,home_pos,away_pos,home_profile,away_profile,loads,seed,tick)
	if String(outcome.get("event",""))=="":
		var next_owner:=String(outcome.get("owner_id",owner.get("id","")))
		if next_owner!=String(owner.get("id","")):
			outcome["event"]="pass"; outcome["receiver_id"]=next_owner; outcome["target_id"]=next_owner; outcome["success"]=true
		elif SpatialStateClass.distance(ball,outcome.get("target",ball))>1.5:
			outcome["event"]="dribble"; outcome["success"]=true
	elif String(outcome.event)=="goal":
		outcome["outcome"]="goal"; outcome["success"]=true
	elif String(outcome.event)=="shot":
		var saved:=SeededRngClass.unit_for(seed,24000+tick)<0.45
		outcome["outcome"]="saved" if saved else "missed"; outcome["success"]=false
	return outcome
