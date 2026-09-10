class_name FullMatchEngineV2
extends RefCounted

const PossessionEngineClass = preload("res://simulation/match/spatial_match_engine_v2.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")

var _possession = PossessionEngineClass.new()
var _tactics = TacticsManagerClass.new()

func simulate_match(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int) -> Dictionary:
	var home_tactic: Dictionary = home_club.get("tactic", _tactics.create_tactic("4-3-3"))
	var away_tactic: Dictionary = away_club.get("tactic", _tactics.create_tactic("4-3-3"))
	var home: Array = _tactics.select_lineup(players, String(home_club.id), home_tactic)
	var away: Array = _tactics.select_lineup(players, String(away_club.id), away_tactic)
	if home.size() < 11 or away.size() < 11:
		return {"error":ERR_UNAVAILABLE,"home_goals":0,"away_goals":0,"events":[],"stats":{}}
	var events: Array = []
	var possession_counts := {"home":0,"away":0}
	var frames: Array = []
	for possession_index in range(54):
		var minute := mini(90, int(floor(float(possession_index) * 90.0 / 54.0)))
		var starting_side := "home" if possession_index % 2 == 0 else "away"
		possession_counts[starting_side] += 1
		var possession: Dictionary = _possession.simulate_possession(home, away, seed + possession_index * 7919, 18, starting_side)
		for event in possession.events:
			var copy: Dictionary = event.duplicate(true)
			copy["minute"] = minute
			events.append(copy)
		frames.append({"minute":minute,"ball":possession.state.ball.duplicate(true),"home":possession.state.home_positions.duplicate(true),"away":possession.state.away_positions.duplicate(true)})
	var stats := {"home":_blank_stats(),"away":_blank_stats()}
	var goals := {"home":0,"away":0}
	for event in events:
		var side := String(event.get("side", "home"))
		if not stats.has(side): continue
		if String(event.type) == "pass":
			stats[side].passes += 1
			if bool(event.get("success", false)): stats[side].passes_completed += 1
		elif String(event.type) == "dribble":
			stats[side].dribbles += 1
			if bool(event.get("success", false)): stats[side].dribbles_completed += 1
		elif String(event.type) == "shot":
			stats[side].shots += 1
			stats[side].xg += float(event.get("xg", 0.0))
			if String(event.get("outcome", "")) in ["goal","saved"]: stats[side].shots_on_target += 1
			if String(event.get("outcome", "")) == "goal":
				stats[side].goals += 1
				goals[side] += 1
	stats.home.xg = snappedf(float(stats.home.xg), 0.01)
	stats.away.xg = snappedf(float(stats.away.xg), 0.01)
	var total_possessions := maxi(1, int(possession_counts.home) + int(possession_counts.away))
	stats.home.possession = snappedf(float(possession_counts.home) / total_possessions * 100.0, 0.1)
	stats.away.possession = snappedf(100.0 - float(stats.home.possession), 0.1)
	return {
		"home_goals":int(goals.home),"away_goals":int(goals.away),"events":events,"stats":stats,
		"lineups":{"home":_ids(home),"away":_ids(away)},
		"spatial":{"pitch_length":105.0,"pitch_width":68.0,"frames":frames,"model":"causal_2d_v2"},
		"seed":seed
	}

func apply_to_fixture(fixture: Dictionary, result: Dictionary) -> void:
	if result.has("error"): return
	fixture.played = true
	fixture.home_goals = int(result.home_goals)
	fixture.away_goals = int(result.away_goals)

func _blank_stats() -> Dictionary:
	return {"passes":0,"passes_completed":0,"dribbles":0,"dribbles_completed":0,"shots":0,"shots_on_target":0,"goals":0,"xg":0.0,"possession":0.0}

func _ids(players: Array) -> Array:
	var ids: Array = []
	for player in players: ids.append(String(player.id))
	return ids
