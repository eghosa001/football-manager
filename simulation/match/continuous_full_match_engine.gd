class_name ContinuousFullMatchEngine
extends RefCounted

const ContinuousClass = preload("res://simulation/match/continuous_spatial_engine_v3.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

var _continuous = ContinuousClass.new()
var _tactics = TacticsManagerClass.new()

func simulate_match(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int) -> Dictionary:
	var home_tactic: Dictionary = home_club.get("tactic", _tactics.create_tactic("4-3-3"))
	var away_tactic: Dictionary = away_club.get("tactic", _tactics.create_tactic("4-3-3"))
	var home: Array = _tactics.select_lineup(players, String(home_club.id), home_tactic).duplicate(true)
	var away: Array = _tactics.select_lineup(players, String(away_club.id), away_tactic).duplicate(true)
	if home.size() < 11 or away.size() < 11:
		return {"error":ERR_UNAVAILABLE,"home_goals":0,"away_goals":0,"events":[],"stats":{}}
	var starters := {"home":_ids(home),"away":_ids(away)}
	var participants := {"home":starters.home.duplicate(),"away":starters.away.duplicate()}
	var benches := {"home":_bench(players,String(home_club.id),home),"away":_bench(players,String(away_club.id),away)}
	var events: Array = []
	var frames: Array = []
	var substitutions: Array = []
	var previous_state: Dictionary = {}
	var segments := [
		{"start":0.0,"end":60.0,"ticks":36000},
		{"start":60.0,"end":70.0,"ticks":6000},
		{"start":70.0,"end":80.0,"ticks":6000},
		{"start":80.0,"end":90.0,"ticks":6000},
	]
	for segment_index in range(segments.size()):
		if segment_index > 0:
			_apply_substitution("home",segment_index-1,home,benches.home,participants,substitutions,events,int(segments[segment_index].start))
			_apply_substitution("away",segment_index-1,away,benches.away,participants,substitutions,events,int(segments[segment_index].start))
		var segment: Dictionary = segments[segment_index]
		var run := _continuous.simulate_continuous(home,away,seed+segment_index*100003,home_tactic,away_tactic,int(segment.ticks),previous_state,15)
		var duration := float(segment.end)-float(segment.start)
		for frame in run.frames:
			var copy: Dictionary = frame.duplicate(true)
			copy["minute"] = float(segment.start) + float(frame.get("tick",0)) / maxf(1.0,float(segment.ticks)) * duration
			frames.append(copy)
		for raw_event in run.events:
			var event := _canonical_event(raw_event,float(segment.start),duration,int(segment.ticks),seed+segment_index*907)
			events.append(event)
			_maybe_card_from_event(events,event,home,away,seed+segment_index*919)
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
	return {
		"home_goals":int(goals.home),"away_goals":int(goals.away),"events":events,"stats":stats,
		"lineups":starters,"participants":participants,"final_lineups":{"home":_ids(home),"away":_ids(away)},"substitutions":substitutions,
		"spatial":{"pitch_length":105.0,"pitch_width":68.0,"frames":frames,"model":"continuous_10hz_sampled","physics_hz":10,"frame_stride":15},
		"tactics":{"home":home_tactic.duplicate(true),"away":away_tactic.duplicate(true)},"seed":seed,"model":"continuous_full_match_v1"
	}

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	if result.has("error"): return
	fixture.played = true
	fixture.home_goals = int(result.home_goals)
	fixture.away_goals = int(result.away_goals)

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

func _maybe_card_from_event(events: Array, event: Dictionary, home: Array, away: Array, seed: int) -> void:
	if String(event.get("type","")) != "interception": return
	var tick := int(event.get("tick",0))
	if SeededRngClass.unit_for(seed,41000+tick) >= 0.006: return
	var side := String(event.get("side","home"))
	var defenders := home if side=="home" else away
	if defenders.is_empty(): return
	var player: Dictionary = defenders[int(SeededRngClass.value_for(seed,42000+tick)%defenders.size())]
	var red := SeededRngClass.unit_for(seed,43000+tick) < 0.035
	events.append({"minute":int(event.get("minute",0)),"type":"card","side":side,"player_id":String(player.id),"card":"red" if red else "yellow"})

func _apply_substitution(side: String, bench_index: int, lineup: Array, bench: Array, participants: Dictionary, substitutions: Array, events: Array, minute: int) -> void:
	if bench_index >= bench.size() or lineup.is_empty(): return
	var out_index := maxi(1,lineup.size()-1-bench_index)
	if out_index >= lineup.size(): return
	var outgoing := String(lineup[out_index].id)
	var incoming: Dictionary = bench[bench_index]
	lineup[out_index] = incoming.duplicate(true)
	var event := {"minute":minute,"type":"substitution","side":side,"player_out":outgoing,"player_in":String(incoming.id),"success":true}
	events.append(event)
	substitutions.append(event.duplicate(true))
	if String(incoming.id) not in participants[side]: participants[side].append(String(incoming.id))

func _bench(players: Array, club_id: String, lineup: Array) -> Array:
	var ids := {}
	for player in lineup: ids[String(player.id)] = true
	var bench: Array = []
	for player in players:
		if String(player.get("club_id","")) == club_id and not bool(player.get("retired",false)) and not ids.has(String(player.id)): bench.append(player)
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
	return {"goals":0,"shots":0,"shots_on_target":0,"xg":0.0,"passes":0,"passes_completed":0,"dribbles":0,"dribbles_completed":0,"interceptions":0,"corners":0,"free_kicks":0,"cards":0,"red_cards":0,"saves":0,"possession":50.0}

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
