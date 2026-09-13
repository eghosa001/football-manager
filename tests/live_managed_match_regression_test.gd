extends SceneTree

const Session = preload("res://simulation/match/managed_match_session.gd")
const Tactics = preload("res://simulation/tactics/tactics_manager.gd")

func _init() -> void:
	var tactics = Tactics.new()
	var home := {"id":"home","tactic":tactics.create_tactic("4-3-3"),"reputation":78}
	var away := {"id":"away","tactic":tactics.create_tactic("4-3-3"),"reputation":75}
	var players: Array = []
	var positions := ["GK","DR","DC","DC","DL","DM","MC","MC","AMR","AML","ST","ST","MC","DC","AMR","GK"]
	for side in ["home","away"]:
		for i in range(16):
			players.append({
				"id":"%s-%02d" % [side,i],"club_id":side,"position":positions[i],
				"current_ability":78-i,"potential":85,"fitness":100,"fatigue":0,"morale":75,
				"injured_days":0,"attributes":{
					"stamina":72,"passing":72,"technique":72,"finishing":72,"dribbling":72,
					"decisions":72,"vision":72,"composure":72,"work_rate":72,"anticipation":72,
					"marking":72,"positioning":72,"pace":72,"acceleration":72,"agility":72,
					"balance":72,"reflexes":72,"one_on_ones":72,"goalkeeper_positioning":72,"handling":72
				}
			})
	var live_session = Session.new()
	var started: Dictionary = live_session.start_match(home,away,players,919191,{})
	assert(not started.has("error"))
	live_session.advance_to_minute(45)
	var half: Dictionary = live_session.snapshot()
	assert(int(half.get("minute",0)) >= 45)
	var starters: Array = half.get("home_lineup",[])
	var bench: Array = half.get("home_bench",[])
	assert(starters.size() >= 11 and not bench.is_empty())
	var player_out := String(starters[starters.size()-1])
	var player_in := String(bench[0])
	assert(live_session.make_substitution("home",player_out,player_in) == OK)
	var attacking := tactics.create_tactic("4-2-3-1","attacking","high","high")
	assert(live_session.change_tactic("home",attacking) == OK)
	var finished: Dictionary = live_session.finish_match()
	assert(not finished.has("error"))
	assert(player_in in finished.get("final_lineups",{}).get("home",[]))
	assert(player_out not in finished.get("final_lineups",{}).get("home",[]))
	assert(String(finished.get("tactics",{}).get("home",{}).get("formation","")) == "4-2-3-1")
	var saw_sub := false
	var saw_tactic := false
	for event in finished.get("events",[]):
		if String(event.get("type","")) == "substitution" and bool(event.get("user_directed",false)): saw_sub = true
		if String(event.get("type","")) == "tactical_change" and bool(event.get("user_directed",false)): saw_tactic = true
	assert(saw_sub and saw_tactic)
	print("[TEST] LIVE MANAGED MATCH REGRESSION PASS")
	quit(0)
