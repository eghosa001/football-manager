class_name ContinuousFullMatchEngine
extends RefCounted

const ContinuousClass = preload("res://simulation/match/continuous_spatial_engine_v4.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")
const LineupResolverClass = preload("res://application/career/lineup_assignment_service.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const LawsClass = preload("res://simulation/match/football_laws_engine.gd")

var _continuous = ContinuousClass.new()
var _tactics = TacticsManagerClass.new()
var _lineup_resolver = LineupResolverClass.new()
var _laws = LawsClass.new()

func simulate_match(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int) -> Dictionary:
	var home_tactic: Dictionary = home_club.get("tactic", _tactics.create_tactic("4-3-3")).duplicate(true)
	var away_tactic: Dictionary = away_club.get("tactic", _tactics.create_tactic("4-3-3")).duplicate(true)
	var home: Array = _lineup_resolver.resolve(players, String(home_club.id), home_tactic).duplicate(true)
	var away: Array = _lineup_resolver.resolve(players, String(away_club.id), away_tactic).duplicate(true)
	if home.size() < 11 or away.size() < 11:
		return {"error":ERR_UNAVAILABLE,"home_goals":0,"away_goals":0,"events":[],"stats":{}}
	var weather := _laws.weather_profile(seed)
	var starters := {"home":_ids(home),"away":_ids(away)}
	var participants := {"home":starters.home.duplicate(),"away":starters.away.duplicate()}
	var benches := {"home":_bench(players,String(home_club.id),home),"away":_bench(players,String(away_club.id),away)}
	var events: Array = []
	var frames: Array = []
	var substitutions: Array = []
	var previous_state: Dictionary = {}
	var segments := [
		{"start":0.0,"end":15.0,"ticks":9000},
		{"start":15.0,"end":30.0,"ticks":9000},
		{"start":30.0,"end":45.0,"ticks":9000},
		{"start":45.0,"end":60.0,"ticks":9000},
		{"start":60.0,"end":75.0,"ticks":9000},
		{"start":75.0,"end":90.0,"ticks":9000},
	]
	for segment_index in range(segments.size()):
		var segment: Dictionary = segments[segment_index]
		if segment_index > 0:
			_adapt_tactic("home", home_tactic, events, int(segment.start))
			_adapt_tactic("away", away_tactic, events, int(segment.start))
			_maybe_state_substitution("home",home,benches.home,participants,substitutions,events,int(segment.start),previous_state,seed+segment_index*7001)
			_maybe_state_substitution("away",away,benches.away,participants,substitutions,events,int(segment.start),previous_state,seed+segment_index*7003)
		var run := _continuous.simulate_continuous(home,away,seed+segment_index*100003,home_tactic,away_tactic,int(segment.ticks),previous_state,15)
		var duration := float(segment.end)-float(segment.start)
		for frame in run.frames:
			var copy: Dictionary = frame.duplicate(true)
			copy["minute"] = float(segment.start) + float(frame.get("tick",0)) / maxf(1.0,float(segment.ticks)) * duration
			frames.append(copy)
		for raw_event in run.events:
			var event := _canonical_event(raw_event,float(segment.start),duration,int(segment.ticks),seed+segment_index*907)
			var processed := _laws.process_event(event, home, away, home_tactic, away_tactic, weather, seed+segment_index*919)
			for p in processed:
				events.append(p)
				var affected_lineup := home if String(p.get("side","home")) == "home" else away
				var injury := _laws.injury_from_event(p, affected_lineup, weather, seed+segment_index*929)
				if not injury.is_empty():
					events.append(injury)
					_apply_forced_injury_substitution(injury,home,away,benches,participants,substitutions,events)
		previous_state = run.final.duplicate(true)
		previous_state["loads"] = run.loads.duplicate(true)
	var stats := {"home":_blank_stats(),"away":_blank_stats()}
	var goals := {"home":0,"away":0}
	for event in events:
		_accumulate(stats,goals,event)
	stats.home.xg = snappedf(float(stats.home.xg),0.01)
	stats.away.xg = snappedf(float(stats.away.xg),0.01)
	var possession := _frame_possession(frames)
	stats.home.possession = possession.home
	stats.away.possession = possession.away
	var discipline := _laws.suspension_state(events, {"yellow_limit":5,"red_games":1})
	return {
		"home_goals":int(goals.home),"away_goals":int(goals.away),"events":events,"stats":stats,
		"lineups":starters,"participants":participants,"final_lineups":{"home":_ids(home),"away":_ids(away)},"substitutions":substitutions,
		"spatial":{"pitch_length":105.0,"pitch_width":68.0,"frames":frames,"model":"continuous_10hz_sampled","physics_hz":10,"frame_stride":15},
		"tactics":{"home":home_tactic.duplicate(true),"away":away_tactic.duplicate(true)},"seed":seed,"model":"continuous_full_match_v2",
		"weather":weather,"discipline":discipline
	}

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	if result.has("error"): return
	fixture.played = true
	fixture.home_goals = int(result.home_goals)
	fixture.away_goals = int(result.away_goals)
	fixture["discipline"] = result.get("discipline", {}).duplicate(true)
	fixture["weather"] = result.get("weather", {}).duplicate(true)

func _canonical_event(raw: Dictionary, start: float, duration: float, ticks: int, seed: int) -> Dictionary:
	var event := raw.duplicate(true)
	var minute := start + float(raw.get("tick",0)) / maxf(1.0,float(ticks)) * duration
	event["minute"] = mini(90,int(floor(minute)))
	var type := String(event.get("type",""))
	if type == "goal":
		event["type"] = "shot"
		event["outcome"] = "goal"
		event["success"] = true
	elif type == "shot":
		if not event.has("outcome"):
			event["outcome"] = "saved" if SeededRngClass.unit_for(seed,30000+int(raw.get("tick",0))) < 0.45 else "missed"
		event["success"] = false
	return event

func _adapt_tactic(side: String, tactic: Dictionary, events: Array, minute: int) -> void:
	var own_goals := 0
	var opp_goals := 0
	var own_cards := 0
	for event in events:
		if int(event.get("minute",0)) > minute: continue
		if String(event.get("type","")) == "shot" and String(event.get("outcome","")) == "goal":
			if String(event.get("side","")) == side: own_goals += 1
			else: opp_goals += 1
		elif String(event.get("type","")) == "card" and String(event.get("side","")) == side:
			own_cards += 1
	if own_goals < opp_goals and minute >= 55:
		tactic["mentality"] = "attacking"
		tactic["tempo"] = "higher"
		tactic["pressing"] = "more_urgent"
	elif own_goals > opp_goals and minute >= 70:
		tactic["mentality"] = "cautious"
		tactic["time_wasting"] = true
		tactic["regroup"] = true
	if own_cards >= 3:
		tactic["tackling"] = "stay_on_feet"

func _maybe_state_substitution(side: String, lineup: Array, bench: Array, participants: Dictionary, substitutions: Array, events: Array, minute: int, state: Dictionary, seed: int) -> void:
	if bench.is_empty() or substitutions.filter(func(s): return String(s.get("side","")) == side).size() >= 5:
		return
	var loads: Dictionary = state.get("loads", {}).get(side, {}) if state.has("loads") else {}
	var candidate_index := -1
	var worst_energy := 1.0
	for i in range(1,lineup.size()):
		var id := String(lineup[i].get("id",""))
		var energy := float(loads.get(id, {}).get("energy", 1.0))
		var booked := _is_booked(events, id)
		var threshold := 0.48 if minute >= 60 else 0.36
		if booked: threshold += 0.10
		if energy < threshold and energy < worst_energy:
			worst_energy = energy
			candidate_index = i
	if candidate_index < 0 and minute >= 75 and SeededRngClass.unit_for(seed, 81001 + minute) < 0.45:
		candidate_index = maxi(1, lineup.size()-1)
	if candidate_index < 0:
		return
	var incoming: Dictionary = bench.pop_front()
	var outgoing := String(lineup[candidate_index].id)
	lineup[candidate_index] = incoming.duplicate(true)
	var event := {"minute":minute,"type":"substitution","side":side,"player_out":outgoing,"player_in":String(incoming.id),"reason":"fitness_or_match_state","success":true}
	events.append(event)
	substitutions.append(event.duplicate(true))
	if String(incoming.id) not in participants[side]: participants[side].append(String(incoming.id))

func _apply_forced_injury_substitution(injury: Dictionary, home: Array, away: Array, benches: Dictionary, participants: Dictionary, substitutions: Array, events: Array) -> void:
	var side := String(injury.get("side","home"))
	var lineup := home if side == "home" else away
	var bench: Array = benches.get(side, [])
	var injured_id := String(injury.get("player_id",""))
	var index := -1
	for i in range(lineup.size()):
		if String(lineup[i].get("id","")) == injured_id:
			index = i
			break
	if index < 0:
		return
	if bench.is_empty() or substitutions.filter(func(s): return String(s.get("side","")) == side).size() >= 5:
		lineup.remove_at(index)
		events.append({"minute":int(injury.get("minute",0)),"type":"forced_short_handed","side":side,"player_id":injured_id,"success":false})
		return
	var incoming: Dictionary = bench.pop_front()
	lineup[index] = incoming.duplicate(true)
	var sub := {"minute":int(injury.get("minute",0)),"type":"substitution","side":side,"player_out":injured_id,"player_in":String(incoming.id),"reason":"injury","success":true}
	events.append(sub)
	substitutions.append(sub.duplicate(true))
	if String(incoming.id) not in participants[side]: participants[side].append(String(incoming.id))

func _is_booked(events: Array, player_id: String) -> bool:
	for event in events:
		if String(event.get("type","")) == "card" and String(event.get("player_id","")) == player_id:
			return true
	return false

func _bench(players: Array, club_id: String, lineup: Array) -> Array:
	var ids := {}
	for player in lineup: ids[String(player.id)] = true
	var bench: Array = []
	for player in players:
		if String(player.get("club_id","")) == club_id and not bool(player.get("retired",false)) and int(player.get("injured_days",0)) <= 0 and not ids.has(String(player.id)): bench.append(player)
	bench.sort_custom(func(a: Dictionary,b: Dictionary):
		if int(a.get("current_ability",0)) == int(b.get("current_ability",0)): return String(a.id)<String(b.id)
		return int(a.get("current_ability",0))>int(b.get("current_ability",0))
	)
	return bench

func _ids(values: Array) -> Array:
	var ids: Array = []
	for value in values: ids.append(String(value.id))
	return ids

func _blank_stats() -> Dictionary:
	return {"goals":0,"shots":0,"shots_on_target":0,"xg":0.0,"passes":0,"passes_completed":0,"dribbles":0,"dribbles_completed":0,"interceptions":0,"corners":0,"free_kicks":0,"offsides":0,"fouls":0,"penalties":0,"cards":0,"red_cards":0,"saves":0,"turnovers":0,"injuries":0,"possession":50.0}

func _accumulate(stats: Dictionary, goals: Dictionary, event: Dictionary) -> void:
	var side := String(event.get("side","home"))
	if not stats.has(side): return
	match String(event.get("type","")):
		"pass":
			stats[side].passes += 1
			if bool(event.get("success",false)): stats[side].passes_completed += 1
		"dribble":
			stats[side].dribbles += 1
			if bool(event.get("success",false)): stats[side].dribbles_completed += 1
		"interception": stats[side].interceptions += 1
		"corner": stats[side].corners += 1
		"offside": stats[side].offsides += 1
		"foul": stats[side].fouls += 1; stats[side].free_kicks += 1
		"penalty_awarded": stats[side].penalties += 1
		"turnover": stats[side].turnovers += 1
		"injury": stats[side].injuries += 1
		"card":
			stats[side].cards += 1
			if String(event.get("card",""))=="red": stats[side].red_cards += 1
		"shot":
			stats[side].shots += 1
			stats[side].xg += float(event.get("xg",0.0))
			if String(event.get("outcome","")) in ["goal","saved"]: stats[side].shots_on_target += 1
			if String(event.get("outcome",""))=="goal": stats[side].goals += 1; goals[side] += 1
			elif String(event.get("outcome",""))=="saved":
				var opponent := "away" if side=="home" else "home"
				stats[opponent].saves += 1

func _frame_possession(frames: Array) -> Dictionary:
	var home := 0
	var away := 0
	for frame in frames:
		if String(frame.get("possession","home"))=="away": away += 1
		else: home += 1
	var total := maxi(1,home+away)
	var home_share := snappedf(float(home)/float(total)*100.0,0.1)
	return {"home":home_share,"away":snappedf(100.0-home_share,0.1)}
