class_name ManagedMatchSession
extends "res://simulation/match/full_match_engine_core.gd"

var home_club: Dictionary = {}
var away_club: Dictionary = {}
var source_players: Array = []
var match_seed := 1
var match_context: Dictionary = {}
var home_tactic: Dictionary = {}
var away_tactic: Dictionary = {}
var home: Array = []
var away: Array = []
var starters: Dictionary = {}
var participants: Dictionary = {}
var substitutions: Array = []
var cautions: Dictionary = {}
var home_mod: Dictionary = {}
var away_mod: Dictionary = {}
var factor_edge := 0.0
var importance := 0.5
var weather: Dictionary = {}
var events: Array = []
var possession_counts: Dictionary = {"home":0,"away":0}
var frames: Array = []
var carry: Dictionary = {}
var possession_index := 0
var finished := false
var error := OK

func start_match(p_home: Dictionary, p_away: Dictionary, players: Array, seed: int, context: Dictionary = {}) -> Dictionary:
	home_club = p_home
	away_club = p_away
	source_players = players
	match_seed = seed
	match_context = context.duplicate(true)
	home_tactic = home_club.get("tactic", _tactics.create_tactic("4-3-3")).duplicate(true)
	away_tactic = away_club.get("tactic", _tactics.create_tactic("4-3-3")).duplicate(true)
	home = _tactics.select_lineup(players, String(home_club.id), home_tactic).duplicate(true)
	away = _tactics.select_lineup(players, String(away_club.id), away_tactic).duplicate(true)
	for player in home: _prepare_match_player(player, seed, 1000)
	for player in away: _prepare_match_player(player, seed, 2000)
	var travel_fatigue := clampf(float(context.get("travel_fatigue", 0.0)), 0.0, 0.38)
	if travel_fatigue > 0.0:
		for player in away:
			player["fitness"] = clampi(int(player.get("fitness",100)) - int(round(travel_fatigue * 22.0)),25,100)
	if home.size() < 11 or away.size() < 11:
		error = ERR_UNAVAILABLE
		finished = true
		return snapshot()
	starters = {"home":_ids(home),"away":_ids(away)}
	participants = starters.duplicate(true)
	home_mod = _tactics.style_modifiers(home_tactic)
	away_mod = _tactics.style_modifiers(away_tactic)
	factor_edge = float(MatchFactorsClass.new().breakdown(home_club,away_club,players,context).total_home_edge)
	importance = float(context.get("importance",0.5))
	weather = _weather_for_seed(seed)
	return snapshot()

func current_minute() -> int:
	return mini(90, int(floor(float(possession_index) * 90.0 / 54.0)))

func advance_to_minute(target_minute: int) -> Dictionary:
	if finished or error != OK:
		return snapshot()
	var target := clampi(target_minute, current_minute(), 90)
	while possession_index < 54 and current_minute() <= target:
		_simulate_next_possession()
		if possession_index >= 54:
			finished = true
			break
		if current_minute() > target:
			break
	return snapshot()

func make_substitution(side: String, player_out: String, player_in: String) -> Error:
	if finished or side not in ["home","away"]:
		return ERR_INVALID_PARAMETER
	if substitutions.filter(func(row): return String(row.get("side","")) == side).size() >= 5:
		return ERR_UNAVAILABLE
	var lineup: Array = home if side == "home" else away
	var out_index := -1
	for i in range(lineup.size()):
		if String(lineup[i].get("id","")) == player_out:
			out_index = i
			break
	if out_index < 0:
		return ERR_DOES_NOT_EXIST
	if player_in in participants.get(side, []):
		return ERR_ALREADY_EXISTS
	var incoming := {}
	var expected_club := String(home_club.id) if side == "home" else String(away_club.id)
	for player in source_players:
		if String(player.get("id","")) == player_in and String(player.get("club_id","")) == expected_club and int(player.get("injured_days",0)) <= 0:
			incoming = player.duplicate(true)
			break
	if incoming.is_empty():
		return ERR_DOES_NOT_EXIST
	_prepare_match_player(incoming,match_seed,3000+possession_index)
	incoming["_came_on_minute"] = current_minute()
	lineup[out_index] = incoming
	if not carry.is_empty():
		var positions: Dictionary = carry.home_positions if side == "home" else carry.away_positions
		if positions.has(player_out):
			positions[String(incoming.id)] = positions[player_out]
			positions.erase(player_out)
		if String(carry.get("ball_owner_id","")) == player_out:
			carry["ball_owner_id"] = String(incoming.id)
	var event := {"minute":current_minute(),"type":"substitution","side":side,"player_out":player_out,"player_in":String(incoming.id),"success":true,"user_directed":true}
	if _abilities.has(incoming,SpecialAbilityServiceClass.SUPER_SUB): event["special_ability"] = "Super Sub"
	if _abilities.has(incoming,SpecialAbilityServiceClass.GAMECHANGER): event["gamechanger"] = true
	events.append(event)
	substitutions.append(event)
	participants[side].append(String(incoming.id))
	return OK

