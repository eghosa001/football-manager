extends SceneTree

const GeneratorClass = preload("res://simulation/world/world_generator.gd")
const ContinuousClass = preload("res://simulation/match/continuous_full_match_engine.gd")
const EventClass = preload("res://simulation/match/full_match_engine_v2.gd")
const AbstractClass = preload("res://simulation/match/abstract_match_engine.gd")
const AggregateClass = preload("res://simulation/match/background_aggregate_engine.gd")

func _init() -> void:
	var samples:=2000
	var env:=OS.get_environment("FM_TIER_SAMPLES")
	if env!="": samples=maxi(100,int(env))
	var world=GeneratorClass.new().create_world(5521,1,2,25)
	var home:Dictionary=world.clubs[0]; var away:Dictionary=world.clubs[1]
	var engines={"detailed":ContinuousClass.new(),"event":EventClass.new(),"abstract":AbstractClass.new(),"aggregate":AggregateClass.new()}
	var summary:={}
	for tier in engines.keys():
		var goals:=0; var home_wins:=0; var draws:=0; var shots:=0
		for i in range(samples):
			var result=engines[tier].simulate_match(home,away,world.players,700000+i)
			if result.has("error"): push_error("%s tier errored"%tier); quit(1); return
			var hg:=int(result.get("home_goals",0)); var ag:=int(result.get("away_goals",0)); goals+=hg+ag
			if hg>ag: home_wins+=1
			elif hg==ag: draws+=1
			shots+=int(result.get("stats",{}).get("home",{}).get("shots",0))+int(result.get("stats",{}).get("away",{}).get("shots",0))
		summary[tier]={"goals":float(goals)/samples,"home_win_rate":float(home_wins)/samples,"draw_rate":float(draws)/samples,"shots":float(shots)/samples}
	print(summary)
	var baseline:Dictionary=summary.detailed
	var ok:=true
	for tier in ["event","abstract","aggregate"]:
		var row:Dictionary=summary[tier]
		ok = ok and absf(float(row.goals)-float(baseline.goals))<=1.0
		ok = ok and absf(float(row.home_win_rate)-float(baseline.home_win_rate))<=0.16
		ok = ok and absf(float(row.draw_rate)-float(baseline.draw_rate))<=0.14
		if float(row.shots)>0.0 and float(baseline.shots)>0.0: ok = ok and absf(float(row.shots)-float(baseline.shots))<=10.0
	if not ok: push_error("Simulation tiers are not statistically equivalent")
	quit(0 if ok else 1)
