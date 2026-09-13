class_name ContinuousSpatialEngineV4
extends "res://simulation/match/continuous_spatial_engine_v3.gd"

const MotionClass = preload("res://simulation/match/player_motion.gd")
const SpatialHashClass = preload("res://simulation/match/spatial_hash.gd")
const BallClass = preload("res://simulation/match/ball_physics.gd")

const MIN_PLAYER_SEPARATION := 1.65
const SPACING_PUSH := 0.34
const PERCEPTION_REFRESH_TICKS := 2
const STATE_REFRESH_TICKS := 3
const PERCEPTION_RANGE := 32.0
const BALL_PHYSICS_SUBSTEPS := 2

var _motion_states: Dictionary = {}
var _perception_cache: Dictionary = {}
var _context_states: Dictionary = {}
var _grid = SpatialHashClass.new(6.0)

func simulate_continuous(home_lineup: Array, away_lineup: Array, seed: int, home_tactic: Dictionary = {}, away_tactic: Dictionary = {}, ticks: int = 540, previous_state: Dictionary = {}, frame_stride: int = 1) -> Dictionary:
	var home_profile := TacticalProfileClass.for_tactic(home_tactic if not home_tactic.is_empty() else _default_tactic())
	var away_profile := TacticalProfileClass.for_tactic(away_tactic if not away_tactic.is_empty() else _default_tactic())
	var home_pos := _anchors(home_lineup,true,home_profile)
	var away_pos := _anchors(away_lineup,false,away_profile)
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

	var initial_ball: Dictionary = previous_state.get("ball",{"x":PITCH_LENGTH*0.5,"y":PITCH_WIDTH*0.5}).duplicate(true)
	var ball_state: Dictionary = previous_state.get("ball_physics",{}).duplicate(true)
	if ball_state.is_empty(): ball_state = BallClass.initial_state(initial_ball)
	var ball: Dictionary = BallClass.to_2d(ball_state)
	var ball_target := {"x":float(ball.x),"y":float(ball.y)}
	var possession := String(previous_state.get("possession","home"))
	var starting_lineup := home_lineup if possession == "home" else away_lineup
	var ball_owner := {"side":possession,"id":String(starting_lineup[mini(6,starting_lineup.size()-1)].id) if not starting_lineup.is_empty() else ""}
	var frames: Array = []
	var events: Array = []
	var interceptions := 0
	var shots := 0
	var goals := 0
	var dt := 1.0/TICK_HZ
	var stride := maxi(1,frame_stride)
	var marking_home: Dictionary = {}
	var marking_away: Dictionary = {}
	var pending_restart: Dictionary = {}
	const MARKING_REFRESH_TICKS := 10

	for tick in range(maxi(0,ticks)):
		if tick % MARKING_REFRESH_TICKS == 0:
			marking_home = _assignments(away_pos,home_pos)
			marking_away = _assignments(home_pos,away_pos)
		_move_side(home_lineup,home_pos,away_pos,ball,home_profile,loads.home,marking_home,possession=="home",dt,tick)
		_move_side(away_lineup,away_pos,home_pos,ball,away_profile,loads.away,marking_away,possession=="away",dt,tick)
		_move_goalkeeper(home_pos,home_lineup,ball,true)
		_move_goalkeeper(away_pos,away_lineup,ball,false)

		for _substep in range(BALL_PHYSICS_SUBSTEPS):
			BallClass.step(ball_state,dt/float(BALL_PHYSICS_SUBSTEPS),PITCH_LENGTH,PITCH_WIDTH)
		ball = BallClass.to_2d(ball_state)
		var horizontal_speed := Vector2((ball_state.velocity as Vector3).x,(ball_state.velocity as Vector3).y).length()
		var travelling := horizontal_speed > 0.7 or SpatialStateClass.distance(ball,ball_target) > 1.6

		if not pending_restart.is_empty():
			if tick >= int(pending_restart.get("at_tick",tick)) or SpatialStateClass.distance(ball,ball_target) < 1.25:
				possession = String(pending_restart.get("side",possession))
				var restart_lineup: Array = home_lineup if possession=="home" else away_lineup
				var restart_id := String(restart_lineup[0].id) if not restart_lineup.is_empty() else ""
				ball_owner = {"side":possession,"id":restart_id}
				var restart_pos := _owner_position(ball_owner,home_pos,away_pos,{"x":PITCH_LENGTH*0.5,"y":PITCH_WIDTH*0.5})
				ball_state = BallClass.initial_state(restart_pos)
				ball = BallClass.to_2d(ball_state)
				ball_target = {"x":float(ball.x),"y":float(ball.y)}
				pending_restart.clear()
				travelling = false

		var owner_pos := _owner_position(ball_owner,home_pos,away_pos,ball)
		var interceptor := {"side":"","id":""}
		if pending_restart.is_empty() and travelling and SpatialStateClass.distance(ball,owner_pos)>2.0:
			interceptor = _check_interception(ball,home_pos,away_pos,ball_owner)
		if String(interceptor.side)!="" and String(interceptor.side)!=String(ball_owner.side):
			interceptions += 1
			possession = String(interceptor.side)
			ball_owner = interceptor
			var intercept_pos := _owner_position(ball_owner,home_pos,away_pos,ball)
			ball_state = BallClass.initial_state(intercept_pos)
			ball = BallClass.to_2d(ball_state)
			ball_target = {"x":float(ball.x),"y":float(ball.y)}
			events.append({"type":"interception","side":interceptor.side,"player_id":interceptor.id,"tick":tick,"success":true})
			travelling = false
		elif pending_restart.is_empty() and (not travelling or SpatialStateClass.distance(ball,ball_target)<1.2):
			# When settled, keep the ball at the owner's feet until a decision kicks it.
			var settled_owner := _owner_position(ball_owner,home_pos,away_pos,ball)
			ball_state = BallClass.initial_state(settled_owner)
			ball = BallClass.to_2d(ball_state)
			var profile: Dictionary = home_profile if possession=="home" else away_profile
			var interval := maxi(4,int(roundi(float(profile.decision_interval)*TICK_HZ*2.0)))
			if tick % interval == 0:
				var previous_owner := ball_owner.duplicate(true)
				var outcome := _decide_action(ball,ball_owner,possession,home_lineup,away_lineup,home_pos,away_pos,home_profile,away_profile,loads,seed,tick)
				possession = String(outcome.get("possession",possession))
				ball_owner = {"side":possession,"id":String(outcome.get("owner_id",ball_owner.id))}
				ball_target = (outcome.get("target",ball) as Dictionary).duplicate(true)
				var event_type := String(outcome.get("event",""))
				if event_type!="":
					var event := outcome.duplicate(true)
					event.erase("event"); event.erase("possession"); event.erase("owner_id"); event.erase("target")
					event["type"] = event_type; event["side"] = String(previous_owner.side); event["player_id"] = String(previous_owner.id); event["tick"] = tick
					events.append(event)
				var target3 := Vector3(float(ball_target.get("x",ball.x)),float(ball_target.get("y",ball.y)),BallClass.BALL_RADIUS)
				var travel_distance := SpatialStateClass.distance(ball,ball_target)
				if travel_distance > 0.35:
					var kick_speed := clampf(10.0+travel_distance*0.72,10.0,31.0)
					var lift := 0.02 if travel_distance < 18.0 else (0.07 if travel_distance < 34.0 else 0.12)
					if event_type in ["shot","goal"]:
						kick_speed = clampf(22.0+travel_distance*0.38,22.0,34.0)
						lift = 0.06
					var stable_spin := float((_stable_motion_key(String(previous_owner.id)) % 17)-8)*0.55
					BallClass.kick(ball_state,target3,kick_speed,lift,stable_spin,-2.0 if event_type in ["shot","goal"] else -0.6)
				if event_type=="shot":
					shots += 1
					var defending_side := "away" if String(previous_owner.side)=="home" else "home"
					pending_restart = {"side":defending_side,"at_tick":tick+12}
				elif event_type=="goal":
					shots += 1; goals += 1
					var kickoff_side := "away" if String(previous_owner.side)=="home" else "home"
					pending_restart = {"side":kickoff_side,"at_tick":tick+16}

		if tick % stride == 0 or tick == ticks-1:
			frames.append({"tick":tick,"ball":ball.duplicate(true),"home":_copy_positions(home_pos),"away":_copy_positions(away_pos),"possession":possession,"home_loads":_copy_loads({"home":loads.home}).home,"away_loads":_copy_loads({"away":loads.away}).away})

	var summary := {"ticks":ticks,"shots":shots,"goals":goals,"interceptions":interceptions,"events":events.size(),"home_distance":_total_distance(loads.home),"away_distance":_total_distance(loads.away)}
	return {"frames":frames,"events":events,"summary":summary,"loads":loads,"final":{"home_positions":home_pos,"away_positions":away_pos,"ball":ball,"ball_physics":ball_state,"possession":possession,"loads":loads},"model":"continuous_10hz_aero_sampled","frame_stride":stride}