func change_tactic(side: String, tactic: Dictionary) -> Error:
	if finished or side not in ["home","away"] or tactic.is_empty():
		return ERR_INVALID_PARAMETER
	if side == "home":
		home_tactic = tactic.duplicate(true)
		home_mod = _tactics.style_modifiers(home_tactic)
	else:
		away_tactic = tactic.duplicate(true)
		away_mod = _tactics.style_modifiers(away_tactic)
	events.append({"minute":current_minute(),"type":"tactical_change","side":side,"formation":String(tactic.get("formation","")),"mentality":String(tactic.get("mentality","")),"user_directed":true})
	return OK

func finish_match() -> Dictionary:
	if not finished and error == OK:
		advance_to_minute(90)
	return result()

func snapshot() -> Dictionary:
	var score := _score()
	var data := {
		"minute":current_minute(),
		"finished":finished,
		"home_goals":score.home,
		"away_goals":score.away,
		"home_lineup":_ids(home),
		"away_lineup":_ids(away),
		"home_bench":_available_bench("home"),
		"away_bench":_available_bench("away"),
		"substitutions":substitutions.duplicate(true),
		"events":events.duplicate(true),
		"frames":frames.duplicate(true),
		"tactics":{"home":home_tactic.duplicate(true),"away":away_tactic.duplicate(true)},
		"weather":weather.duplicate(true),
	}
	if error != OK:
		data["error"] = error
	return data

func result() -> Dictionary:
	if error != OK:
		return {"error":error,"home_goals":0,"away_goals":0,"events":[],"stats":{}}
	var stats := {"home":_blank_stats(),"away":_blank_stats()}
	var goals := {"home":0,"away":0}
	for event in events: _accumulate_event(stats,goals,event)
	stats.home.xg = snappedf(float(stats.home.xg),0.01)
	stats.away.xg = snappedf(float(stats.away.xg),0.01)
	var total := maxi(1,int(possession_counts.home)+int(possession_counts.away))
	stats.home.possession = snappedf(float(possession_counts.home)/total*100.0,0.1)
	stats.away.possession = snappedf(100.0-float(stats.home.possession),0.1)
	var factors := MatchFactorsClass.new().breakdown(home_club,away_club,source_players,match_context)
	return {
		"home_goals":int(goals.home),"away_goals":int(goals.away),"events":events.duplicate(true),"stats":stats,
		"lineups":starters.duplicate(true),"participants":participants.duplicate(true),"final_lineups":{"home":_ids(home),"away":_ids(away)},"substitutions":substitutions.duplicate(true),
		"spatial":{"pitch_length":105.0,"pitch_width":68.0,"frames":frames.duplicate(true),"model":"managed_incremental_2d"},
		"tactics":{"home":home_tactic.duplicate(true),"away":away_tactic.duplicate(true)},"seed":match_seed,
		"factors":factors,"match_context":match_context.duplicate(true),"weather":weather.duplicate(true),"importance":importance,
		"special_ability_impact":_ability_impact(events,source_players)
	}

