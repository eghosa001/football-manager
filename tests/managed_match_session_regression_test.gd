extends SceneTree

const Session = preload("res://simulation/match/managed_match_session.gd")
const Tactics = preload("res://simulation/tactics/tactics_manager.gd")

func _init() -> void:
	var home := {"id":"home","tactic":Tactics.new().create_tactic("4-3-3"),"reputation":70}
	var away := {"id":"away","tactic":Tactics.new().create_tactic("4-3-3"),"reputation":68}
	var players := _players()
	var match = Session.new()
	var start: Dictionary = match.start_match(home,away,players,99117,{})
	assert(not start.has("error"))
	assert(int(start.get("minute",0)) == 0)
	var half: Dictionary = match.advance_to_minute(45)
	assert(int(half.get("minute",0)) >= 45)
	assert(not bool(half.get("finished",false)))
	var home_lineup: Array = half.get("home_lineup",[])
	var bench: Array = half.get("home_bench",[])
	assert(home_lineup.size() >= 10)
	assert(not bench.is_empty())
	var outgoing := String(home_lineup[home_lineup.size()-1])
	var incoming := String(bench[0])
	assert(match.make_substitution("home",outgoing,incoming) == OK)
	var attacking := Tactics.new().create_tactic("4-2-3-1","attacking","high","high")
	assert(match.change_tactic("home",attacking) == OK)
	var final: Dictionary = match.finish_match()
	assert(not final.has("error"))
	assert(incoming in final.get("final_lineups",{}).get("home",[]))
	assert(outgoing not in final.get("final_lineups",{}).get("home",[]))
	var directed_sub := false
	var directed_tactic := false
	for event in final.get("events",[]):
		if String(event.get("type","")) == "substitution" and bool(event.get("user_directed",false)): directed_sub = true
		if String(event.get("type","")) == "tactical_change" and bool(event.get("user_directed",false)): directed_tactic = true
	assert(directed_sub)
	assert(directed_tactic)
	assert(final.get("spatial",{}).get("frames",[]).size() > half.get("frames",[]).size())
	print("[TEST] MANAGED MATCH SESSION REGRESSION PASS")
	quit(0)

func _players() -> Array:
	var rows: Array = []
	var positions := ["GK","DR","DC","DC","DL","DM","MC","MC","AMR","AML","ST","ST","MC","DC","AMR","GK"]
	for side in ["home","away"]:
		for i in range(16):
			rows.append({
				"id":"%s-%02d" % [side,i],"club_id":side,"position":positions[i],"current_ability":72-i,"potential":78,"fitness":100,"morale":70,
				"attributes":{"stamina":70,"passing":70,"technique":70,"finishing":70,"dribbling":70,"decisions":70,"vision":70,"composure":70,"work_rate":70,"anticipation":70,"marking":70,"positioning":70,"pace":70,"acceleration":70,"agility":70,"balance":70,"reflexes":70,"one_on_ones":70,"goalkeeper_positioning":70,"handling":70}
			})
	return rows
