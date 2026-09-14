extends SceneTree

const MatchEngine = preload("res://simulation/match/full_match_engine_v2.gd")
const Tactics = preload("res://simulation/tactics/tactics_manager.gd")

func _init() -> void:
	var home := {"id":"home","tactic":Tactics.new().create_tactic("4-3-3"),"reputation":70}
	var away := {"id":"away","tactic":Tactics.new().create_tactic("4-3-3"),"reputation":68}
	var players: Array = []
	for side in ["home","away"]:
		for i in range(16):
			var positions := ["GK","DR","DC","DC","DL","DM","MC","MC","AMR","AML","ST","ST","MC","DC","AMR","GK"]
			players.append({"id":"%s-%02d" % [side,i],"club_id":side,"position":positions[i],"current_ability":70-i,"potential":75,"fitness":100,"morale":70,"attributes":{"stamina":70,"passing":70,"technique":70,"finishing":70,"dribbling":70,"decisions":70,"vision":70,"composure":70,"work_rate":70,"anticipation":70,"marking":70,"positioning":70,"pace":70,"acceleration":70,"agility":70,"balance":70,"reflexes":70,"one_on_ones":70,"goalkeeper_positioning":70,"handling":70}})
	var baseline: Dictionary = MatchEngine.new().simulate_match(home,away,players,424242,{})
	assert(not baseline.has("error"))
	var starters: Array = baseline.get("lineups",{}).get("home",[])
	assert(starters.size() == 11)
	var player_out := String(starters[starters.size()-1])
	var player_in := ""
	for player in players:
		if String(player.get("club_id","")) == "home" and String(player.get("id","")) not in starters:
			player_in = String(player.get("id",""))
			break
	assert(player_in != "")
	var managed: Dictionary = MatchEngine.new().simulate_match(home,away,players,424242,{"user_substitutions":[{"minute":55,"side":"home","player_out":player_out,"player_in":player_in}]})
	assert(not managed.has("error"))
	var found := false
	for row in managed.get("substitutions",[]):
		if bool(row.get("user_directed",false)) and String(row.get("player_out","")) == player_out and String(row.get("player_in","")) == player_in:
			found = true
	assert(found)
	assert(player_in in managed.get("final_lineups",{}).get("home",[]))
	assert(player_out not in managed.get("final_lineups",{}).get("home",[]))
	print("[TEST] INTERACTIVE SUBSTITUTION REGRESSION PASS")
	quit(0)