func _move_side(lineup: Array, own: Dictionary, opp: Dictionary, ball: Dictionary, profile: Dictionary, loads: Dictionary, marking: Dictionary, in_possession: bool, dt: float, tick: int) -> void:
	var before: Dictionary = {}
	for player in lineup:
		var pid := String(player.get("id", ""))
		if pid != "" and own.has(pid):
			before[pid] = (own[pid] as Dictionary).duplicate(true)

	super._move_side(lineup, own, opp, ball, profile, loads, marking, in_possession, dt, tick)
	var refresh_context := tick % STATE_REFRESH_TICKS == 0
	if refresh_context:
		_grid.clear()
		for own_id in own.keys(): _grid.insert(String(own_id), own[own_id], "own")
		for opp_id in opp.keys(): _grid.insert(String(opp_id), opp[opp_id], "opp")
	var ball_v := Vector2(float(ball.get("x",0.0)),float(ball.get("y",0.0)))

	for i in range(1,lineup.size()):
		var player: Dictionary = lineup[i]
		var id := String(player.get("id", ""))
		if id == "" or not before.has(id) or not own.has(id):
			continue
		var previous: Dictionary = before[id]
		var proposed: Dictionary = own[id]
		var state: Dictionary = _motion_states.get(id, {})
		if state.is_empty():
			var facing := Vector2.RIGHT if float(proposed.get("x",0.0)) >= float(previous.get("x",0.0)) else Vector2.LEFT
			state = MotionClass.make_state(previous,facing)
		else:
			state["position"] = Vector2(float(previous.get("x",0.0)),float(previous.get("y",0.0)))

		if tick % PERCEPTION_REFRESH_TICKS == 0 or not _perception_cache.has(id):
			var fov := lerpf(105.0,155.0,_quality(player,["vision","anticipation","concentration"]))
			_perception_cache[id] = MotionClass.can_perceive(state,ball_v,PERCEPTION_RANGE,fov)
		var target := Vector2(float(proposed.get("x",0.0)),float(proposed.get("y",0.0)))
		var previous_v := Vector2(float(previous.get("x",0.0)),float(previous.get("y",0.0)))
		if not in_possession and not bool(_perception_cache.get(id,true)) and previous_v.distance_to(ball_v) > 12.0:
			var anchor: Dictionary = _role_anchor(player,i,profile)
			target = target.lerp(Vector2(float(anchor.x),float(anchor.y)),0.48)

		var athleticism := _quality(player,["pace","acceleration","agility"])
		var max_speed := lerpf(5.8,9.1,athleticism)
		var accel := lerpf(3.8,7.2,_quality(player,["acceleration","agility","balance"]))
		var decel := lerpf(5.0,8.6,_quality(player,["agility","balance","strength"]))
		var turn_rate := lerpf(3.1,6.4,_quality(player,["agility","balance","technique"]))
		MotionClass.step(state,target,dt,max_speed,accel,decel,turn_rate)
		var p: Vector2 = state.position
		own[id] = SpatialStateClass.clamp_position({"x":p.x,"y":p.y})
		_motion_states[id] = state

		if refresh_context or not _context_states.has(id):
			var nearby := _grid.query_radius(own[id],12.0,id,"opp") if refresh_context else []
			var opponent_distance := 99.0 if nearby.is_empty() else float(nearby[0].distance)
			_context_states[id] = MotionClass.contextual_state(in_possession,false,p.distance_to(ball_v),opponent_distance,float(p.x)/PITCH_LENGTH)

	_resolve_team_spacing(lineup,own)
	_keep_outfield_inside_playable_lane(lineup,own)

