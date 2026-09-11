class_name DestructiveFuzzer
extends RefCounted

const ValidatorClass = preload("res://core/schema/domain_validator.gd")
const RuleEngineClass = preload("res://simulation/competitions/competition_rule_engine.gd")
const ModManifestClass = preload("res://mods/mod_manifest_service.gd")

var _validator = ValidatorClass.new()
var _rules = RuleEngineClass.new()
var _mods = ModManifestClass.new()

func run(seed: int = 1, iterations: int = 250) -> Dictionary:
	var failures: Array = []
	for i in range(maxi(1,iterations)):
		var world:=_world(seed,i)
		var validation:=_validator.validate_world(world)
		if bool(validation.get("ok",false)) != (i%7!=0):
			failures.append({"case":"schema_expectation","iteration":i,"validation":validation})
		var rule_result:=_exercise_rules(i)
		if not bool(rule_result.get("ok",false)): failures.append({"case":"competition_rules","iteration":i,"result":rule_result})
		var mod_result:=_exercise_mods(i)
		if not bool(mod_result.get("ok",false)): failures.append({"case":"mods","iteration":i,"result":mod_result})
	return {"ok":failures.is_empty(),"iterations":iterations,"failures":failures}

func malformed_save_cases() -> Array:
	return [
		{"name":"missing_world","value":{"schema_version":3}},
		{"name":"future_version","value":{"schema_version":999,"world":{},"history":[]}},
		{"name":"wrong_collection_types","value":{"schema_version":3,"world":{"players":{},"clubs":"bad"},"history":[]}},
		{"name":"huge_squad","value":{"schema_version":3,"world":{"players":_many_players(400),"clubs":[{"id":"c","name":"Club"}],"fixtures":[],"contracts":[]},"history":[]}},
		{"name":"extreme_economy","value":{"schema_version":3,"world":{"players":[],"clubs":[{"id":"c","name":"Club","cash":922337203685477000}],"fixtures":[],"contracts":[]},"history":[]}},
	]

func _world(seed:int,i:int)->Dictionary:
	var valid:=i%7!=0
	var club_id:="c-%d-%d"%[seed,i]
	var player_id:="p-%d-%d"%[seed,i]
	var clubs:Array=[{"id":club_id,"name":"Fuzz Club %d"%i}]
	var players:Array=[{"id":player_id,"club_id":club_id if valid else "missing","age":18+(i%20),"position":"MC","current_ability":35+(i%60),"potential":60+(i%40)}]
	return {"clubs":clubs,"players":players,"fixtures":[],"contracts":[],"competitions":[]}

func _exercise_rules(i:int)->Dictionary:
	var rules={"points_win":3,"points_draw":1,"tie_breakers":["points","goal_difference","goals_for","head_to_head"],"extra_time":true,"penalties":true,"replays":i%2==0,"max_squad":25,"yellow_limit":5}
	if _rules.has_method("validate_rules"):
		var checked=_rules.validate_rules(rules)
		return {"ok":bool(checked.get("ok",true)),"checked":checked}
	return {"ok":true}

func _exercise_mods(i:int)->Dictionary:
	var manifests:Array=[{"id":"base","version":"1.0.0","game_version":"1","dependencies":[],"conflicts":[],"load_order":0},{"id":"addon","version":"1.0.%d"%i,"game_version":"1","dependencies":["base"],"conflicts":[],"load_order":1}]
	if _mods.has_method("validate_set"):
		var checked=_mods.validate_set(manifests,"1")
		return {"ok":bool(checked.get("ok",true)),"checked":checked}
	return {"ok":true}

func _many_players(count:int)->Array:
	var values:Array=[]
	for i in range(count): values.append({"id":"p-%d"%i,"club_id":"c","age":18+i%20,"position":"MC","current_ability":50,"potential":60})
	return values
