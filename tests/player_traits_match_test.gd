extends SceneTree

const Engine = preload("res://simulation/match/continuous_spatial_engine_v4.gd")

var checks := 0
var failures := 0

func _init() -> void:
	var engine = Engine.new()
	var home := _lineup("home")
	var away := _lineup("away")
	home[10]["traits"] = ["tries_long_shots","runs_with_ball","cuts_inside","beats_offside_trap"]
	var trait_events := 0
	var tagged := 0
	for seed in range(20):
		var result := engine.simulate_continuous(home,away,96000+seed,{}, {},1200,{},20)
		for event in result.events:
			if String(event.get("player_id","")) != "home-10":
				continue
			trait_events += 1
			if event.has("trait") or bool(event.get("trait_run_in_behind",false)):
				tagged += 1
	_expect(trait_events > 0,"Trait-bearing attacker must participate in continuous match events")
	_expect(tagged > 0,"Learned player traits must change and tag at least one decision across deterministic seed sample")
	var replay_a := engine.simulate_continuous(home,away,96999,{}, {},500,{},25)
	var replay_b := Engine.new().simulate_continuous(home,away,96999,{}, {},500,{},25)
	_expect(replay_a == replay_b,"Trait-aware match decisions must remain deterministic")
	if failures==0:
		print("[TEST] PLAYER TRAITS MATCH PASS — %d checks"%checks); quit(0)
	else:
		push_error("[TEST] PLAYER TRAITS MATCH FAIL — %d failures across %d checks"%[failures,checks]); quit(1)

func _lineup(prefix:String)->Array:
	var positions := ["GK","DR","DC","DC","DL","DM","MC","MC","AMR","AML","ST"]
	var rows:Array=[]
	for i in range(11):
		rows.append({"id":"%s-%d"%[prefix,i],"position":positions[i],"current_ability":65,"fitness":100,"traits":[],"attributes":{"pace":65,"acceleration":65,"agility":65,"stamina":70,"natural_fitness":70,"passing":65,"technique":65,"finishing":65,"long_shots":70,"dribbling":70,"balance":65,"decisions":65,"vision":65,"composure":65,"work_rate":65,"anticipation":65,"marking":60,"positioning":60,"reflexes":65,"one_on_ones":65,"goalkeeper_positioning":65,"handling":65}})
	return rows

func _expect(condition:bool,message:String)->void:
	checks+=1
	if not condition:
		failures+=1
		push_error("[TEST] "+message)