func _resolve_team_spacing(lineup: Array, positions: Dictionary) -> void:
	for i in range(1, lineup.size()):
		var a_id := String(lineup[i].get("id", ""))
		if a_id == "" or not positions.has(a_id): continue
		for j in range(i+1,lineup.size()):
			var b_id := String(lineup[j].get("id", ""))
			if b_id == "" or not positions.has(b_id): continue
			var a: Dictionary = positions[a_id]
			var b: Dictionary = positions[b_id]
			var dx := float(b.get("x",0.0))-float(a.get("x",0.0))
			var dy := float(b.get("y",0.0))-float(a.get("y",0.0))
			var distance := sqrt(dx*dx+dy*dy)
			if distance >= MIN_PLAYER_SEPARATION: continue
			var nx: float
			var ny: float
			if distance < 0.001:
				var sign := -1.0 if a_id < b_id else 1.0
				nx = 0.35*sign; ny = 0.94; distance = 1.0
			else:
				nx = dx/distance; ny = dy/distance
			var overlap := (MIN_PLAYER_SEPARATION-distance)*0.5*SPACING_PUSH
			positions[a_id] = SpatialStateClass.clamp_position({"x":float(a.x)-nx*overlap,"y":float(a.y)-ny*overlap})
			positions[b_id] = SpatialStateClass.clamp_position({"x":float(b.x)+nx*overlap,"y":float(b.y)+ny*overlap})

