extends SceneTree

const Lifecycle = preload("res://simulation/players/player_lifecycle_v2.gd")

var checks := 0
var failures := 0

func _init() -> void:
	var lifecycle = Lifecycle.new()
	var durable := _player("durable",34,72,94,92,88,2)
	var fragile := _player("fragile",38,32,48,25,20,14)
	var durable_retirements := 0
	var fragile_retirements := 0
	for seed in range(200):
		if lifecycle._should_retire(durable,92000+seed): durable_retirements += 1
		if lifecycle._should_retire(fragile,92000+seed): fragile_retirements += 1
	_expect(fragile_retirements > durable_retirements,"Older low-ability injury-heavy player must retire more often than fit motivated veteran")
	var staff_roles := {}
	for seed in range(30):
		var staff := lifecycle._convert_to_staff(_player("career-%d"%seed,36,65,75,70,70,4),{},93000+seed)
		staff_roles[String(staff.role)] = true
		_expect(String(staff.get("former_player_id",""))!="","Converted staff must retain former-player identity link")
	_expect(staff_roles.size() >= 2,"Former-player conversion must support more than one staff career path")
	_expect(lifecycle._should_retire(_player("forced",42,90,100,100,100,0),94000),"Age 42 must force retirement")
	if failures==0:
		print("[TEST] PLAYER LIFECYCLE V2 PASS — %d checks"%checks); quit(0)
	else:
		push_error("[TEST] PLAYER LIFECYCLE V2 FAIL — %d failures across %d checks"%[failures,checks]); quit(1)

func _player(id:String,age:int,ability:int,fitness:int,natural:int,motivation:int,injuries:int)->Dictionary:
	var history:Array=[]
	for i in range(injuries): history.append({"days":25})
	return {
		"id":id,"club_id":"club","first_name":"Retired","last_name":"Player","age":age,"current_ability":ability,"fitness":fitness,"career_seasons":12,"reputation":ability,
		"attributes":{"natural_fitness":natural,"leadership":motivation,"decisions":motivation,"vision":motivation},
		"hidden_attributes":{"professionalism":motivation,"ambition":motivation,"loyalty":motivation,"adaptability":motivation,"sportsmanship":motivation},
		"injury_history":history,"injured_days":0
	}

func _expect(condition:bool,message:String)->void:
	checks+=1
	if not condition:
		failures+=1
		push_error("[TEST] "+message)