func _simulate_next_possession() -> void:
	var minute := current_minute()
	var home_share := _possession_share(home,away,home_mod,away_mod,factor_edge)
	var starting_side := "home" if SeededRngClass.unit_for(match_seed,31_000+possession_index) < home_share else "away"
	if not carry.is_empty(): starting_side = String(carry.possession_side)
	possession_counts[starting_side] = int(possession_counts.get(starting_side,0)) + 1
	var sequence_factor := float(home_mod.sequence_multiplier) if starting_side == "home" else float(away_mod.sequence_multiplier)
	var max_actions := clampi(int(round(18.0*sequence_factor)),14,22)
	carry["tactic_home"] = home_tactic
	carry["tactic_away"] = away_tactic
	carry["weather"] = weather
	carry["match_importance"] = importance
	var possession: Dictionary = _possession.simulate_possession(home,away,match_seed+possession_index*7919,max_actions,starting_side,carry)
	for frame_index in range(possession.frames.size()):
		var frame: Dictionary = possession.frames[frame_index]
		frame["minute"] = float(possession_index)*90.0/54.0 + float(frame_index)*90.0/54.0/maxf(1.0,float(possession.frames.size()))
		frames.append(frame)
	for event in possession.events:
		var copy: Dictionary = event.duplicate(true)
		copy["minute"] = minute
		_enrich_shot(copy,home,away,possession.state)
		_apply_shot_traits(copy,home,away,match_seed,possession_index,match_context)
		events.append(copy)
	_maybe_set_piece(events,home,away,possession.state,starting_side,minute,match_seed,possession_index,match_context)
	var before_card := events.size()
	_maybe_card(events,home,away,starting_side,minute,match_seed,possession_index,home_mod,away_mod)
	if events.size() > before_card:
		var card: Dictionary = events.back()
		var player_id := String(card.player_id)
		if String(card.card) == "yellow":
			cautions[player_id] = int(cautions.get(player_id,0))+1
			if int(cautions[player_id]) >= 2:
				card.card = "red"
				card["second_yellow"] = true
		if String(card.card) == "red":
			var card_lineup: Array = home if String(card.side) == "home" else away
			for i in range(card_lineup.size()-1,-1,-1):
				if String(card_lineup[i].id) == player_id: card_lineup.remove_at(i)
			var positions: Dictionary = possession.state.home_positions if String(card.side) == "home" else possession.state.away_positions
			positions.erase(player_id)
	carry = possession.state
	if String(carry.get("ball_owner_id","")).is_empty():
		var next_side := "away" if starting_side == "home" else "home"
		carry = _possession._initial_state(home,away,next_side)
	for team in [home,away]:
		for player in team:
			var stamina := float(player.get("attributes",{}).get("stamina",50))
			var retention := _abilities.stamina_retention(player)
			var fatigue_loss := (0.55-stamina*0.003)*(1.0-retention)
			player.fitness = maxf(25.0,float(player.get("fitness",100))-fatigue_loss)
	possession_index += 1
	if possession_index >= 54: finished = true

func _available_bench(side: String) -> Array:
	var club_id := String(home_club.id) if side == "home" else String(away_club.id)
	var used: Array = participants.get(side,[])
	var result: Array = []
	for player in source_players:
		var id := String(player.get("id",""))
		if String(player.get("club_id","")) == club_id and id not in used and int(player.get("injured_days",0)) <= 0:
			result.append(id)
	return result

func _score() -> Dictionary:
	var home_goals := 0
	var away_goals := 0
	for event in events:
		var goal := (String(event.get("type","")) == "shot" and String(event.get("outcome","")) == "goal") or String(event.get("type","")) == "goal"
		if not goal: continue
		if String(event.get("side","")) == "home": home_goals += 1
		elif String(event.get("side","")) == "away": away_goals += 1
	return {"home":home_goals,"away":away_goals}

func _weather_for_seed(seed: int) -> Dictionary:
	var result := {"kind":"clear","pass_factor":1.0,"touch_factor":1.0,"stamina_factor":1.0,"shot_factor":1.0,"attendance_factor":1.0}
	var roll := SeededRngClass.unit_for(seed,91001)
	if roll < 0.12: return {"kind":"heavy_rain","pass_factor":0.90,"touch_factor":0.86,"stamina_factor":0.92,"shot_factor":0.94,"attendance_factor":0.88}
	if roll < 0.30: return {"kind":"rain","pass_factor":0.95,"touch_factor":0.93,"stamina_factor":0.96,"shot_factor":0.97,"attendance_factor":0.94}
	if roll > 0.92: return {"kind":"hot","pass_factor":0.99,"touch_factor":0.98,"stamina_factor":0.88,"shot_factor":0.98,"attendance_factor":0.96}
	return result