func _keep_outfield_inside_playable_lane(lineup: Array, positions: Dictionary) -> void:
	for i in range(1,lineup.size()):
		var id := String(lineup[i].get("id", ""))
		if id == "" or not positions.has(id): continue
		var pos: Dictionary = positions[id]
		pos.x = clampf(float(pos.get("x",0.0)),0.75,PITCH_LENGTH-0.75)
		pos.y = clampf(float(pos.get("y",0.0)),0.75,PITCH_WIDTH-0.75)
		positions[id] = pos

func _decide_action(ball: Dictionary, owner: Dictionary, possession: String, home_lineup: Array, away_lineup: Array, home_pos: Dictionary, away_pos: Dictionary, home_profile: Dictionary, away_profile: Dictionary, loads: Dictionary, seed: int, tick: int) -> Dictionary:
	var outcome: Dictionary = super._decide_action(ball,owner,possession,home_lineup,away_lineup,home_pos,away_pos,home_profile,away_profile,loads,seed,tick)
	var team: Array = home_lineup if possession=="home" else away_lineup
	var player: Dictionary = _player_by_id(team,String(owner.get("id","")))
	var traits: Array = player.get("traits",[])
	if traits.is_empty(): return outcome
	var direction := 1.0 if possession=="home" else -1.0
	var event_type := String(outcome.get("event",""))
	var roll := SeededRngClass.unit_for(seed,32000+tick+_trait_key(String(player.get("id",""))))
	if "tries_long_shots" in traits and event_type not in ["shot","goal"]:
		var goal_x := PITCH_LENGTH if possession=="home" else 0.0
		var distance := absf(goal_x-float(ball.x))
		if distance<42.0 and roll<0.18:
			var finishing := _quality(player,["long_shots","finishing","composure"])
			var xg := clampf((0.23-distance/240.0)*lerpf(0.72,1.25,finishing),0.01,0.22)
			outcome = {"possession":possession,"owner_id":String(owner.get("id","")),"target":{"x":goal_x,"y":PITCH_WIDTH*0.5},"event":"shot","xg":xg,"outcome":"missed","success":false,"trait":"tries_long_shots"}
	elif "runs_with_ball" in traits and event_type=="pass" and roll<0.24:
		outcome["event"]="dribble"; outcome["owner_id"]=String(owner.get("id","")); outcome["target"]=SpatialStateClass.clamp_position({"x":float(ball.x)+direction*7.0,"y":float(ball.y)}); outcome["success"]=true; outcome["trait"]="runs_with_ball"; outcome.erase("receiver_id"); outcome.erase("target_id")
	elif "plays_one_twos" in traits and event_type=="pass" and roll<0.30:
		outcome["trait"]="plays_one_twos"; outcome["one_two_intent"]=true
	elif "switches_ball" in traits and event_type=="pass" and roll<0.26:
		var switch_target: Dictionary = outcome.get("target",ball).duplicate(true)
		switch_target.y = clampf(PITCH_WIDTH-float(switch_target.get("y",ball.y)),2.0,PITCH_WIDTH-2.0)
		outcome["target"] = switch_target; outcome["trait"] = "switches_ball"
	if String(outcome.get("event",""))=="dribble":
		var dribble_target: Dictionary = outcome.get("target",ball).duplicate(true)
		if "cuts_inside" in traits:
			dribble_target.y = lerpf(float(dribble_target.get("y",ball.y)),PITCH_WIDTH*0.5,0.55); outcome["trait"]="cuts_inside"
		elif "stays_wide" in traits:
			var current_y := float(ball.get("y",PITCH_WIDTH*0.5)); dribble_target.y = 4.0 if current_y<PITCH_WIDTH*0.5 else PITCH_WIDTH-4.0; outcome["trait"]="stays_wide"
		if "beats_offside_trap" in traits:
			dribble_target.x = clampf(float(dribble_target.get("x",ball.x))+direction*4.0,0.0,PITCH_LENGTH); outcome["trait_run_in_behind"]=true
		if "drops_deep" in traits and roll<0.22:
			dribble_target.x = clampf(float(dribble_target.get("x",ball.x))-direction*4.5,0.0,PITCH_LENGTH); outcome["trait_drops_deep"]=true
		outcome["target"] = SpatialStateClass.clamp_position(dribble_target)
	if "avoids_weak_foot" in traits: outcome["preferred_foot_bias"] = true
	return outcome

func _copy_loads(loads: Dictionary) -> Dictionary:
	var result := {}
	for side in loads.keys():
		result[side] = {}
		var side_loads: Dictionary = loads[side]
		for id in side_loads.keys(): result[side][id] = {"energy":float((side_loads[id] as Dictionary).get("energy",1.0))}
	return result

func runtime_player_state(player_id: String) -> Dictionary:
	var state: Dictionary = _motion_states.get(player_id,{}).duplicate(true)
	if not state.is_empty():
		state["context"] = String(_context_states.get(player_id,"shape")); state["perceives_ball"] = bool(_perception_cache.get(player_id,true))
	return state

func _stable_motion_key(text: String) -> int:
	var value := 53
	for character in text.to_utf8_buffer(): value = posmod(value*173+int(character),2147483647)
	return value

func _trait_key(text: String) -> int:
	var value := 97
	for character in text.to_utf8_buffer(): value = posmod(value*199+int(character),2147483647)
	return value
