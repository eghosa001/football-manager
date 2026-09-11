extends SceneTree

const GeneratorClass = preload("res://simulation/world/world_generator.gd")
const EngineClass = preload("res://simulation/match/continuous_full_match_engine.gd")

func _init() -> void:
	var samples:=100000
	var env:=OS.get_environment("FM_MATCH_SAMPLES")
	if env!="": samples=maxi(100,int(env))
	var world=GeneratorClass.new().create_world(4401,1,2,25)
	var home:Dictionary=world.clubs[0]; var away:Dictionary=world.clubs[1]
	var engine=EngineClass.new()
	var goals:=0; var shots:=0; var cards:=0; var home_points:=0.0; var home_goal_diff:=0
	for i in range(samples):
		var result=engine.simulate_match(home,away,world.players,900000+i)
		if result.has("error"):
			push_error("Continuous simulation error at sample %d"%i); quit(1); return
		var hg:=int(result.get("home_goals",0)); var ag:=int(result.get("away_goals",0))
		goals+=hg+ag; home_goal_diff+=hg-ag
		shots+=int(result.get("stats",{}).get("home",{}).get("shots",0))+int(result.get("stats",{}).get("away",{}).get("shots",0))
		cards+=int(result.get("stats",{}).get("home",{}).get("cards",0))+int(result.get("stats",{}).get("away",{}).get("cards",0))
		home_points += 3.0 if hg>ag else (1.0 if hg==ag else 0.0)
		if i>0 and i%1000==0: print("continuous distribution %d/%d"%[i,samples])
	var avg_goals:=float(goals)/samples; var avg_shots:=float(shots)/samples; var avg_cards:=float(cards)/samples; var home_ppg:=home_points/samples; var avg_home_gd:=float(home_goal_diff)/samples
	print({"samples":samples,"avg_goals":avg_goals,"avg_shots":avg_shots,"avg_cards":avg_cards,"home_ppg":home_ppg,"avg_home_goal_difference":avg_home_gd})
	var ok:=avg_goals>=1.8 and avg_goals<=4.5 and avg_shots>=12.0 and avg_shots<=36.0 and avg_cards>=0.5 and avg_cards<=8.0 and home_ppg>=1.15 and home_ppg<=2.0 and avg_home_gd>=-0.10 and avg_home_gd<=0.80
	if not ok: push_error("Continuous distribution outside acceptance bands")
	quit(0 if ok else 1)
