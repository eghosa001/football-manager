extends SceneTree

const Engine = preload("res://simulation/match/continuous_spatial_engine_v3.gd")

var checks := 0
var failures := 0

func _init() -> void:
	var strong := _lineup("strong",85,85,85,85)
	var weak := _lineup("weak",35,35,35,35)
	var neutral := _lineup("neutral",55,55,55,55)
	var strong_goals := 0
	var weak_goals := 0
	var strong_distance := 0.0
	var weak_distance := 0.0
	for seed in range(30):
		var a := Engine.new().simulate_continuous(strong,neutral,91000+seed,{}, {},900,{},30)
		var b := Engine.new().simulate_continuous(weak,neutral,91000+seed,{}, {},900,{},30)
		strong_goals += int(a.summary.goals)
		weak_goals += int(b.summary.goals)
		strong_distance += float(a.summary.home_distance)
		weak_distance += float(b.summary.home_distance)
	_expect(strong_distance > weak_distance, "Higher pace/acceleration/stamina must increase aggregate movement distance")
	_expect(strong_goals >= weak_goals, "Higher finishing/composure must not underperform weak finishing across deterministic sample")
	var replay_a := Engine.new().simulate_continuous(strong,neutral,99991,{}, {},300,{},20)
	var replay_b := Engine.new().simulate_continuous(strong,neutral,99991,{}, {},300,{},20)
	_expect(replay_a == replay_b, "Attribute-sensitive continuous simulation must remain deterministic")
	if failures == 0:
		print("[TEST] CONTINUOUS ATTRIBUTES PASS — %d checks" % checks)
		quit(0)
	else:
		push_error("[TEST] CONTINUOUS ATTRIBUTES FAIL — %d failures across %d checks" % [failures,checks])
		quit(1)

func _lineup(prefix:String, physical:int, technical:int, mental:int, keeping:int) -> Array:
	var positions := ["GK","DR","DC","DC","DL","DM","MC","MC","AMR","AML","ST"]
	var rows: Array = []
	for i in range(11):
		rows.append({
			"id":"%s-%02d" % [prefix,i],"position":positions[i],"current_ability":technical,"fitness":100,
			"attributes":{
				"pace":physical,"acceleration":physical,"agility":physical,"stamina":physical,"natural_fitness":physical,
				"passing":technical,"technique":technical,"finishing":technical,"dribbling":technical,"balance":physical,
				"decisions":mental,"vision":mental,"composure":mental,"work_rate":mental,"anticipation":mental,"marking":mental,"positioning":mental,
				"reflexes":keeping,"one_on_ones":keeping,"goalkeeper_positioning":keeping,"handling":keeping
			}
		})
	return rows

func _expect(condition:bool,message:String)->void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TEST] "+message)
